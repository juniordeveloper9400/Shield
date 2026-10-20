import { memberLabStage } from '../../src/modules/care/booking.service';

describe('memberLabStage', () => {
  const base = { status: 'REQUESTED', isVerified: false, billExists: false, billStatus: null as string | null };

  it('is Requested until the admin verifies the bill', () => {
    expect(memberLabStage(base)).toBe('REQUESTED');
  });

  it('becomes Verified once the bill is verified', () => {
    expect(memberLabStage({ ...base, isVerified: true })).toBe('VERIFIED');
    // Confirming the booking does not move it past Verified by itself.
    expect(memberLabStage({ ...base, status: 'CONFIRMED', isVerified: true })).toBe('VERIFIED');
  });

  it('becomes Billed when it has been converted to a bill', () => {
    expect(memberLabStage({ ...base, status: 'CONFIRMED', isVerified: true, billExists: true, billStatus: 'PENDING' })).toBe('BILLED');
  });

  it('is Completed once the bill is paid or the report is ready', () => {
    expect(memberLabStage({ ...base, isVerified: true, billExists: true, billStatus: 'PAID' })).toBe('COMPLETED');
    expect(memberLabStage({ ...base, status: 'REPORT_READY' })).toBe('COMPLETED');
  });

  it('stays Cancelled whatever else was done', () => {
    expect(memberLabStage({ ...base, status: 'CANCELLED', isVerified: true, billExists: true, billStatus: 'PAID' })).toBe('CANCELLED');
  });
});
