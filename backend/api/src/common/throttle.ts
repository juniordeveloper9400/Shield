import { Throttle } from '@nestjs/throttler';

/**
 * Tighter-than-default limits for the routes docs/security.md calls out
 * specifically: auth/OTP-adjacent exchange and financial mutations. The
 * global default (ThrottlerModule.forRoot in app.module.ts) is the floor
 * every other route gets; these are stricter ceilings on top of it.
 */
export const AuthThrottle = () => Throttle({ default: { limit: 10, ttl: 60_000 } });
export const FinancialThrottle = () => Throttle({ default: { limit: 20, ttl: 60_000 } });

/**
 * A receipt/proof-of-payment upload — a manual bank-transfer claim on an
 * order, or the receipt that comes with a Sahakar HealthPass card
 * submission. Both carry an image in the request body (a data: URI), so
 * FinancialThrottle's 20/minute is nowhere near tight enough: a script (or
 * a confused member double- and triple-tapping "Submit") could otherwise
 * hammer the database with large payloads indefinitely. Three genuine
 * receipts an hour is already generous — nobody legitimately re-submits a
 * payment proof more than that in one sitting.
 */
export const ReceiptUploadThrottle = () => Throttle({ default: { limit: 3, ttl: 60 * 60_000 } });
