import { isFailureShape, lastTenDigitsMatch, verifiedPhoneFrom } from '../../src/modules/otp/otp.service';

describe('lastTenDigitsMatch', () => {
  it('matches however each side carries the +91 country code', () => {
    expect(lastTenDigitsMatch('9876543210', '+91 98765 43210')).toBe(true);
    expect(lastTenDigitsMatch('919876543210', '9876543210')).toBe(true);
  });

  it('refuses two different numbers', () => {
    expect(lastTenDigitsMatch('9876543210', '9999999999')).toBe(false);
  });

  it('refuses a short or malformed value rather than matching by accident', () => {
    expect(lastTenDigitsMatch('12345', '9876543210')).toBe(false);
  });
});

describe('isFailureShape', () => {
  it('reads MSG91-style type fields', () => {
    expect(isFailureShape({ type: 'error', message: 'bad token' })).toBe(true);
    expect(isFailureShape({ type: 'failure' })).toBe(true);
    expect(isFailureShape({ type: 'success' })).toBe(false);
    expect(isFailureShape(null)).toBe(false);
  });
});

describe('verifiedPhoneFrom', () => {
  it('finds a top-level mobile/identifier/phone field', () => {
    expect(verifiedPhoneFrom({ mobile: '919876543210' })).toBe('919876543210');
    expect(verifiedPhoneFrom({ identifier: '9876543210' })).toBe('9876543210');
    expect(verifiedPhoneFrom({ phone: '9876543210' })).toBe('9876543210');
  });

  it('finds a phone nested under message or data, one level deep', () => {
    expect(verifiedPhoneFrom({ message: { mobile: '9876543210' } })).toBe('9876543210');
    expect(verifiedPhoneFrom({ data: { identifier: '919876543210' } })).toBe('919876543210');
  });

  it('accepts message itself as the plain identifier string', () => {
    expect(verifiedPhoneFrom({ message: '919876543210' })).toBe('919876543210');
  });

  it('returns null when nothing resembling a phone number is found', () => {
    expect(verifiedPhoneFrom({ type: 'success' })).toBeNull();
    expect(verifiedPhoneFrom({ message: 'ok' })).toBeNull();
    expect(verifiedPhoneFrom(null)).toBeNull();
  });
});
