import { CanActivate, ExecutionContext, ForbiddenException, Inject, Injectable } from '@nestjs/common';
import { and, eq, isNull } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { users } from '../../db/schema';
import type { RequestSubject } from '../../modules/auth/session.types';

/**
 * Lets a member through only once their Sahakar 360 registration is complete
 * (`app.users.registration_completed_at`, which only the server ever sets — see
 * `IdentityService.updateProfile`). Applied per route with `@RequireRegistered()`
 * to the actions that create something on a member's behalf: adding to the cart,
 * checkout, prescription upload and orders, lab bookings, appointments and
 * wallet-card purchases.
 *
 * This is the server-side half of "only registered members can do that": the
 * apps also stop an unregistered member before they get here, but a client
 * check alone is only a courtesy.
 */
@Injectable()
export class RegisteredGuard implements CanActivate {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const user: RequestSubject | undefined = context.switchToHttp().getRequest().user;
    // Only member routes carry this decorator; a staff session never reaches it.
    if (!user || user.subjectType !== 'MEMBER') return true;

    const [member] = await this.db
      .select({ registrationCompletedAt: users.registrationCompletedAt })
      .from(users)
      .where(and(eq(users.id, Number(user.subjectId)), isNull(users.deletedAt)))
      .limit(1);

    if (!member?.registrationCompletedAt) {
      throw new ForbiddenException({
        error: {
          code: 'REGISTRATION_REQUIRED',
          message: 'Complete your Sahakar 360 registration first — only registered members can do this.',
        },
      });
    }
    return true;
  }
}
