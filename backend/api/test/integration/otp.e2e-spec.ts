process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { hash } from 'bcryptjs';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { adminUser } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('OTP (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let staffToken: string;

  beforeAll(async () => {
    db = createTestDb();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(REDIS_CLIENT)
      .useValue(createTestRedis())
      .overrideProvider(FIREBASE_VERIFIER)
      .useValue(new FakeFirebaseVerifier())
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();

    const passwordHash = await hash('correct-horse-battery-staple', 4);
    await db.insert(adminUser).values({ loginId: 'otp-staff@example.com', name: 'Staff', passwordHash, role: 'SUPERADMIN' });
    staffToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'otp-staff@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects an unauthenticated caller', async () => {
    await request(app.getHttpServer())
      .post('/v1/staff/otp/verify-msg91')
      .send({ accessToken: 'whatever', expectedPhone: '9876543210' })
      .expect(401);
  });

  it('rejects a malformed body', async () => {
    await request(app.getHttpServer())
      .post('/v1/staff/otp/verify-msg91')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({ accessToken: '' })
      .expect(400);
  });

  it('reports itself unconfigured rather than crashing when MSG91_AUTH_KEY is unset — the normal state in this test environment', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/staff/otp/verify-msg91')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({ accessToken: 'some-jwt', expectedPhone: '9876543210' })
      .expect(200);
    expect(res.body).toEqual({ ok: false, reason: 'OTP verification is not configured on the server yet.' });
  });
});
