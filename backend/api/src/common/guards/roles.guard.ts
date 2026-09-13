import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY, SUBJECT_TYPE_KEY } from '../decorators/require-role.decorator';
import type { AdminRole, RequestSubject, SubjectType } from '../../modules/auth/session.types';

/**
 * Server-side counterpart to shieldweb/src/config/permissions.ts, which
 * today only runs in the browser and enforces nothing against a party that
 * bypasses the client. A no-op when a route has neither @RequireRole nor
 * @RequireSubject (see those decorators' docs for why a bare "authenticated"
 * check isn't enough for /staff/* and /member/* routes).
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<AdminRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    const requiredSubjectTypes = this.reflector.getAllAndOverride<SubjectType[]>(SUBJECT_TYPE_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    const hasRoleRequirement = !!requiredRoles && requiredRoles.length > 0;
    const hasSubjectRequirement = !!requiredSubjectTypes && requiredSubjectTypes.length > 0;
    if (!hasRoleRequirement && !hasSubjectRequirement) return true;

    const request = context.switchToHttp().getRequest();
    const user: RequestSubject | undefined = request.user;

    if (hasRoleRequirement) {
      if (!user || user.subjectType !== 'STAFF' || !user.role || !requiredRoles!.includes(user.role)) {
        throw new ForbiddenException({
          error: { code: 'FORBIDDEN', message: `Requires one of role: ${requiredRoles!.join(', ')}` },
        });
      }
      return true;
    }

    if (!user || !requiredSubjectTypes!.includes(user.subjectType)) {
      throw new ForbiddenException({
        error: { code: 'FORBIDDEN', message: `Requires subject type: ${requiredSubjectTypes!.join(', ')}` },
      });
    }
    return true;
  }
}
