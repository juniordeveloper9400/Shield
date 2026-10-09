process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('Agent-registration OTP (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let memberAccessToken: string;

  beforeAll(async () => {
    db = createTestDb();
    firebase = new FakeFirebaseVerifier();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(REDIS_CLIENT)
      .useValue(createTestRedis())
      .overrideProvider(FIREBASE_VERIFIER)
      .useValue(firebase)
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();

    await db.insert(users).values({
      phone: '9876500000',
      name: 'Recruiting Agent',
      firebaseUid: 'agent-otp-uid',
      registrationCompletedAt: new Date(),
    });
    firebase.register('token-agent-otp-uid', { uid: 'agent-otp-uid' });
    memberAccessToken = (
      await request(app.getHttpServer())
        .post('/v1/member/auth/session')
        .send({ idToken: 'token-agent-otp-uid' })
        .expect(200)
    ).body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects an unauthenticated send', async () => {
    await request(app.getHttpServer())
      .post('/v1/agent/otp/send-msg91')
      .send({ phone: '9876543210' })
      .expect(401);
  });

  it('rejects a malformed send body', async () => {
    await request(app.getHttpServer())
      .post('/v1/agent/otp/send-msg91')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ phone: '123' })
      .expect(400);
  });

  it('reports sending as unconfigured rather than crashing when the widget env is unset', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/agent/otp/send-msg91')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ phone: '9876543210' })
      .expect(200);
    expect(res.body).toEqual({ ok: false, reason: 'OTP sending is not configured on the server yet.' });
  });

  it('rejects an unauthenticated verify', async () => {
    await request(app.getHttpServer())
      .post('/v1/agent/otp/verify-msg91')
      .send({ phone: '9876543210', code: '123456' })
      .expect(401);
  });

  it('rejects a malformed verify body', async () => {
    await request(app.getHttpServer())
      .post('/v1/agent/otp/verify-msg91')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ phone: '9876543210', code: '' })
      .expect(400);
  });

  it('reports verification as unconfigured rather than crashing when the widget env is unset', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/agent/otp/verify-msg91')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ phone: '9876543210', code: '123456' })
      .expect(200);
    expect(res.body).toEqual({ ok: false, reason: 'OTP verification is not configured on the server yet.' });
  });
});
