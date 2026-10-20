import { DEFAULT_ALLOWED_ORIGINS, isOriginAllowed, parseAllowedOrigins } from '../../src/common/cors';

describe('CORS allowlist', () => {
  const allowed = parseAllowedOrigins('https://admin.example.com/, https://other.example.com');

  it('lets native apps and servers through (no Origin header)', () => {
    expect(isOriginAllowed(undefined, allowed, true)).toBe(true);
  });

  it('allows the built-in hosts and anything added by env', () => {
    for (const origin of DEFAULT_ALLOWED_ORIGINS) expect(isOriginAllowed(origin, allowed, true)).toBe(true);
    expect(isOriginAllowed('https://admin.example.com', allowed, true)).toBe(true);
    expect(isOriginAllowed('https://other.example.com', allowed, true)).toBe(true);
  });

  it('blocks any other website', () => {
    expect(isOriginAllowed('https://evil.example.org', allowed, true)).toBe(false);
    expect(isOriginAllowed('https://shield-evil.vercel.app', allowed, true)).toBe(false);
  });

  it('trusts localhost only outside production', () => {
    expect(isOriginAllowed('http://localhost:5173', allowed, false)).toBe(true);
    expect(isOriginAllowed('http://localhost:5173', allowed, true)).toBe(false);
  });
});
