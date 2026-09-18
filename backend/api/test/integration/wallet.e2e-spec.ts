process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { hash } from 'bcryptjs';
import { randomUUID } from 'node:crypto';
import { and, eq } from 'drizzle-orm';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { adminUser, agent, authSession, membershipTier, membershipTierLoad, referral, users, wallet } from '../../src/db/schema';
import { TokenService } from '../../src/modules/auth/token.service';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('Wallet & Rewards (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let tokens: TokenService;
  let memberAccessToken: string;
  let pharmacyStaffToken: string;
  let superAdminToken: string;
  let adminToken: string;
  let tierId: number;
  let memberId: number;
  let agentId: number;

  /**
   * A real, valid member access token minted directly rather than through a
   * real Firebase sign-in over POST /v1/member/auth/session — this file
   * already runs exactly 10 genuine sign-ins (one per member/staff needing
   * a fresh session), which is AuthThrottle's own 10/60s ceiling on that
   * route; one more real sign-in tips a later test into a 429. See
   * agent.e2e-spec.ts's own copy of this helper for the same reasoning.
   */
  async function directMemberToken(userId: number): Promise<string> {
    const [session] = await db
      .insert(authSession)
      // Explicit id: pg-mem's gen_random_uuid() default has produced the
      // same value across back-to-back inserts in this file's own test
      // (three calls in quick succession, the second colliding with the
      // first) — sidestep it with a real, guaranteed-unique client id.
      .values({
        id: randomUUID(),
        subjectType: 'MEMBER',
        subjectId: String(userId),
        expiresAt: new Date(Date.now() + 60_000),
      })
      .returning();
    const { token } = await tokens.issueAccessToken({
      sessionId: session.id,
      subjectType: 'MEMBER',
      subjectId: String(userId),
    });
    return token;
  }

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
    tokens = moduleRef.get(TokenService);

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
    // parentId: agentId — a REGION agent's real immediate parent IS the
    // national agent in this tree (confirmed against live data), so the
    // 10% "immediate parent" override and the "national" override are the
    // same payment here, not two separate ones.
    const [regionAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-REG-TEST1', name: 'Region Agent', phone: '9000000098', level: 'REGION', parentId: agentId })
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

  it('splits a state-level direct sale four ways: 60% seller, 10% real region parent, 6% national, 24% reserved', async () => {
    // A real reporting line two levels below national: state's parent is
    // this specific region agent, whose own parent is the national agent —
    // not just "whoever happens to be at the REGION level".
    const [regionAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-REG-TEST2', name: 'Region Agent 2', phone: '9000000097', level: 'REGION', parentId: agentId })
      .returning();
    const [stateAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-STA-TEST1', name: 'State Agent', phone: '9000000096', level: 'STATE', parentId: regionAgent.id })
      .returning();

    await db.insert(users).values({ phone: '9000000006', name: 'Fourth Member', firebaseUid: 'member-wallet-4' });
    firebase.register('member-4-token', { uid: 'member-wallet-4' });
    const fourthMemberToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-4-token' }).expect(200)
    ).body.accessToken;

    // agentId (NATIONAL) has already earned from earlier tests in this file
    // — read its current figure rather than assume a fixed value.
    const [nationalBefore] = await db.select().from(agent).where(eq(agent.id, agentId));

    const submitted = await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${fourthMemberToken}`)
      .send({ tierId, amount: 10000, agentCode: 'SHD-STA-TEST1' })
      .expect(201);

    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${submitted.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);

    const [stateAfter] = await db.select().from(agent).where(eq(agent.id, stateAgent.id));
    expect(Number(stateAfter.earned)).toBe(600); // 10000 * 10% pool * 60% direct share
    expect(Number(stateAfter.personalSales)).toBe(10000);

    const [regionAfter] = await db.select().from(agent).where(eq(agent.id, regionAgent.id));
    expect(Number(regionAfter.earned)).toBe(100); // 10% pool to the real immediate parent
    expect(Number(regionAfter.personalSales)).toBe(0); // not their own sale

    const [nationalAfter] = await db.select().from(agent).where(eq(agent.id, agentId));
    expect(Number(nationalAfter.earned) - Number(nationalBefore.earned)).toBe(60); // 6% pool, national ≠ immediate parent here

    const reserve = await request(app.getHttpServer())
      .get('/v1/staff/wallet-cards/reserve')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    const thisEntry = reserve.body.entries.find((e: { walletCardId: number }) => e.walletCardId === submitted.body.id);
    expect(Number(thisEntry.amount)).toBe(240); // 1000 pool - 600 direct - 100 parent - 60 national
  });

  it('splits a district-level direct sale five ways: 60% seller, 10% state, 6% region, 5% national, 19% reserved', async () => {
    // A real four-deep reporting line: district -> state -> region -> national.
    const [regionAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-REG-TEST3', name: 'Region Agent 3', phone: '9000000095', level: 'REGION', parentId: agentId })
      .returning();
    const [stateAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-STA-TEST2', name: 'State Agent 2', phone: '9000000094', level: 'STATE', parentId: regionAgent.id })
      .returning();
    const [districtAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-DIS-TEST1', name: 'District Agent', phone: '9000000093', level: 'DISTRICT', parentId: stateAgent.id })
      .returning();

    await db.insert(users).values({ phone: '9000000007', name: 'Fifth Member', firebaseUid: 'member-wallet-5' });
    firebase.register('member-5-token', { uid: 'member-wallet-5' });
    const fifthMemberToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-5-token' }).expect(200)
    ).body.accessToken;

    // agentId (NATIONAL) has already earned from earlier tests in this file
    // — read its current figure rather than assume a fixed value.
    const [nationalBefore] = await db.select().from(agent).where(eq(agent.id, agentId));

    const submitted = await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${fifthMemberToken}`)
      .send({ tierId, amount: 10000, agentCode: 'SHD-DIS-TEST1' })
      .expect(201);

    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${submitted.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);

    const [districtAfter] = await db.select().from(agent).where(eq(agent.id, districtAgent.id));
    expect(Number(districtAfter.earned)).toBe(600); // 10000 * 10% pool * 60% direct share
    expect(Number(districtAfter.personalSales)).toBe(10000);

    const [stateAfter] = await db.select().from(agent).where(eq(agent.id, stateAgent.id));
    expect(Number(stateAfter.earned)).toBe(100); // hop 1: 10% pool

    const [regionAfter] = await db.select().from(agent).where(eq(agent.id, regionAgent.id));
    expect(Number(regionAfter.earned)).toBe(60); // hop 2: 6% pool

    const [nationalAfter] = await db.select().from(agent).where(eq(agent.id, agentId));
    expect(Number(nationalAfter.earned) - Number(nationalBefore.earned)).toBe(50); // hop 3: 5% pool

    const reserve = await request(app.getHttpServer())
      .get('/v1/staff/wallet-cards/reserve')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    const thisEntry = reserve.body.entries.find((e: { walletCardId: number }) => e.walletCardId === submitted.body.id);
    expect(Number(thisEntry.amount)).toBe(190); // 1000 pool - 600 direct - 100 - 60 - 50
  });

  it('splits an assembly-level direct sale six ways: 60% seller, 10% district, 6% state, 5% region, 4% national, 15% reserved', async () => {
    // A real five-deep reporting line: assembly -> district -> state -> region -> national.
    const [regionAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-REG-TEST4', name: 'Region Agent 4', phone: '9000000092', level: 'REGION', parentId: agentId })
      .returning();
    const [stateAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-STA-TEST3', name: 'State Agent 3', phone: '9000000091', level: 'STATE', parentId: regionAgent.id })
      .returning();
    const [districtAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-DIS-TEST2', name: 'District Agent 2', phone: '9000000090', level: 'DISTRICT', parentId: stateAgent.id })
      .returning();
    const [assemblyAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-ASM-TEST1', name: 'Assembly Agent', phone: '9000000089', level: 'ASSEMBLY', parentId: districtAgent.id })
      .returning();

    await db.insert(users).values({ phone: '9000000008', name: 'Sixth Member', firebaseUid: 'member-wallet-6' });
    firebase.register('member-6-token', { uid: 'member-wallet-6' });
    const sixthMemberToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-6-token' }).expect(200)
    ).body.accessToken;

    // agentId (NATIONAL) has already earned from earlier tests in this file
    // — read its current figure rather than assume a fixed value.
    const [nationalBefore] = await db.select().from(agent).where(eq(agent.id, agentId));

    const submitted = await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${sixthMemberToken}`)
      .send({ tierId, amount: 10000, agentCode: 'SHD-ASM-TEST1' })
      .expect(201);

    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${submitted.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);

    const [assemblyAfter] = await db.select().from(agent).where(eq(agent.id, assemblyAgent.id));
    expect(Number(assemblyAfter.earned)).toBe(600); // 10000 * 10% pool * 60% direct share
    expect(Number(assemblyAfter.personalSales)).toBe(10000);

    const [districtAfter] = await db.select().from(agent).where(eq(agent.id, districtAgent.id));
    expect(Number(districtAfter.earned)).toBe(100); // hop 1: 10% pool

    const [stateAfter] = await db.select().from(agent).where(eq(agent.id, stateAgent.id));
    expect(Number(stateAfter.earned)).toBe(60); // hop 2: 6% pool

    const [regionAfter] = await db.select().from(agent).where(eq(agent.id, regionAgent.id));
    expect(Number(regionAfter.earned)).toBe(50); // hop 3: 5% pool

    const [nationalAfter] = await db.select().from(agent).where(eq(agent.id, agentId));
    expect(Number(nationalAfter.earned) - Number(nationalBefore.earned)).toBe(40); // hop 4: 4% pool

    const reserve = await request(app.getHttpServer())
      .get('/v1/staff/wallet-cards/reserve')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    const thisEntry = reserve.body.entries.find((e: { walletCardId: number }) => e.walletCardId === submitted.body.id);
    expect(Number(thisEntry.amount)).toBe(150); // 1000 pool - 600 direct - 100 - 60 - 50 - 40
  });

  it('splits an lsgd-level direct sale seven ways: 60% seller, 10% assembly, 6% district, 5% state, 4% region, 3% national, 12% reserved', async () => {
    // A real six-deep reporting line: lsgd -> assembly -> district -> state -> region -> national.
    const [regionAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-REG-TEST5', name: 'Region Agent 5', phone: '9000000088', level: 'REGION', parentId: agentId })
      .returning();
    const [stateAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-STA-TEST4', name: 'State Agent 4', phone: '9000000087', level: 'STATE', parentId: regionAgent.id })
      .returning();
    const [districtAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-DIS-TEST3', name: 'District Agent 3', phone: '9000000086', level: 'DISTRICT', parentId: stateAgent.id })
      .returning();
    const [assemblyAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-ASM-TEST2', name: 'Assembly Agent 2', phone: '9000000085', level: 'ASSEMBLY', parentId: districtAgent.id })
      .returning();
    const [lsgdAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-LSG-TEST1', name: 'Lsgd Agent', phone: '9000000084', level: 'LSGD', parentId: assemblyAgent.id })
      .returning();

    await db.insert(users).values({ phone: '9000000009', name: 'Seventh Member', firebaseUid: 'member-wallet-7' });
    firebase.register('member-7-token', { uid: 'member-wallet-7' });
    const seventhMemberToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-7-token' }).expect(200)
    ).body.accessToken;

    // agentId (NATIONAL) has already earned from earlier tests in this file
    // — read its current figure rather than assume a fixed value.
    const [nationalBefore] = await db.select().from(agent).where(eq(agent.id, agentId));

    const submitted = await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${seventhMemberToken}`)
      .send({ tierId, amount: 10000, agentCode: 'SHD-LSG-TEST1' })
      .expect(201);

    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${submitted.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);

    const [lsgdAfter] = await db.select().from(agent).where(eq(agent.id, lsgdAgent.id));
    expect(Number(lsgdAfter.earned)).toBe(600); // 10000 * 10% pool * 60% direct share
    expect(Number(lsgdAfter.personalSales)).toBe(10000);

    const [assemblyAfter] = await db.select().from(agent).where(eq(agent.id, assemblyAgent.id));
    expect(Number(assemblyAfter.earned)).toBe(100); // hop 1: 10% pool

    const [districtAfter] = await db.select().from(agent).where(eq(agent.id, districtAgent.id));
    expect(Number(districtAfter.earned)).toBe(60); // hop 2: 6% pool

    const [stateAfter] = await db.select().from(agent).where(eq(agent.id, stateAgent.id));
    expect(Number(stateAfter.earned)).toBe(50); // hop 3: 5% pool

    const [regionAfter] = await db.select().from(agent).where(eq(agent.id, regionAgent.id));
    expect(Number(regionAfter.earned)).toBe(40); // hop 4: 4% pool

    const [nationalAfter] = await db.select().from(agent).where(eq(agent.id, agentId));
    expect(Number(nationalAfter.earned) - Number(nationalBefore.earned)).toBe(30); // hop 5: 3% pool

    const reserve = await request(app.getHttpServer())
      .get('/v1/staff/wallet-cards/reserve')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    const thisEntry = reserve.body.entries.find((e: { walletCardId: number }) => e.walletCardId === submitted.body.id);
    expect(Number(thisEntry.amount)).toBe(120); // 1000 pool - 600 direct - 100 - 60 - 50 - 40 - 30
  });

  it('splits a ward-level direct sale eight ways: 60% seller, 10% lsgd, 6% assembly, 5% district, 4% state, 3% region, 2% national, 10% reserved', async () => {
    // A real seven-deep reporting line: ward -> lsgd -> assembly -> district -> state -> region -> national.
    const [regionAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-REG-TEST6', name: 'Region Agent 6', phone: '9000000083', level: 'REGION', parentId: agentId })
      .returning();
    const [stateAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-STA-TEST5', name: 'State Agent 5', phone: '9000000082', level: 'STATE', parentId: regionAgent.id })
      .returning();
    const [districtAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-DIS-TEST4', name: 'District Agent 4', phone: '9000000081', level: 'DISTRICT', parentId: stateAgent.id })
      .returning();
    const [assemblyAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-ASM-TEST3', name: 'Assembly Agent 3', phone: '9000000080', level: 'ASSEMBLY', parentId: districtAgent.id })
      .returning();
    const [lsgdAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-LSG-TEST2', name: 'Lsgd Agent 2', phone: '9000000079', level: 'LSGD', parentId: assemblyAgent.id })
      .returning();
    const [wardAgent] = await db
      .insert(agent)
      .values({ code: 'SHD-WRD-TEST1', name: 'Ward Agent', phone: '9000000078', level: 'WARD', parentId: lsgdAgent.id })
      .returning();

    await db.insert(users).values({ phone: '9000000077', name: 'Eighth Member', firebaseUid: 'member-wallet-8' });
    firebase.register('member-8-token', { uid: 'member-wallet-8' });
    const eighthMemberToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-8-token' }).expect(200)
    ).body.accessToken;

    // agentId (NATIONAL) has already earned from earlier tests in this file
    // — read its current figure rather than assume a fixed value.
    const [nationalBefore] = await db.select().from(agent).where(eq(agent.id, agentId));

    const submitted = await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${eighthMemberToken}`)
      .send({ tierId, amount: 10000, agentCode: 'SHD-WRD-TEST1' })
      .expect(201);

    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${submitted.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);

    const [wardAfter] = await db.select().from(agent).where(eq(agent.id, wardAgent.id));
    expect(Number(wardAfter.earned)).toBe(600); // 10000 * 10% pool * 60% direct share
    expect(Number(wardAfter.personalSales)).toBe(10000);

    const [lsgdAfter] = await db.select().from(agent).where(eq(agent.id, lsgdAgent.id));
    expect(Number(lsgdAfter.earned)).toBe(100); // hop 1: 10% pool

    const [assemblyAfter] = await db.select().from(agent).where(eq(agent.id, assemblyAgent.id));
    expect(Number(assemblyAfter.earned)).toBe(60); // hop 2: 6% pool

    const [districtAfter] = await db.select().from(agent).where(eq(agent.id, districtAgent.id));
    expect(Number(districtAfter.earned)).toBe(50); // hop 3: 5% pool

    const [stateAfter] = await db.select().from(agent).where(eq(agent.id, stateAgent.id));
    expect(Number(stateAfter.earned)).toBe(40); // hop 4: 4% pool

    const [regionAfter] = await db.select().from(agent).where(eq(agent.id, regionAgent.id));
    expect(Number(regionAfter.earned)).toBe(30); // hop 5: 3% pool

    const [nationalAfter] = await db.select().from(agent).where(eq(agent.id, agentId));
    expect(Number(nationalAfter.earned) - Number(nationalBefore.earned)).toBe(20); // hop 6: 2% pool

    const reserve = await request(app.getHttpServer())
      .get('/v1/staff/wallet-cards/reserve')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    const thisEntry = reserve.body.entries.find((e: { walletCardId: number }) => e.walletCardId === submitted.body.id);
    expect(Number(thisEntry.amount)).toBe(100); // 1000 pool - 600 direct - 100 - 60 - 50 - 40 - 30 - 20
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

  it('applies an agent code typed into the "Referral ID" field at registration, linking as that agent\'s customer', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/referrals/apply-code')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ code: 'SHD-NAT-TEST1' })
      .expect(201);
    expect(res.body.linked).toBe('agent');

    // Idempotent — applying again (a retry, or a second code typed later)
    // does nothing: a member links to at most one agent, ever.
    const again = await request(app.getHttpServer())
      .post('/v1/member/referrals/apply-code')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ code: 'SHD-NAT-TEST1' })
      .expect(201);
    expect(again.body.linked).toBe('none');
  });

  it('applies a fellow member\'s referral code, recording the referral edge as REGISTERED', async () => {
    // memberAccessToken's own member plays the inviter here — being agent-
    // linked (previous test) or a referral inviter are independent, never
    // colliding facts about the same account.
    const codeRes = await request(app.getHttpServer())
      .get('/v1/member/referrals/code')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    const inviterCode = codeRes.body.code as string;

    await db.insert(users).values({ phone: '9000000013', name: 'New Signup', firebaseUid: 'member-signup-code-member' });
    firebase.register('signup-code-member-token', { uid: 'member-signup-code-member' });
    const inviteeToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'signup-code-member-token' }).expect(200)
    ).body.accessToken;

    const res = await request(app.getHttpServer())
      .post('/v1/member/referrals/apply-code')
      .set('Authorization', `Bearer ${inviteeToken}`)
      .send({ code: inviterCode })
      .expect(201);
    expect(res.body.linked).toBe('member');

    // memberId already carries an unrelated SHARED referral row from an
    // earlier test in this file — filter on the code this test actually
    // used, not just the inviter, to find the right one.
    const [edge] = await db.select().from(referral).where(eq(referral.codeUsed, inviterCode));
    expect(edge.status).toBe('REGISTERED');
    expect(edge.inviterMemberId).toBe(memberId);
  });

  it('applies an agent code typed in lowercase — the field is never forced to a fixed case, so this must resolve exactly like the upper-case original', async () => {
    const [freshMember] = await db
      .insert(users)
      .values({ phone: '9000000023', name: 'Lowercase Agent Code Typist', firebaseUid: 'member-agent-code-lowercase' })
      .returning();
    const freshToken = await directMemberToken(freshMember.id);

    const res = await request(app.getHttpServer())
      .post('/v1/member/referrals/apply-code')
      .set('Authorization', `Bearer ${freshToken}`)
      .send({ code: 'shd-nat-test1' })
      .expect(201);
    expect(res.body.linked).toBe('agent');
  });

  it("applies a fellow member's referral code typed in lowercase — same reasoning as the agent-code case above", async () => {
    const codeRes = await request(app.getHttpServer())
      .get('/v1/member/referrals/code')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    const inviterCode = codeRes.body.code as string; // 'SHIELD-####'

    const [freshInvitee] = await db
      .insert(users)
      .values({ phone: '9000000024', name: 'Lowercase Member Code Typist', firebaseUid: 'member-referral-code-lowercase' })
      .returning();
    const freshInviteeToken = await directMemberToken(freshInvitee.id);

    const res = await request(app.getHttpServer())
      .post('/v1/member/referrals/apply-code')
      .set('Authorization', `Bearer ${freshInviteeToken}`)
      .send({ code: inviterCode.toLowerCase() })
      .expect(201);
    expect(res.body.linked).toBe('member');

    const [edge] = await db
      .select()
      .from(referral)
      .where(and(eq(referral.inviterMemberId, memberId), eq(referral.inviteeMemberId, freshInvitee.id)));
    expect(edge.status).toBe('REGISTERED');
    // Stored as the canonical upper-case code, not whatever case was typed.
    expect(edge.codeUsed).toBe(inviterCode);
  });

  it('does nothing for a code that matches neither an agent nor a member', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/referrals/apply-code')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ code: 'NOT-A-REAL-CODE' })
      .expect(201);
    expect(res.body.linked).toBe('none');
  });

  it('does nothing when a member applies their own referral code', async () => {
    const codeRes = await request(app.getHttpServer())
      .get('/v1/member/referrals/code')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);

    const res = await request(app.getHttpServer())
      .post('/v1/member/referrals/apply-code')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ code: codeRes.body.code })
      .expect(201);
    expect(res.body.linked).toBe('none');
  });

  it('credits the referring member 2% of every plan a referred member activates, and pays real reward points once their direct-referral count crosses a referral_level rung', async () => {
    // A fresh inviter, so the wallet/points assertions below aren't
    // polluted by anything an earlier test in this file already did to
    // memberId's own wallet or points.
    const [inviter] = await db
      .insert(users)
      .values({ phone: '9000000020', name: 'Referral Inviter', firebaseUid: 'member-referral-inviter' })
      .returning();
    const inviterToken = await directMemberToken(inviter.id);

    const codeRes = await request(app.getHttpServer())
      .get('/v1/member/referrals/code')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(200);
    const inviterCode = codeRes.body.code as string;

    // referral_level's first rung (Starter) needs 2 direct referrals.
    const [firstInvitee] = await db
      .insert(users)
      .values({ phone: '9000000021', name: 'First Invitee', firebaseUid: 'member-referral-invitee-1' })
      .returning();
    const [secondInvitee] = await db
      .insert(users)
      .values({ phone: '9000000022', name: 'Second Invitee', firebaseUid: 'member-referral-invitee-2' })
      .returning();
    const firstInviteeToken = await directMemberToken(firstInvitee.id);
    const secondInviteeToken = await directMemberToken(secondInvitee.id);

    await request(app.getHttpServer())
      .post('/v1/member/referrals/apply-code')
      .set('Authorization', `Bearer ${firstInviteeToken}`)
      .send({ code: inviterCode })
      .expect(201);
    await request(app.getHttpServer())
      .post('/v1/member/referrals/apply-code')
      .set('Authorization', `Bearer ${secondInviteeToken}`)
      .send({ code: inviterCode })
      .expect(201);

    // First activation: a 2% commission, but only 1 of the 2 referrals
    // Starter needs — no reward points yet.
    const firstCard = await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${firstInviteeToken}`)
      .send({ tierId, amount: 10000 })
      .expect(201);
    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${firstCard.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);

    const [afterFirst] = await db.select().from(users).where(eq(users.id, inviter.id));
    expect(afterFirst.referralLevelAwarded).toBe(0);
    expect(afterFirst.rewardPoints).toBe(0);

    const [walletAfterFirst] = await db.select().from(wallet).where(eq(wallet.memberId, inviter.id));
    expect(Number(walletAfterFirst.balance)).toBe(200); // 2% of 10,000

    const [referralAfterFirst] = await db
      .select()
      .from(referral)
      .where(and(eq(referral.inviterMemberId, inviter.id), eq(referral.inviteeMemberId, firstInvitee.id)));
    expect(referralAfterFirst.status).toBe('PLAN_ACTIVATED');
    expect(Number(referralAfterFirst.commissionAmount)).toBe(200);
    expect(Number(referralAfterFirst.planAmount)).toBe(10000);

    // Second activation: a second 2% commission, and this is the referral
    // that crosses Starter (2 referrals -> 100 points).
    const secondCard = await request(app.getHttpServer())
      .post('/v1/member/wallet/cards')
      .set('Authorization', `Bearer ${secondInviteeToken}`)
      .send({ tierId, amount: 10000 })
      .expect(201);
    await request(app.getHttpServer())
      .patch(`/v1/staff/wallet-cards/${secondCard.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);

    const [walletAfterSecond] = await db.select().from(wallet).where(eq(wallet.memberId, inviter.id));
    expect(Number(walletAfterSecond.balance)).toBe(400); // 2% x two ₹10,000 activations

    const [afterSecond] = await db.select().from(users).where(eq(users.id, inviter.id));
    expect(afterSecond.referralLevelAwarded).toBe(1); // Starter cleared
    expect(afterSecond.rewardPoints).toBe(100); // Starter's own points payout

    // getProgress is what the app's own Refer & Earn screen reads — assert
    // the real, credited totals come back from there too, not just the DB.
    const progress = await request(app.getHttpServer())
      .get('/v1/member/referrals/progress')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(200);
    expect(progress.body.directReferrals).toBe(2);
    expect(Number(progress.body.sahakarMoneyEarned)).toBe(400);

    const entries = await request(app.getHttpServer())
      .get('/v1/member/wallet/entries')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(200);
    const referralEntries = entries.body.filter(
      (e: { kind: string }) => e.kind === 'REFERRAL_EARNINGS',
    );
    expect(referralEntries).toHaveLength(2);
  });
});
