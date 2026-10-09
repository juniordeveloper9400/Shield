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
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { OtpService } from '../../src/modules/otp/otp.service';
import { users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

/** Stands in for the real MSG91 call so the sign-in/registration *logic*
 *  (not MSG91 itself) can be exercised deterministically: [acceptedCode] is
 *  the one code `verifyMsg91Otp` treats as correct, for whichever phone
 *  [sendMsg91Otp] was last asked to text. */
class FakeOtpService {
  acceptedCode = '123456';
  private sentTo: string | null = null;

  async sendMsg91Otp(phone: string) {
    this.sentTo = phone;
    return { ok: true };
  }

  async verifyMsg91Otp(phone: string, code: string) {
    if (this.sentTo !== phone) {
      return { ok: false, reason: 'No code was sent to that number.' };
    }
    return code === this.acceptedCode
      ? { ok: true }
      : { ok: false, reason: 'That code is not right or has expired.' };
  }
}

describe('Member login via MSG91 OTP (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;

  beforeAll(async () => {
    db = createTestDb();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(FIREBASE_VERIFIER)
      .useValue(new FakeFirebaseVerifier())
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();

    await db.insert(users).values({ phone: '9876500001', name: 'Existing Member' });
  });

  afterAll(async () => {
    await app.close();
  });

  // MSG91_WIDGET_ID/MSG91_WIDGET_TOKEN_AUTH are unset in this test env — see
  // backend/api/.env.example — so every call below exercises the
  // "reports itself unconfigured" path rather than a real MSG91 round trip,
  // the same way otp.e2e-spec.ts and agent-otp.e2e-spec.ts do.

  it('reports OTP sending as unconfigured rather than crashing', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/auth/otp/send')
      .send({ phone: '9876500001' })
      .expect(200);
    expect(res.body).toEqual({ ok: false, reason: 'OTP sending is not configured on the server yet.' });
  });

  it('rejects a malformed phone on send', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/auth/otp/send')
      .send({ phone: '12345' })
      .expect(400);
  });

  it('refuses sign-in with a 401 while MSG91 is unconfigured, for an existing member', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/auth/otp/verify')
      .send({ phone: '9876500001', code: '123456' })
      .expect(401);
  });

  it('rejects a malformed verify body', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/auth/otp/verify')
      .send({ phone: '9876500001', code: '' })
      .expect(400);
  });

  it('refuses registration with a 401 while MSG91 is unconfigured, even for a brand-new phone', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/auth/otp/register')
      .send({ phone: '9876500099', code: '123456', name: 'Brand New Member' })
      .expect(401);
  });

  it('rejects a malformed register body', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/auth/otp/register')
      .send({ phone: '9876500099', code: '123456', name: '' })
      .expect(400);
  });
});

describe('Member login via MSG91 OTP — with MSG91 faked (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let otp: FakeOtpService;

  beforeAll(async () => {
    db = createTestDb();
    otp = new FakeOtpService();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(FIREBASE_VERIFIER)
      .useValue(new FakeFirebaseVerifier())
      .overrideProvider(OtpService)
      .useValue(otp)
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();

    await db.insert(users).values({ phone: '9876500001', name: 'Existing Member' });
    await db.insert(users).values({ phone: '9876500002', name: 'Deleted Member', deletedAt: new Date() });
  });

  afterAll(async () => {
    await app.close();
  });

  it('signs an existing member in once the right code is entered', async () => {
    await request(app.getHttpServer()).post('/v1/member/auth/otp/send').send({ phone: '9876500001' }).expect(200);

    const res = await request(app.getHttpServer())
      .post('/v1/member/auth/otp/verify')
      .send({ phone: '9876500001', code: '123456' })
      .expect(200);
    expect(res.body.accessToken).toBeTruthy();
    expect(res.body.refreshToken).toBeTruthy();
  });

  it('rejects sign-in with the wrong code', async () => {
    await request(app.getHttpServer()).post('/v1/member/auth/otp/send').send({ phone: '9876500001' }).expect(200);
    await request(app.getHttpServer())
      .post('/v1/member/auth/otp/verify')
      .send({ phone: '9876500001', code: '000000' })
      .expect(401);
  });

  it('refuses sign-in for a phone with no app.users row, even with the right code', async () => {
    await request(app.getHttpServer()).post('/v1/member/auth/otp/send').send({ phone: '9876500098' }).expect(200);
    await request(app.getHttpServer())
      .post('/v1/member/auth/otp/verify')
      .send({ phone: '9876500098', code: '123456' })
      .expect(404);
  });

  it('refuses sign-in for a soft-deleted member', async () => {
    await request(app.getHttpServer()).post('/v1/member/auth/otp/send').send({ phone: '9876500002' }).expect(200);
    await request(app.getHttpServer())
      .post('/v1/member/auth/otp/verify')
      .send({ phone: '9876500002', code: '123456' })
      .expect(404);
  });

  it('registers a brand-new phone and signs it straight in', async () => {
    await request(app.getHttpServer()).post('/v1/member/auth/otp/send').send({ phone: '9876500003' }).expect(200);
    const res = await request(app.getHttpServer())
      .post('/v1/member/auth/otp/register')
      .send({ phone: '9876500003', code: '123456', name: 'Brand New Member' })
      .expect(200);
    expect(res.body.accessToken).toBeTruthy();

    const [row] = await db.select().from(users).where(eq(users.phone, '9876500003'));
    expect(row?.name).toBe('Brand New Member');
    expect(row?.deletedAt).toBeNull();
  });

  it('reactivates a soft-deleted member on register, taking the freshly typed-in name', async () => {
    // A reactivated account takes the incoming name rather than whatever the
    // deleted row carried — see registerMemberByPhone's own doc (same rule
    // registerMember applies for the Firebase path).
    await request(app.getHttpServer()).post('/v1/member/auth/otp/send').send({ phone: '9876500002' }).expect(200);
    const res = await request(app.getHttpServer())
      .post('/v1/member/auth/otp/register')
      .send({ phone: '9876500002', code: '123456', name: 'Some Other Name Typed In' })
      .expect(200);
    expect(res.body.accessToken).toBeTruthy();

    const [row] = await db.select().from(users).where(eq(users.phone, '9876500002'));
    expect(row?.name).toBe('Some Other Name Typed In');
    expect(row?.deletedAt).toBeNull();
  });

  it('rejects registration with the wrong code', async () => {
    await request(app.getHttpServer()).post('/v1/member/auth/otp/send').send({ phone: '9876500004' }).expect(200);
    await request(app.getHttpServer())
      .post('/v1/member/auth/otp/register')
      .send({ phone: '9876500004', code: '000000', name: 'Nope' })
      .expect(401);
  });
});
