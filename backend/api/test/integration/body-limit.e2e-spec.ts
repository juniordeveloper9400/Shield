process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import request from 'supertest';
import { eq } from 'drizzle-orm';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { patient, prescriptionImage, users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

/**
 * A synthetic ~190KB base64 payload with a real `data:image/jpeg;base64,`
 * prefix — comfortably over Express's own default 100kb JSON body limit
 * (well past what any real compressed prescription photo needs, but this
 * test is about the request being accepted at all, not the image content —
 * `submitOrderReceiptSchema`/the prescription DTO's own regex only checks
 * the prefix, never decodes the base64 that follows).
 */
const LARGE_DATA_URI = `data:image/jpeg;base64,${'A'.repeat(190_000)}`;

/**
 * Regression coverage for main.ts / api/index.js's `bodyParser: false` +
 * `useBodyParser('json', { limit: '15mb' })` bootstrap change — see that
 * file's own doc comment. Every image this API accepts (a prescription
 * scan, a wallet-card/order receipt, a bill photo) travels as a base64
 * data: URI inside a plain JSON body, and Nest's own default (Express's
 * body-parser, 100kb) silently 413s any of them before a controller or
 * even the Zod validation pipe ever sees the request — this app's own e2e
 * suites never caught it because every OTHER test's fixture image is a
 * tiny 1x1 PNG (`PNG_DATA_URI`, ~90 bytes), nowhere near that ceiling.
 *
 * This suite builds its own app instance with the exact same override
 * main.ts applies, so it proves the fix itself works — not just that it
 * typechecks — since the shared jest test harness (`createNestApplication()`
 * with no options, used by every other *.e2e-spec.ts file here) never
 * exercises main.ts/api/index.js at all.
 */
describe('Request body size limit (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let memberAccessToken: string;
  let patientId: number;

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

    app = moduleRef.createNestApplication<NestExpressApplication>({ bodyParser: false });
    (app as NestExpressApplication).useBodyParser('json', { limit: '15mb' });
    (app as NestExpressApplication).useBodyParser('urlencoded', { extended: true, limit: '15mb' });
    await app.init();

    const [member] = await db
      .insert(users)
      .values({ phone: '9000000030', name: 'Body Limit Member', firebaseUid: 'member-body-limit-1' })
      .returning();
    firebase.register('member-token', { uid: 'member-body-limit-1' });

    const [seededPatient] = await db
      .insert(patient)
      .values({ memberId: member.id, name: 'Self', dob: '1990-01-01', relation: 'SELF' })
      .returning();
    patientId = seededPatient.id;

    memberAccessToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-token' }).expect(200)
    ).body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('accepts a prescription upload whose JSON body is well over the 100kb Express default, and actually stores the image', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/member/prescriptions')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ patientId, images: [LARGE_DATA_URI] })
      .expect(201);

    const rows = await db.select().from(prescriptionImage).where(eq(prescriptionImage.prescriptionId, created.body.id));
    expect(rows).toHaveLength(1);
    expect(rows[0].image).toBe(LARGE_DATA_URI);
  });
});
