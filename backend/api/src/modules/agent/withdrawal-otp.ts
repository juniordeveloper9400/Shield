import { ForbiddenException } from '@nestjs/common';
import type { VerifiedFirebaseToken } from '../auth/session.types';

/** How long after the agent's SMS code was confirmed an approval may still use it. */
export const APPROVAL_OTP_MAX_AGE_SECONDS = 5 * 60;

/** Clock skew tolerated between this server and Firebase's `auth_time`. */
const CLOCK_SKEW_SECONDS = 60;

const lastTenDigits = (phone: string | undefined) => (phone ?? '').replace(/\D/g, '').slice(-10);

const refused = () =>
  new ForbiddenException(
    'OTP verification is required: send a code to the agent’s registered phone, enter it, then approve within 5 minutes.',
  );

/**
 * A withdrawal is approved only by someone who proved they hold the agent's
 * registered phone. The admin console sends a Firebase phone-auth SMS to that
 * number, the code is read back and confirmed, and the resulting ID token is
 * sent with the approval. This checks the token (already signature-verified)
 * is a phone-auth token for *this agent's* number and was minted just now.
 */
export function assertApprovalOtp(
  token: VerifiedFirebaseToken,
  agentPhone: string,
  nowSeconds = Math.floor(Date.now() / 1000),
): void {
  const expected = lastTenDigits(agentPhone);
  if (expected.length !== 10 || lastTenDigits(token.phoneNumber) !== expected) throw refused();
  if (token.authTime === undefined) throw refused();
  const age = nowSeconds - token.authTime;
  if (age > APPROVAL_OTP_MAX_AGE_SECONDS || age < -CLOCK_SKEW_SECONDS) throw refused();
}
