import { JwtService } from '@nestjs/jwt';
import type { ConfigService } from '@nestjs/config';
import { TokenService } from '../../src/modules/auth/token.service';
import type { Env } from '../../src/config/env';
import type { RequestSubject } from '../../src/modules/auth/session.types';

function fakeConfig(): ConfigService<Env, true> {
  const values: Record<string, string> = {
    JWT_ACCESS_SECRET: 'a'.repeat(32),
    JWT_REFRESH_SECRET: 'b'.repeat(32),
  };
  return { get: (key: string) => values[key] } as unknown as ConfigService<Env, true>;
}

describe('TokenService', () => {
  const svc = new TokenService(new JwtService(), fakeConfig());

  it('issues an access token whose verified payload round-trips the subject', async () => {
    const subject: RequestSubject = { sessionId: 's1', subjectType: 'MEMBER', subjectId: '42' };
    const { token, expiresIn } = await svc.issueAccessToken(subject);

    expect(expiresIn).toBe(15 * 60);
    const verified = await svc.verifyAccessToken(token);
    expect(verified).toEqual(subject);
  });

  it('carries role and store scope for staff subjects', async () => {
    const subject: RequestSubject = {
      sessionId: 's2',
      subjectType: 'STAFF',
      subjectId: '7',
      role: 'PHARMACY',
      storeId: 3,
    };
    const { token } = await svc.issueAccessToken(subject);
    const verified = await svc.verifyAccessToken(token);
    expect(verified).toEqual(subject);
  });

  it('rejects a token signed with a different secret', async () => {
    const other = new TokenService(new JwtService(), {
      get: (key: string) => (key === 'JWT_ACCESS_SECRET' ? 'c'.repeat(32) : 'd'.repeat(32)),
    } as unknown as ConfigService<Env, true>);

    const { token } = await other.issueAccessToken({ sessionId: 's3', subjectType: 'MEMBER', subjectId: '1' });
    await expect(svc.verifyAccessToken(token)).rejects.toThrow();
  });

  it('generates distinct, high-entropy refresh tokens with a deterministic, verifiable hash', () => {
    const a = svc.generateRefreshToken();
    const b = svc.generateRefreshToken();

    expect(a.raw).not.toBe(b.raw);
    expect(a.raw.length).toBeGreaterThan(40);
    expect(svc.hashRefreshToken(a.raw)).toBe(a.hash);
    expect(svc.hashRefreshToken(a.raw)).not.toBe(svc.hashRefreshToken(b.raw));
  });
});
