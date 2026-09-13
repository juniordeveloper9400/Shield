process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { adminUser, users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

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
      email: 'pharmacist@example.com',
      name: 'Test Pharmacist',
      firebaseUid: 'staff-uid-1',
      role: 'PHARMACY',
    });

    firebase.register('valid-member-token', { uid: 'member-uid-1' });
    firebase.register('valid-staff-token', { uid: 'staff-uid-1', email: 'pharmacist@example.com' });
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

  it('logs a staff user in and exposes their role for server-side RBAC', async () => {
    const login = await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ idToken: 'valid-staff-token' })
      .expect(200);

    const me = await request(app.getHttpServer())
      .get('/v1/staff/me')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(200);

    expect(me.body.role).toBe('PHARMACY');
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
      .send({ idToken: 'valid-staff-token' })
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
});
