process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { randomUUID } from 'node:crypto';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { authSession, users } from '../../src/db/schema';
import { TokenService } from '../../src/modules/auth/token.service';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';

describe('Agent-registration OTP (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let memberAccessToken: string;

  beforeAll(async () => {
    db = createTestDb();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(REDIS_CLIENT)
      .useValue(createTestRedis())
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();

    const [member] = await db
      .insert(users)
      .values({ phone: '9876500000', name: 'Recruiting Agent', registrationCompletedAt: new Date() })
      .returning();
    // Minted directly: this suite keeps the real OtpService (it tests the
    // unconfigured-MSG91 responses), so it cannot sign in through OTP.
    const [session] = await db
      .insert(authSession)
      .values({ id: randomUUID(), subjectType: 'MEMBER', subjectId: String(member.id), expiresAt: new Date(Date.now() + 60_000) })
      .returning();
    memberAccessToken = (
      await app.get(TokenService).issueAccessToken({ sessionId: session.id, subjectType: 'MEMBER', subjectId: String(member.id) })
    ).token;
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

  // The MSG91-Widget-access-token path — a client (a WebView on native)
  // that ran MSG91's own JS widget instead of asking this backend to send
  // the code. Uses MSG91_AUTH_KEY (unset in this test env, same as
  // otp.e2e-spec.ts), so this exercises the same unconfigured path.
  it('rejects an unauthenticated verify-widget', async () => {
    await request(app.getHttpServer())
      .post('/v1/agent/otp/verify-widget')
      .send({ accessToken: 'whatever', expectedPhone: '9876543210' })
      .expect(401);
  });

  it('rejects a malformed verify-widget body', async () => {
    await request(app.getHttpServer())
      .post('/v1/agent/otp/verify-widget')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ accessToken: '' })
      .expect(400);
  });

  it('reports verify-widget as unconfigured rather than crashing when MSG91_AUTH_KEY is unset', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/agent/otp/verify-widget')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ accessToken: 'some-jwt', expectedPhone: '9876543210' })
      .expect(200);
    expect(res.body).toEqual({ ok: false, reason: 'OTP verification is not configured on the server yet.' });
  });
});
