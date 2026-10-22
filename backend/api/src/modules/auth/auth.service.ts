import { ForbiddenException, Inject, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { compare } from 'bcryptjs';
import { and, eq, isNull } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { adminUser, users } from '../../db/schema';
import { authSession, refreshToken } from '../../db/schema/backend-auth';
import { TokenService, REFRESH_TOKEN_TTL_MS } from './token.service';
import type { IssuedTokens, RequestSubject } from './session.types';
import { OtpService, type VerifyMsg91Result } from '../otp/otp.service';
import { AuditService } from '../audit/audit.service';

export interface RequestContext {
  userAgent?: string;
  ip?: string;
}

@Injectable()
export class AuthService {
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    private readonly tokens: TokenService,
    private readonly otp: OtpService,
    private readonly audit: AuditService,
  ) {}

  /**
   * Whether [phone] already has a live `app.users` row — a pre-OTP
   * check so the client can decide "sign in" vs. "create
   * account" UI before it ever sends an OTP (the login screen's own doc on
   * `AuthService.hasAccount`). Deliberately not gated behind OTP
   * verification — that's the whole point, it runs *before* an OTP is
   * even requested — so this is the one auth route that hands back a yes/no
   * about phone numbers to an unauthenticated caller. `AuthThrottle` on the
   * controller route (10/min/IP) keeps that from being a practical
   * enumeration tool; it was already answerable, unthrottled, via the raw
   * Neon SQL every pre-migration client ships — this route is strictly
   * tighter than the status quo it replaces, not a new exposure.
   */
  async phoneExists(phone: string): Promise<boolean> {
    const [row] = await this.db
      .select({ id: users.id })
      .from(users)
      .where(and(eq(users.phone, phone), isNull(users.deletedAt)))
      .limit(1);
    return !!row;
  }

  /**
   * Sends the member-login OTP via MSG91. See OtpService.sendMsg91Otp for
   * the MSG91 side; this exists mainly so the controller has a thin,
   * unauthenticated route to call before any login decision is made.
   */
  async sendMemberOtp(phone: string): Promise<VerifyMsg91Result> {
    return this.otp.sendMsg91Otp(phone);
  }

  /**
   * Member login, MSG91-backed: verifies [code] against the last
   * [sendMemberOtp] for [phone] via MSG91, then issues a session for the
   * matching app.users row. We do NOT create rows here: a verified phone
   * with no member row means the member hasn't registered yet, which is the
   * caller's job to handle. Keyed on the bare phone number, the real unique
   * identity (`member_phone_key`); the legacy `firebase_uid` column is not
   * read.
   *
   * Throws the same 401 shape whether the code was wrong/expired *or*
   * MSG91 itself is unreachable/unconfigured — deliberately not
   * distinguished to the client beyond OtpService's own `reason` string,
   * since neither case is something retrying the same code fixes.
   */
  async exchangeMemberPhone(phone: string, code: string, ctx: RequestContext): Promise<IssuedTokens> {
    const result = await this.otp.verifyMsg91Otp(phone, code);
    if (!result.ok) {
      throw new UnauthorizedException({
        error: { code: 'UNAUTHORIZED', message: result.reason ?? 'That code is not right or has expired.' },
      });
    }

    const [member] = await this.db
      .select()
      .from(users)
      .where(and(eq(users.phone, phone), isNull(users.deletedAt)))
      .limit(1);

    if (!member) {
      throw new NotFoundException({
        error: { code: 'NOT_FOUND', message: 'No member registered for this number yet' },
      });
    }

    return this.createSession('MEMBER', String(member.id), undefined, undefined, ctx);
  }

  /**
   * Member self-registration, MSG91-backed: verifies [code] the same way
   * [exchangeMemberPhone] does, then finds-or-creates the app.users row by
   * [phone]. A live account keeps its own name — signing in again must
   * never silently rename the member; a reactivated deleted one, or a row
   * with no usable name, takes the incoming [name].
   */
  async registerMemberByPhone(phone: string, code: string, name: string, ctx: RequestContext): Promise<IssuedTokens> {
    const result = await this.otp.verifyMsg91Otp(phone, code);
    if (!result.ok) {
      throw new UnauthorizedException({
        error: { code: 'UNAUTHORIZED', message: result.reason ?? 'That code is not right or has expired.' },
      });
    }

    // Deliberately not filtered to isNull(deletedAt): phone carries a UNIQUE
    // constraint (member_phone_key), so a deleted account's row still
    // occupies that phone. Reactivating it is what lets a member who
    // deleted their account sign up again on the same number; filtering
    // would fall through to the insert and hit that constraint as a 500.
    const [byPhone] = await this.db.select().from(users).where(eq(users.phone, phone)).limit(1);

    let memberId: number;
    if (byPhone) {
      const wasDeleted = byPhone.deletedAt !== null;
      const hasUsableName = !wasDeleted && byPhone.name.trim() !== '';
      await this.db
        .update(users)
        .set({ deletedAt: null, name: hasUsableName ? byPhone.name : name })
        .where(eq(users.id, byPhone.id));
      memberId = byPhone.id;
    } else {
      const [created] = await this.db.insert(users).values({ phone, name }).returning();
      memberId = created.id;
    }

    return this.createSession('MEMBER', String(memberId), undefined, undefined, ctx);
  }

  /**
   * Member login, MSG91 Widget-backed: the client already ran MSG91's own
   * JS widget (in a browser, or a WebView on native) and got back a signed
   * access-token proving it holds [phone] — this verifies that token
   * server-side via `verifyMsg91AccessToken` (the one MSG91 endpoint
   * actually confirmed from the dashboard's own docs) and issues a session,
   * same contract as [exchangeMemberPhone]. This is the path native apps
   * use instead of [exchangeMemberPhone]/[sendMemberOtp]: MSG91's Widget
   * has no real server-to-server "send" — see otp.service.ts's own doc on
   * why `sendMsg91Otp`/`verifyMsg91Otp` turned out not to be a supported
   * flow at all.
   */
  async exchangeMemberWidgetToken(accessToken: string, phone: string, ctx: RequestContext): Promise<IssuedTokens> {
    const result = await this.otp.verifyMsg91AccessToken(accessToken, phone);
    if (!result.ok) {
      throw new UnauthorizedException({
        error: { code: 'UNAUTHORIZED', message: result.reason ?? 'That code is not right or has expired.' },
      });
    }

    const [member] = await this.db
      .select()
      .from(users)
      .where(and(eq(users.phone, phone), isNull(users.deletedAt)))
      .limit(1);

    if (!member) {
      throw new NotFoundException({
        error: { code: 'NOT_FOUND', message: 'No member registered for this number yet' },
      });
    }

    return this.createSession('MEMBER', String(member.id), undefined, undefined, ctx);
  }

  /**
   * Member self-registration, MSG91 Widget-backed — see
   * [exchangeMemberWidgetToken] for the access-token verification and
   * [registerMemberByPhone] for the identical find-or-create/reactivation
   * rules this otherwise follows.
   */
  async registerMemberByWidgetToken(
    accessToken: string,
    phone: string,
    name: string,
    ctx: RequestContext,
  ): Promise<IssuedTokens> {
    const result = await this.otp.verifyMsg91AccessToken(accessToken, phone);
    if (!result.ok) {
      throw new UnauthorizedException({
        error: { code: 'UNAUTHORIZED', message: result.reason ?? 'That code is not right or has expired.' },
      });
    }

    const [byPhone] = await this.db.select().from(users).where(eq(users.phone, phone)).limit(1);

    let memberId: number;
    if (byPhone) {
      const wasDeleted = byPhone.deletedAt !== null;
      const hasUsableName = !wasDeleted && byPhone.name.trim() !== '';
      await this.db
        .update(users)
        .set({ deletedAt: null, name: hasUsableName ? byPhone.name : name })
        .where(eq(users.id, byPhone.id));
      memberId = byPhone.id;
    } else {
      const [created] = await this.db.insert(users).values({ phone, name }).returning();
      memberId = created.id;
    }

    return this.createSession('MEMBER', String(memberId), undefined, undefined, ctx);
  }

  /**
   * Staff login: login id + password, checked directly against the bcrypt
   * hash on app.admin_user. Deliberately the same generic error for "no such
   * account" and "wrong password" — distinguishing them lets an attacker
   * enumerate valid staff login ids.
   */
  async loginStaff(loginId: string, password: string, ctx: RequestContext): Promise<IssuedTokens> {
    const invalid = () =>
      new UnauthorizedException({ error: { code: 'UNAUTHORIZED', message: 'Invalid login id or password' } });
    // No authenticated actor exists yet at a login attempt — AuditInterceptor
    // can't cover this one itself (see its own doc) — so every path through
    // here, success or failure, logs explicitly instead.
    const logFailure = (staff?: { id: number; name: string; role: string; storeId: number | null }) =>
      this.audit.record({
        staffId: staff?.id ?? null,
        staffLoginId: loginId,
        staffName: staff?.name ?? '(unknown)',
        staffRole: staff?.role ?? '',
        storeId: staff?.storeId ?? null,
        action: 'LOGIN_FAILED',
        method: 'POST',
        path: '/v1/staff/auth/session',
        statusCode: 401,
        ip: ctx.ip ?? null,
      });

    const [staff] = await this.db.select().from(adminUser).where(eq(adminUser.loginId, loginId)).limit(1);
    if (!staff || !staff.passwordHash) {
      logFailure();
      throw invalid();
    }

    const ok = await compare(password, staff.passwordHash);
    if (!ok) {
      logFailure(staff);
      throw invalid();
    }

    if (!staff.isActive) {
      this.audit.record({
        staffId: staff.id,
        staffLoginId: staff.loginId,
        staffName: staff.name,
        staffRole: staff.role,
        storeId: staff.storeId,
        action: 'LOGIN_FAILED',
        method: 'POST',
        path: '/v1/staff/auth/session',
        statusCode: 403,
        ip: ctx.ip ?? null,
      });
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Staff account is deactivated' } });
    }

    this.audit.record({
      staffId: staff.id,
      staffLoginId: staff.loginId,
      staffName: staff.name,
      staffRole: staff.role,
      storeId: staff.storeId,
      action: 'LOGIN',
      method: 'POST',
      path: '/v1/staff/auth/session',
      statusCode: 200,
      ip: ctx.ip ?? null,
    });
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
