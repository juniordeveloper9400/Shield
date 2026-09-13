import { Throttle } from '@nestjs/throttler';

/**
 * Tighter-than-default limits for the routes docs/security.md calls out
 * specifically: auth/OTP-adjacent exchange and financial mutations. The
 * global default (ThrottlerModule.forRoot in app.module.ts) is the floor
 * every other route gets; these are stricter ceilings on top of it.
 */
export const AuthThrottle = () => Throttle({ default: { limit: 10, ttl: 60_000 } });
export const FinancialThrottle = () => Throttle({ default: { limit: 20, ttl: 60_000 } });
