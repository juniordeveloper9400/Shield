import { ForbiddenException, Inject, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { compare } from 'bcryptjs';
import { and, eq, isNull } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { adminUser, users } from '../../db/schema';
import { authSession, refreshToken } from '../../db/schema/backend-auth';
import { TokenService, REFRESH_TOKEN_TTL_MS } from './token.service';
import { FIREBASE_VERIFIER, type FirebaseVerifier, type IssuedTokens, type RequestSubject } from './session.types';

export interface RequestContext {
  userAgent?: string;
  ip?: string;
}

@Injectable()
export class AuthService {
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    @Inject(FIREBASE_VERIFIER) private readonly firebase: FirebaseVerifier,
    private readonly tokens: TokenService,
  ) {}

  /**
   * Member login: the client already completed Firebase phone auth. We only
   * verify the resulting token and issue our own session — we do NOT create
   * app.users rows here. A token with no matching member row means the
   * member hasn't finished registration; that's the caller's job to handle,
   * not something this endpoint silently papers over.
   */
  async exchangeMemberToken(idToken: string, ctx: RequestContext): Promise<IssuedTokens> {
    const decoded = await this.firebase.verifyIdToken(idToken);

    const [member] = await this.db
      .select()
      .from(users)
      .where(and(eq(users.firebaseUid, decoded.uid), isNull(users.deletedAt)))
      .limit(1);

    if (!member) {
      throw new NotFoundException({
        error: { code: 'NOT_FOUND', message: 'No member registered for this identity yet' },
      });
    }

    return this.createSession('MEMBER', String(member.id), undefined, undefined, ctx);
  }

  /**
   * Staff login: login id + password, checked directly against the bcrypt
   * hash on app.admin_user — no Firebase involved (that's member-only, see
   * exchangeMemberToken). Deliberately the same generic error for "no such
   * account" and "wrong password" — distinguishing them lets an attacker
   * enumerate valid staff login ids.
   */
  async loginStaff(loginId: string, password: string, ctx: RequestContext): Promise<IssuedTokens> {
    const invalid = () =>
      new UnauthorizedException({ error: { code: 'UNAUTHORIZED', message: 'Invalid login id or password' } });

    const [staff] = await this.db.select().from(adminUser).where(eq(adminUser.loginId, loginId)).limit(1);
    if (!staff || !staff.passwordHash) throw invalid();

    const ok = await compare(password, staff.passwordHash);
    if (!ok) throw invalid();

    if (!staff.isActive) {
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Staff account is deactivated' } });
    }

    return this.createSession('STAFF', String(staff.id), staff.role, staff.storeId, ctx);
  }

  private async createSession(
    subjectType: 'MEMBER' | 'STAFF',
    subjectId: string,
    role: RequestSubject['role'],
    storeId: number | null | undefined,
    ctx: RequestContext,
  ): Promise<IssuedTokens> {
    const [session] = await this.db
      .insert(authSession)
      .values({
        id: randomUUID(),
        subjectType,
        subjectId,
        expiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_MS),
        userAgent: ctx.userAgent,
        ip: ctx.ip,
      })
      .returning();

    const subject: RequestSubject = { sessionId: session.id, subjectType, subjectId, role, storeId };
    const issued = await this.tokens.issuePair(subject);

    await this.db.insert(refreshToken).values({
      id: randomUUID(),
      sessionId: session.id,
      tokenHash: issued.refreshTokenHash,
      expiresAt: issued.refreshExpiresAt,
    });

    if (subjectType === 'MEMBER') {
      await this.db.update(users).set({ lastLoginAt: new Date() }).where(eq(users.id, Number(subjectId)));
    } else {
      await this.db.update(adminUser).set({ lastLoginAt: new Date() }).where(eq(adminUser.id, Number(subjectId)));
    }

    return { accessToken: issued.accessToken, refreshToken: issued.refreshToken, expiresIn: issued.expiresIn };
  }

  /** Rotates a refresh token: the old one is single-use. */
  async refresh(rawRefreshToken: string): Promise<IssuedTokens> {
    const hash = this.tokens.hashRefreshToken(rawRefreshToken);
    const [stored] = await this.db.select().from(refreshToken).where(eq(refreshToken.tokenHash, hash)).limit(1);

    if (!stored || stored.usedAt || stored.expiresAt < new Date()) {
      throw new UnauthorizedException({ error: { code: 'UNAUTHORIZED', message: 'Refresh token invalid or expired' } });
    }

    const [session] = await this.db.select().from(authSession).where(eq(authSession.id, stored.sessionId)).limit(1);
    if (!session || session.revokedAt || session.expiresAt < new Date()) {
      throw new UnauthorizedException({ error: { code: 'UNAUTHORIZED', message: 'Session is no longer active' } });
    }

    await this.db.update(refreshToken).set({ usedAt: new Date() }).where(eq(refreshToken.id, stored.id));

    const subject: RequestSubject = {
      sessionId: session.id,
      subjectType: session.subjectType,
      subjectId: session.subjectId,
    };
    if (session.subjectType === 'STAFF') {
      const [staff] = await this.db.select().from(adminUser).where(eq(adminUser.id, Number(session.subjectId))).limit(1);
      if (!staff || !staff.isActive) {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Staff account is deactivated' } });
      }
      subject.role = staff.role;
      subject.storeId = staff.storeId;
    }

    const issued = await this.tokens.issuePair(subject);
    await this.db.insert(refreshToken).values({
      id: randomUUID(),
      sessionId: session.id,
      tokenHash: issued.refreshTokenHash,
      expiresAt: issued.refreshExpiresAt,
    });

    return { accessToken: issued.accessToken, refreshToken: issued.refreshToken, expiresIn: issued.expiresIn };
  }

  async revokeSession(sessionId: string): Promise<void> {
    await this.db.update(authSession).set({ revokedAt: new Date() }).where(eq(authSession.id, sessionId));
  }

  async revokeAllSessions(subjectType: 'MEMBER' | 'STAFF', subjectId: string): Promise<void> {
    await this.db
      .update(authSession)
      .set({ revokedAt: new Date() })
      .where(and(eq(authSession.subjectType, subjectType), eq(authSession.subjectId, subjectId), isNull(authSession.revokedAt)));
  }

  async isSessionActive(sessionId: string): Promise<boolean> {
    const [session] = await this.db.select().from(authSession).where(eq(authSession.id, sessionId)).limit(1);
    return !!session && !session.revokedAt && session.expiresAt > new Date();
  }
}
