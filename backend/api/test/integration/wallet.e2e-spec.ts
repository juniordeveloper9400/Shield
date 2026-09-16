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
import { adminUser, agent, membershipTier, membershipTierLoad, referral, users } from '../../src/db/schema';
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
  let adminToken: string;
  let tierId: number;
  let memberId: number;
  let agentId: number;

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

    const [sellingAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-NAT-TEST1', name: 'Selling Agent', phone: '9000000099', level: 'NATIONAL' })
      .returning();
    agentId = sellingAgent.id;

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

    await db.insert(adminUser).values({
      loginId: 'admin@example.com',
      name: 'Plain Admin',
      passwordHash: testPasswordHash,
      role: 'ADMIN',
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
    adminToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'admin@example.com', password: 'correct-horse-battery-staple' })
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

  it("lists the caller's own submitted cards, oldest first", async () => {
    const cards = await request(app.getHttpServer())
      .get('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);

    expect(cards.body).toHaveLength(1);
    expect(cards.body[0].id).toBe(cardId);
    expect(cards.body[0].status).toBe('PENDING');
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

    // The member's own card list picks up the approval too — this is how a
    // client learns a pending submission was approved.
    const cards = await request(app.getHttpServer())
      .get('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(cards.body[0].status).toBe('APPROVED');
  });

  it('rejects approving the same card twice', async () => {
    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${cardId}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(403);
  });

  it("credits the agent whose code was given at checkout — 10% of the load as the commission pool, 60% of that pool as the agent's own direct-sale earnings — only once the card is actually approved, not at submission", async () => {
    // A separate member — approving into memberAccessToken's own wallet
    // here would shift the balance later tests assert an exact figure
    // against.
    await db.insert(users).values({ phone: '9000000004', name: 'Another Member', firebaseUid: 'member-wallet-2' });
    firebase.register('member-2-token', { uid: 'member-wallet-2' });
    const otherMemberToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-2-token' }).expect(200)
    ).body.accessToken;

    const submitted = await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${otherMemberToken}`)
      .send({ tierId, amount: 10000, agentCode: 'shd-nat-test1' }) // lowercase — resolution is case-insensitive
      .expect(201);

    const [beforeApproval] = await db.select().from(agent).where(eq(agent.id, agentId));
    expect(Number(beforeApproval.earned)).toBe(0);
    expect(Number(beforeApproval.personalSales)).toBe(0);

    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${submitted.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);

    const [afterApproval] = await db.select().from(agent).where(eq(agent.id, agentId));
    expect(Number(afterApproval.earned)).toBe(600); // 10000 * 10% pool * 60% direct share
    expect(Number(afterApproval.personalSales)).toBe(10000);
  });

  it('never blocks a submission over an agent code that matches no real agent', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ tierId, amount: 10000, agentCode: 'NOT-A-REAL-CODE' })
      .expect(201);
  });

  it('splits a non-national direct sale three ways: 60% to the seller, 10% up to the one national agent, 30% reserved', async () => {
    const [regionAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-REG-TEST1', name: 'Region Agent', phone: '9000000098', level: 'REGION' })
      .returning();

    await db.insert(users).values({ phone: '9000000005', name: 'Third Member', firebaseUid: 'member-wallet-3' });
    firebase.register('member-3-token', { uid: 'member-wallet-3' });
    const thirdMemberToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-3-token' }).expect(200)
    ).body.accessToken;

    // agentId (NATIONAL) already earned 600 from the earlier direct-sale
    // test in this file — read its current figure rather than assume 0, so
    // this test doesn't depend on running after (or instead of) that one.
    const [nationalBefore] = await db.select().from(agent).where(eq(agent.id, agentId));

    const submitted = await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${thirdMemberToken}`)
      .send({ tierId, amount: 10000, agentCode: 'SHD-REG-TEST1' })
      .expect(201);

    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${submitted.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);

    const [regionAfter] = await db.select().from(agent).where(eq(agent.id, regionAgent.id));
    expect(Number(regionAfter.earned)).toBe(600); // 10000 * 10% pool * 60% direct share
    expect(Number(regionAfter.personalSales)).toBe(10000);

    const [nationalAfter] = await db.select().from(agent).where(eq(agent.id, agentId));
    expect(Number(nationalAfter.earned) - Number(nationalBefore.earned)).toBe(100); // 10% pool override
    expect(Number(nationalAfter.personalSales)).toBe(Number(nationalBefore.personalSales)); // not their own sale

    const reserve = await request(app.getHttpServer())
      .get('/v1/staff/wallet-cards/reserve')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    const thisEntry = reserve.body.entries.find((e: { walletCardId: number }) => e.walletCardId === submitted.body.id);
    expect(Number(thisEntry.amount)).toBe(300); // 1000 pool - 600 direct - 100 override
  });

  it('rejects the commission reserve to ADMIN, even though that role can approve/reject wallet cards themselves', async () => {
    await request(app.getHttpServer())
      .get('/v1/staff/wallet-cards/reserve')
      .set('Authorization', `Bearer ${adminToken}`)
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

  it('gets or creates the caller\'s own referral code, stably across repeat calls', async () => {
    const first = await request(app.getHttpServer())
      .get('/v1/member/referrals/code')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(first.body.code).toMatch(/^SHIELD-\d{4}$/);

    const second = await request(app.getHttpServer())
      .get('/v1/member/referrals/code')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(second.body.code).toBe(first.body.code);
  });

  it("reports direct referrals and activated wallet cards for the caller's own progress", async () => {
    const [invitee] = await db
      .insert(users)
      .values({ phone: '9000000010', name: 'Referred Invitee', firebaseUid: 'member-referred-invitee' })
      .returning();
    await db.insert(referral).values({
      inviterMemberId: memberId,
      inviteeMemberId: invitee.id,
      inviteePhone: invitee.phone,
      status: 'TRANSACTED',
      registeredAt: new Date(),
      transactedAt: new Date(),
    });

    firebase.register('invitee-progress-token', { uid: 'member-referred-invitee' });
    const inviteeLogin = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'invitee-progress-token' })
      .expect(200);
    const inviteeToken = inviteeLogin.body.accessToken as string;

    const card = await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${inviteeToken}`)
      .send({ tierId, amount: 10000 })
      .expect(201);
    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${card.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);

    const progress = await request(app.getHttpServer())
      .get('/v1/member/referrals/progress')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(progress.body.directReferrals).toBe(1);
    expect(progress.body.activatedWalletCards).toHaveLength(1);
    expect(Number(progress.body.activatedWalletCards[0].amount)).toBe(10000);
  });
});
