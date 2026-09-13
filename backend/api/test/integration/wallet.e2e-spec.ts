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
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { adminUser, membershipTier, membershipTierLoad, users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('Wallet & Rewards (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let memberAccessToken: string;
  let pharmacyStaffToken: string;
  let superAdminToken: string;
  let tierId: number;
  let memberId: number;

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

    const [tier] = await db
      .insert(membershipTier)
      .values({ kind: 'SILVER', name: 'Silver Shield', bin: '1234', bonusRate: '0.100', validityMonths: 12 })
      .returning();
    tierId = tier.id;
    await db.insert(membershipTierLoad).values({ tierId, amount: '10000.00' });

    const [member] = await db
      .insert(users)
      .values({ phone: '9000000003', name: 'Wallet Member', firebaseUid: 'member-wallet-1' })
      .returning();
    memberId = member.id;
    firebase.register('member-token', { uid: 'member-wallet-1' });

    const testPasswordHash = await hash('correct-horse-battery-staple', 4); // low cost factor — this is a test, not production

    await db.insert(adminUser).values({
      loginId: 'pharmacy@example.com',
      name: 'Pharmacy Staff',
      passwordHash: testPasswordHash,
      role: 'PHARMACY',
    });

    await db.insert(adminUser).values({
      loginId: 'superadmin@example.com',
      name: 'Super Admin',
      passwordHash: testPasswordHash,
      role: 'SUPERADMIN',
    });

    memberAccessToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-token' }).expect(200)
    ).body.accessToken;
    pharmacyStaffToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'pharmacy@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;
    superAdminToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'superadmin@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it("rejects a wallet card amount that isn't one of the tier's fixed loadable amounts", async () => {
    await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ tierId, amount: 9999 })
      .expect(403);
  });

  let cardId: number;

  it('submits a wallet card as PENDING, crediting nothing yet', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ tierId, amount: 10000 })
      .expect(201);

    cardId = res.body.id;
    expect(res.body.status).toBe('PENDING');
    expect(Number(res.body.bonus)).toBe(1000); // 10% of 10000

    const wallet = await request(app.getHttpServer())
      .get('/v1/member/wallet')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(Number(wallet.body.balance)).toBe(0);
  });

  it('rejects redeeming points before the wallet has ever been opened', async () => {
    await db.update(users).set({ rewardPoints: 500 }).where(eq(users.id, memberId));

    await request(app.getHttpServer())
      .post('/v1/member/rewards/redeem')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .set('Idempotency-Key', 'redeem-key-early')
      .send({ points: 100 })
      .expect(403);
  });

  it('rejects a non-SUPERADMIN staff role from approving a wallet card', async () => {
    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${cardId}/approve`)
      .set('Authorization', `Bearer ${pharmacyStaffToken}`)
      .expect(403);
  });

  it('lets SUPERADMIN approve the card, crediting the ledger and opening the wallet', async () => {
    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${cardId}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);

    const wallet = await request(app.getHttpServer())
      .get('/v1/member/wallet')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(Number(wallet.body.balance)).toBe(11000); // 10000 + 1000 bonus
    expect(wallet.body.openedAt).not.toBeNull();

    const entries = await request(app.getHttpServer())
      .get('/v1/member/wallet/entries')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(entries.body).toHaveLength(2); // TOPUP + BONUS
  });

  it('rejects approving the same card twice', async () => {
    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${cardId}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(403);
  });

  it('rejects redemption below the minimum or not a multiple of 10', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/rewards/redeem')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .set('Idempotency-Key', 'redeem-key-toolow')
      .send({ points: 50 })
      .expect(403);

    await request(app.getHttpServer())
      .post('/v1/member/rewards/redeem')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .set('Idempotency-Key', 'redeem-key-notmultiple')
      .send({ points: 105 })
      .expect(403);
  });

  it('redeems points into the wallet, ledger and denormalized fields agreeing exactly', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/rewards/redeem')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .set('Idempotency-Key', 'redeem-key-1')
      .send({ points: 100 })
      .expect(201);

    expect(res.body.pointsRedeemed).toBe(100);
    expect(res.body.rupeesCredited).toBe(10);
    expect(Number(res.body.wallet.balance)).toBe(11010);
    expect(res.body.wallet.rewardPoints).toBe(-100); // wallet.reward_points started at 0, never credited by the card path

    const member = await request(app.getHttpServer())
      .get('/v1/member/me')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(member.body.rewardPoints).toBe(400); // 500 - 100
  });

  it('is idempotent: retrying the same redeem key does not double-debit', async () => {
    const retry = await request(app.getHttpServer())
      .post('/v1/member/rewards/redeem')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .set('Idempotency-Key', 'redeem-key-1')
      .send({ points: 100 })
      .expect(201);
    expect(retry.body.pointsRedeemed).toBe(100);

    const member = await request(app.getHttpServer())
      .get('/v1/member/me')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(member.body.rewardPoints).toBe(400); // unchanged by the retry
  });

  it('rejects redeeming more points than the member has', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/rewards/redeem')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .set('Idempotency-Key', 'redeem-key-toomuch')
      .send({ points: 100000 })
      .expect(403);
  });

  it('creates and lists a referral', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/referrals')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ inviteePhone: '9123456789' })
      .expect(201);

    const list = await request(app.getHttpServer())
      .get('/v1/member/referrals')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(list.body).toEqual(expect.arrayContaining([expect.objectContaining({ inviteePhone: '9123456789', status: 'SHARED' })]));
  });
});
