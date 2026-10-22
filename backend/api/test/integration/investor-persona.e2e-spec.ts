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
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { investor, shieldStore, users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { OtpService } from '../../src/modules/otp/otp.service';
import { FakeOtpService, memberLogin } from './fake-otp';

/**
 * GET /v1/investor/me — the "is this signed-in member also an investor"
 * check a client used to run directly against app.investor with the
 * compiled-in Neon credential (lib/data/neon/persona_repository.dart, now
 * gone). First real test coverage for InvestorService.
 */
describe('Investor self-profile (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;

  beforeAll(async () => {
    db = createTestDb();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(REDIS_CLIENT)
      .useValue(createTestRedis())
      .overrideProvider(OtpService)
      .useValue(new FakeOtpService())
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  async function tokenFor(phone: string, firebaseUid: string) {
    await db.insert(users).values({ phone, name: 'Persona Member', firebaseUid, registrationCompletedAt: new Date() });
    const res = await memberLogin(app, phone).expect(200);
    return { accessToken: res.body.accessToken as string, phone };
  }

  it("returns the investor row, with the invested branch's code, for a member who is one", async () => {
    const { accessToken, phone } = await tokenFor('9199999301', 'persona-investor-uid');
    const [member] = await db.select().from(users).where(eq(users.phone, phone)).limit(1);
    const [store] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-INV', name: 'Store Inv', area: 'A', city: 'A', state: 'A', pincode: '111111' })
      .returning();
    await db.insert(investor).values({
      memberId: member.id,
      code: 'INV-SELF-1',
      name: 'Persona Member',
      phone,
      investedStoreId: store.id,
      totalUnits: 2,
      investedSince: '2026-01-01',
      roiPercent: '12.50',
      planType: 'YEARLY',
    });

    const res = await request(app.getHttpServer())
      .get('/v1/investor/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    expect(res.body.code).toBe('INV-SELF-1');
    expect(res.body.totalUnits).toBe(2);
    expect(res.body.storeCode).toBe('SHD-INV');
  });

  it('is refused for a member who is not an investor', async () => {
    const { accessToken } = await tokenFor('9199999302', 'persona-noninvestor-uid');
    await request(app.getHttpServer())
      .get('/v1/investor/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(403);
  });

  it('rejects an unauthenticated call', async () => {
    await request(app.getHttpServer()).get('/v1/investor/me').expect(401);
  });
});
