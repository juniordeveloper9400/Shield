import { CanActivate, ExecutionContext, ForbiddenException, Inject, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { eq } from 'drizzle-orm';
import { ROLES_KEY } from '../decorators/require-role.decorator';
import { modulesForRequest } from '../module-routes';
import { DRIZZLE, type Database } from '../../db/client';
import { adminUser } from '../../db/schema';
import type { AdminRole, RequestSubject } from '../../modules/auth/session.types';

/**
 * Narrows a staff account to its own custom sidebar module list
 * (app.admin_user.modules), on top of — never instead of — the role check
 * RolesGuard already ran (this guard only looks at routes that carried a
 * @RequireRole; a route with no role requirement is untouched here too).
 *
 * `modules` NULL (every account until someone edits it) means "everything
 * the role grants" — this guard is then a no-op, so nothing changes for an
 * account nobody has customized. A route this guard can't map to a module
 * (see module-routes.ts) is never restricted here either — the one-way
 * safety property that makes this additive rather than a risk of silently
 * blocking something that used to work.
 */
@Injectable()
export class ModuleGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    @Inject(DRIZZLE) private readonly db: Database,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredRoles = this.reflector.getAllAndOverride<AdminRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredRoles || requiredRoles.length === 0) return true; // not a role-gated staff route

    const request = context.switchToHttp().getRequest();
    const user: RequestSubject | undefined = request.user;
    if (!user || user.subjectType !== 'STAFF') return true; // RolesGuard already refused this; nothing more to add

    const routeModules = modulesForRequest(request.method, request.path ?? request.url ?? '');
    if (!routeModules) return true; // unmapped route — not individually restrictable, same as before this feature

    const [row] = await this.db
      .select({ modules: adminUser.modules })
      .from(adminUser)
      .where(eq(adminUser.id, Number(user.subjectId)))
      .limit(1);

    if (!row || row.modules == null) return true; // no customization on this account

    if (!routeModules.some((m) => row.modules!.includes(m))) {
      throw new ForbiddenException({
        error: { code: 'FORBIDDEN', message: `This account's access to "${routeModules[0]}" has been turned off.` },
      });
    }
    return true;
  }
}
