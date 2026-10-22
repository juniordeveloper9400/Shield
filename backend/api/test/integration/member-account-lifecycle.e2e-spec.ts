process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { eq } from 'drizzle-orm';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { IdentityService } from '../../src/modules/identity/identity.service';
import { users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { OtpService } from '../../src/modules/otp/otp.service';
import { FakeOtpService, memberLogin, memberRegister } from './fake-otp';

// A separate app/spec from auth-flow.e2e-spec.ts — that file's own tests
// already sit close to AuthThrottle's 10/min ceiling on
// /v1/member/auth/session; this file's own fresh app instance gets its own
// in-memory throttle window rather than sharing (and tipping over) that
// one's.
describe('Member account lifecycle (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;

  beforeAll(async () => {
    db = createTestDb();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(OtpService)
      .useValue(new FakeOtpService())
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('POST /v1/member/auth/phone-lookup', () => {
    it('reports true for a phone with a live account', async () => {
      await db.insert(users).values({ phone: '9199999001', name: 'Has Account' });

      const result = await request(app.getHttpServer())
        .post('/v1/member/auth/phone-lookup')
        .send({ phone: '9199999001' })
        .expect(200);
      expect(result.body).toEqual({ exists: true });
    });

    it('reports false for a phone with no account', async () => {
      const result = await request(app.getHttpServer())
        .post('/v1/member/auth/phone-lookup')
        .send({ phone: '9199999002' })
        .expect(200);
      expect(result.body).toEqual({ exists: false });
    });

    it('reports false for a phone whose only row is soft-deleted', async () => {
      await db.insert(users).values({ phone: '9199999003', name: 'Deleted user', deletedAt: new Date() });

      const result = await request(app.getHttpServer())
        .post('/v1/member/auth/phone-lookup')
        .send({ phone: '9199999003' })
        .expect(200);
      expect(result.body).toEqual({ exists: false });
    });

    it('rejects a body that is not a 10-digit Indian mobile number', async () => {
      await request(app.getHttpServer())
        .post('/v1/member/auth/phone-lookup')
        .send({ phone: '12345' })
        .expect(400);
    });
  });

  describe('a deleted account reactivates on re-registration, instead of hitting the phone UNIQUE constraint', () => {
    it('reactivates the same row, clearing deletedAt and taking the freshly typed name', async () => {
      const [created] = await db
        .insert(users)
        .values({ phone: '9199999099', name: 'Soon Deleted', firebaseUid: 'to-be-deleted-uid' })
        .returning();

      // Soft-delete it the same way IdentityService.deleteAccount does.
      await db
        .update(users)
        .set({ name: 'Deleted user', firebaseUid: null, deletedAt: new Date() })
        .where(eq(users.id, created.id));

      // The member comes back and re-verifies the same phone number.
      const register = await memberRegister(app, '9199999099', 'Reactivated Member')
        .expect(200);

      const rows = await db.select().from(users).where(eq(users.phone, '9199999099'));
      expect(rows).toHaveLength(1); // reactivated the same row — not a second one
      expect(rows[0].id).toBe(created.id);
      expect(rows[0].deletedAt).toBeNull();
      expect(rows[0].name).toBe('Reactivated Member');

      const me = await request(app.getHttpServer())
        .get('/v1/member/me')
        .set('Authorization', `Bearer ${register.body.accessToken}`)
        .expect(200);
      expect(me.body.name).toBe('Reactivated Member');
    });

    it("keeps a live account's stored name on a plain re-registration — reactivation-only behavior does not leak into the ordinary case", async () => {
      await db.insert(users).values({ phone: '9199999098', name: 'Kept Name' });

      await memberRegister(app, '9199999098', 'Typed Over It')
        .expect(200);

      const [row] = await db.select().from(users).where(eq(users.phone, '9199999098'));
      expect(row.name).toBe('Kept Name'); // not renamed by the typed-in name
      expect(row.deletedAt).toBeNull();
    });
  });

  describe('DELETE /v1/member/me', () => {
    it("clears the member's personal fields, keeps the phone, and revokes the session that deleted it", async () => {
      await db
        .insert(users)
        .values({ phone: '9199999077', name: 'Delete Me', firebaseUid: 'delete-me-uid', email: 'delete@example.com' });

      const login = await memberLogin(app, '9199999077')
        .expect(200);
      const token = login.body.accessToken as string;

      await request(app.getHttpServer()).delete('/v1/member/me').set('Authorization', `Bearer ${token}`).expect(204);

      const [row] = await db.select().from(users).where(eq(users.phone, '9199999077'));
      expect(row.name).toBe('Deleted user');
      expect(row.email).toBeNull();
      expect(row.firebaseUid).toBeNull();
      expect(row.deletedAt).not.toBeNull();
      expect(row.phone).toBe('9199999077'); // kept — the reactivation key

      // The very token that made the delete call is itself revoked by it.
      await request(app.getHttpServer()).get('/v1/member/me').set('Authorization', `Bearer ${token}`).expect(401);
    });

    it('404s deleting an account that is already deleted', async () => {
      await db.insert(users).values({ phone: '9199999078', name: 'Delete Twice', firebaseUid: 'delete-twice-uid' });

      const login = await memberLogin(app, '9199999078')
        .expect(200);
      await request(app.getHttpServer())
        .delete('/v1/member/me')
        .set('Authorization', `Bearer ${login.body.accessToken}`)
        .expect(204);

      // Re-login is impossible post-delete (exchangeMemberPhone itself
      // filters deletedAt), so exercise the idempotency guard directly on
      // the already-wired IdentityService this app instance holds.
      const identity = app.get(IdentityService);
      const [deletedRow] = await db.select().from(users).where(eq(users.phone, '9199999078'));
      await expect(identity.deleteAccount(deletedRow.id)).rejects.toMatchObject({ status: 404 });
    });

    it('rejects an unauthenticated delete', async () => {
      await request(app.getHttpServer()).delete('/v1/member/me').expect(401);
    });
  });

  describe('POST /v1/member/me/touch-login', () => {
    it('bumps last_login_at for the signed-in member', async () => {
      await db
        .insert(users)
        .values({ phone: '9199999090', name: 'Touch Login', firebaseUid: 'touch-login-uid', lastLoginAt: null });

      const login = await memberLogin(app, '9199999090')
        .expect(200);
      const token = login.body.accessToken as string;

      // createSession itself already set last_login_at on the sign-in
      // above; clear it so this call is the only thing that could set it.
      await db.update(users).set({ lastLoginAt: null }).where(eq(users.phone, '9199999090'));

      await request(app.getHttpServer())
        .post('/v1/member/me/touch-login')
        .set('Authorization', `Bearer ${token}`)
        .expect(204);

      const [row] = await db.select().from(users).where(eq(users.phone, '9199999090'));
      expect(row.lastLoginAt).not.toBeNull();
    });

    it('rejects an unauthenticated call', async () => {
      await request(app.getHttpServer()).post('/v1/member/me/touch-login').expect(401);
    });
  });
});
