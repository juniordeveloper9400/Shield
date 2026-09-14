process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { hash } from 'bcryptjs';
import { eq } from 'drizzle-orm';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { adminUser, users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

const STAFF_LOGIN_ID = 'pharmacist@example.com';
const STAFF_PASSWORD = 'correct-horse-battery-staple';

describe('Auth flow (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;

  beforeAll(async () => {
    db = createTestDb();
    firebase = new FakeFirebaseVerifier();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(FIREBASE_VERIFIER)
      .useValue(firebase)
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();

    await db.insert(users).values({ phone: '9999999999', name: 'Test Member', firebaseUid: 'member-uid-1' });
    await db.insert(adminUser).values({
      loginId: STAFF_LOGIN_ID,
      name: 'Test Pharmacist',
      passwordHash: await hash(STAFF_PASSWORD, 4), // low cost factor — this is a test, not production
      role: 'PHARMACY',
    });

    firebase.register('valid-member-token', { uid: 'member-uid-1' });
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects protected routes with no token', async () => {
    await request(app.getHttpServer()).get('/v1/member/me').expect(401);
  });

  it('logs a member in via a verified Firebase token and reads their own profile', async () => {
    const login = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'valid-member-token' })
      .expect(200);

    expect(login.body.accessToken).toBeDefined();
    expect(login.body.refreshToken).toBeDefined();

    const me = await request(app.getHttpServer())
      .get('/v1/member/me')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(200);

    expect(me.body.phone).toBe('9999999999');
  });

  it('does not silently create a member for an unrecognized Firebase identity', async () => {
    firebase.register('stranger-token', { uid: 'no-such-user' });
    await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'stranger-token' })
      .expect(404);
  });

  it('logs a staff user in with login id + password and exposes their role for server-side RBAC', async () => {
    const login = await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ loginId: STAFF_LOGIN_ID, password: STAFF_PASSWORD })
      .expect(200);

    const me = await request(app.getHttpServer())
      .get('/v1/staff/me')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(200);

    expect(me.body.role).toBe('PHARMACY');
  });

  it('rejects a wrong password with the same generic error as an unknown login id — no user enumeration', async () => {
    const wrongPassword = await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ loginId: STAFF_LOGIN_ID, password: 'not-the-right-password' })
      .expect(401);
    const unknownLoginId = await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ loginId: 'nobody@example.com', password: STAFF_PASSWORD })
      .expect(401);

    expect(wrongPassword.body.error.message).toBe(unknownLoginId.body.error.message);
  });

  it('rejects a member session on a staff-only route', async () => {
    const login = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'valid-member-token' })
      .expect(200);

    await request(app.getHttpServer())
      .get('/v1/staff/me')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(403); // RequireStaff() rejects it before the handler ever runs — see RolesGuard
  });

  it('rejects a staff session on a member-only route — the symmetric case', async () => {
    const login = await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ loginId: STAFF_LOGIN_ID, password: STAFF_PASSWORD })
      .expect(200);

    await request(app.getHttpServer())
      .get('/v1/member/me')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(403);
  });

  it('revokes a session immediately on logout — not just when the access token would naturally expire', async () => {
    const login = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'valid-member-token' })
      .expect(200);

    await request(app.getHttpServer())
      .delete('/v1/member/auth/session')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(204);

    await request(app.getHttpServer())
      .get('/v1/member/me')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(401);
  });

  it('rotates refresh tokens and rejects reuse of an already-used one', async () => {
    const login = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'valid-member-token' })
      .expect(200);

    const refreshed = await request(app.getHttpServer())
      .post('/v1/member/auth/refresh')
      .send({ refreshToken: login.body.refreshToken })
      .expect(200);

    expect(refreshed.body.accessToken).not.toBe(login.body.accessToken);

    await request(app.getHttpServer())
      .post('/v1/member/auth/refresh')
      .send({ refreshToken: login.body.refreshToken })
      .expect(401);
  });

  it('rejects a request body that fails validation instead of reaching the database', async () => {
    await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'x' }).expect(400);
  });

  it('registers a brand-new member from a verified Firebase identity with no app.users row yet', async () => {
    firebase.register('new-member-token', { uid: 'brand-new-uid', phoneNumber: '+919812345678' });

    const register = await request(app.getHttpServer())
      .post('/v1/member/auth/register')
      .send({ idToken: 'new-member-token', name: 'Brand New Member' })
      .expect(200);

    expect(register.body.accessToken).toBeDefined();

    const me = await request(app.getHttpServer())
      .get('/v1/member/me')
      .set('Authorization', `Bearer ${register.body.accessToken}`)
      .expect(200);

    expect(me.body.phone).toBe('9812345678');
    expect(me.body.name).toBe('Brand New Member');
  });

  it('backfills firebase_uid onto an existing phone-only row instead of creating a duplicate account', async () => {
    await db.insert(users).values({ phone: '9700000001', name: 'Legacy Phone Member' });
    firebase.register('legacy-member-token', { uid: 'legacy-uid-1', phoneNumber: '+919700000001' });

    await request(app.getHttpServer())
      .post('/v1/member/auth/register')
      .send({ idToken: 'legacy-member-token', name: 'Legacy Phone Member' })
      .expect(200);

    const rows = await db.select().from(users).where(eq(users.phone, '9700000001'));
    expect(rows).toHaveLength(1);
    expect(rows[0].firebaseUid).toBe('legacy-uid-1');

    // A second sign-in for the same identity is now a plain session exchange, not a re-registration.
    const session = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'legacy-member-token' })
      .expect(200);
    expect(session.body.accessToken).toBeDefined();
  });
});
