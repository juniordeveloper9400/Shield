import { ForbiddenException } from '@nestjs/common';
import { APPROVAL_OTP_MAX_AGE_SECONDS, assertApprovalOtp } from '../../src/modules/agent/withdrawal-otp';

const NOW = 1_800_000_000;
const token = (over: Partial<{ phoneNumber: string; authTime: number }> = {}) => ({
  uid: 'u1',
  phoneNumber: '+919876543210',
  authTime: NOW - 30,
  ...over,
});

describe('assertApprovalOtp', () => {
  it('accepts a fresh code confirmed on the agent’s own number, however the number is stored', () => {
    expect(() => assertApprovalOtp(token(), '9876543210', NOW)).not.toThrow();
    expect(() => assertApprovalOtp(token(), '+91 98765 43210', NOW)).not.toThrow();
  });

  it('refuses a code confirmed on a different phone', () => {
    expect(() => assertApprovalOtp(token({ phoneNumber: '+919999999999' }), '9876543210', NOW)).toThrow(ForbiddenException);
  });

  it('refuses a token that is not a phone-auth token', () => {
    expect(() => assertApprovalOtp({ uid: 'u1', email: 'a@b.c', authTime: NOW }, '9876543210', NOW)).toThrow(ForbiddenException);
  });

  it('refuses a stale code and a token with no sign-in time', () => {
    const stale = token({ authTime: NOW - APPROVAL_OTP_MAX_AGE_SECONDS - 1 });
    expect(() => assertApprovalOtp(stale, '9876543210', NOW)).toThrow(ForbiddenException);
    expect(() => assertApprovalOtp({ uid: 'u1', phoneNumber: '+919876543210' }, '9876543210', NOW)).toThrow(ForbiddenException);
  });

  it('refuses a sign-in time from the future and an agent with no usable phone', () => {
    expect(() => assertApprovalOtp(token({ authTime: NOW + 3600 }), '9876543210', NOW)).toThrow(ForbiddenException);
    expect(() => assertApprovalOtp(token(), '', NOW)).toThrow(ForbiddenException);
  });
});
