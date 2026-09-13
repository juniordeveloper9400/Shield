import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { randomBytes, createHash } from 'node:crypto';
import type { Env } from '../../config/env';
import type { AdminRole, IssuedTokens, RequestSubject, SubjectType } from './session.types';

const ACCESS_TOKEN_TTL_SECONDS = 15 * 60; // 15 min
export const REFRESH_TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

interface AccessTokenPayload {
  jti: string; // per-issuance nonce — guarantees uniqueness even if issued within the same second, and gives audit logging something to key on
  sid: string;
  sty: SubjectType;
  sub: string;
  role?: AdminRole;
  storeId?: number | null;
}

/**
 * Issues this service's OWN tokens — separate from the Firebase ID token a
 * client used to authenticate. Access tokens are short-lived by design so a
 * leaked one has a small exploitation window; refresh tokens are opaque,
 * stored only as a hash, and are what actually gets revoked on logout.
 */
@Injectable()
export class TokenService {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService<Env, true>,
  ) {}

  async issueAccessToken(subject: RequestSubject): Promise<{ token: string; expiresIn: number }> {
    const payload: AccessTokenPayload = {
      jti: randomBytes(16).toString('hex'),
      sid: subject.sessionId,
      sty: subject.subjectType,
      sub: subject.subjectId,
      role: subject.role,
      storeId: subject.storeId,
    };
    const token = await this.jwt.signAsync(payload, {
      secret: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
      expiresIn: ACCESS_TOKEN_TTL_SECONDS,
    });
    return { token, expiresIn: ACCESS_TOKEN_TTL_SECONDS };
  }

  async verifyAccessToken(token: string): Promise<RequestSubject> {
    const payload = await this.jwt.verifyAsync<AccessTokenPayload>(token, {
      secret: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
    });
    return {
      sessionId: payload.sid,
      subjectType: payload.sty,
      subjectId: payload.sub,
      role: payload.role,
      storeId: payload.storeId,
    };
  }

  /** A raw refresh token to hand to the client, and its hash to store. */
  generateRefreshToken(): { raw: string; hash: string; expiresAt: Date } {
    const raw = randomBytes(48).toString('base64url');
    return {
      raw,
      hash: this.hashRefreshToken(raw),
      expiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_MS),
    };
  }

  hashRefreshToken(raw: string): string {
    // Refresh tokens are high-entropy random values, not user-chosen
    // passwords — a fast cryptographic hash is the correct tool here
    // (unlike password storage, which needs a slow, salted hash).
    return createHash('sha256').update(raw).digest('hex');
  }

  async issuePair(subject: RequestSubject): Promise<IssuedTokens & { refreshTokenHash: string; refreshExpiresAt: Date }> {
    const access = await this.issueAccessToken(subject);
    const refresh = this.generateRefreshToken();
    return {
      accessToken: access.token,
      expiresIn: access.expiresIn,
      refreshToken: refresh.raw,
      refreshTokenHash: refresh.hash,
      refreshExpiresAt: refresh.expiresAt,
    };
  }
}
