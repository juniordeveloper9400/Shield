import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/**
 * Tracks a throttle bucket by the signed-in member/agent/admin (`request.user`,
 * set by `AuthGuard` — see `common/decorators/current-user.decorator.ts`),
 * falling back to the plain IP-based default for routes nothing has
 * authenticated (sign-in, register, public catalogue reads).
 *
 * The default `ThrottlerGuard` tracks by IP alone. That's fine for a blanket
 * anti-abuse ceiling, but wrong for a per-member limit like
 * `ReceiptUploadThrottle` (three receipts an hour): members behind the same
 * NAT — an office, a shared mobile tower — would throttle each other, while
 * this is exactly what a real member's own three-per-hour is meant to track.
 */
@Injectable()
export class PerSubjectThrottlerGuard extends ThrottlerGuard {
  protected override async getTracker(req: Record<string, any>): Promise<string> {
    const subjectId = req.user?.subjectId;
    return subjectId ? `user:${subjectId}` : `ip:${req.ip}`;
  }
}
