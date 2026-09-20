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
import {
  adminUser,
  memberAddress,
  order,
  paymentMethod,
  product,
  productCategory,
  referral,
  shieldStore,
  users,
  wallet,
  walletEntry,
} from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('Commerce (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let memberAccessToken: string;
  let storeAStaffToken: string;
  let storeBStaffToken: string;
  let productId: number;

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

    const [storeA] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-A', name: 'Store A', area: 'A', city: 'A', state: 'A', pincode: '111111' })
      .returning();
    const [storeB] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-B', name: 'Store B', area: 'B', city: 'B', state: 'B', pincode: '222222' })
      .returning();

    const [category] = await db
      .insert(productCategory)
      .values({ slug: 'otc', title: 'OTC', tabLabel: 'OTC' })
      .returning();
    const [seededProduct] = await db
      .insert(product)
      .values({ name: 'Vitamin C', categoryId: category.id, price: '100.00', mrp: '120.00' })
      .returning();
    productId = seededProduct.id;

    const [member] = await db
      .insert(users)
      .values({ phone: '9000000001', name: 'Commerce Member', firebaseUid: 'member-commerce-1', homeStoreId: storeA.id })
      .returning();
    firebase.register('member-token', { uid: 'member-commerce-1' });

    const testPasswordHash = await hash('correct-horse-battery-staple', 4); // low cost factor — this is a test, not production

    await db.insert(adminUser).values({
      loginId: 'storea@example.com',
      name: 'Store A Staff',
      passwordHash: testPasswordHash,
      role: 'PHARMACY',
      storeId: storeA.id,
    });

    await db.insert(adminUser).values({
      loginId: 'storeb@example.com',
      name: 'Store B Staff',
      passwordHash: testPasswordHash,
      role: 'PHARMACY',
      storeId: storeB.id,
    });

    memberAccessToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-token' }).expect(200)
    ).body.accessToken;
    storeAStaffToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'storea@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;
    storeBStaffToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'storeb@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;

    void member; // referenced only for the insert above
  });

  afterAll(async () => {
    await app.close();
  });

  it('prices a cart line from the live product row, not from the client', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/cart/lines')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ productId, qty: 2 })
      .expect(201);

    // Real Postgres (via `pg`) returns NUMERIC as a string; pg-mem returns a
    // JS number in this test environment — assert the value, not the
    // representation, which is a test-harness difference, not a production one.
    expect(Number(res.body.price)).toBe(100);
    expect(Number(res.body.mrp)).toBe(120);
    expect(res.body.qty).toBe(2);
  });

  let orderId: number;

  it('rejects checkout with no Idempotency-Key header', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/orders')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({})
      .expect(400);
  });

  it('checks out, computing totals server-side and clearing the cart', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/orders')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .set('Idempotency-Key', 'checkout-key-1')
      .send({})
      .expect(201);

    orderId = res.body.id;
    expect(res.body.itemCount).toBe(2);
    expect(Number(res.body.paidTotal)).toBe(200);
    expect(Number(res.body.mrpTotal)).toBe(240);
    expect(res.body.status).toBe('PROCESSING');

    const cart = await request(app.getHttpServer())
      .get('/v1/member/cart')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(cart.body.lines).toEqual([]);

    // A paid checkout earns reward points automatically now — ₹200 → 20 pts.
    const me = await request(app.getHttpServer())
      .get('/v1/member/me')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(me.body.rewardPoints).toBe(20);
  });

  it('is idempotent: retrying checkout with the same key returns the same order, not a new one', async () => {
    const retry = await request(app.getHttpServer())
      .post('/v1/member/orders')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .set('Idempotency-Key', 'checkout-key-1')
      .send({})
      .expect(201);

    expect(retry.body.id).toBe(orderId);

    const orders = await request(app.getHttpServer())
      .get('/v1/member/orders')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(orders.body).toHaveLength(1); // not two
  });

  it("lists the order's storeContactedAt for the member's Track order — null until staff contact them", async () => {
    const before = await request(app.getHttpServer())
      .get('/v1/member/orders')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(before.body[0]).toEqual(expect.objectContaining({ id: orderId, storeContactedAt: null }));

    // The admin console stamps this directly (shieldweb/src/api/orders.ts).
    const contactedAt = new Date('2026-09-20T10:15:00.000Z');
    await db.update(order).set({ storeContactedAt: contactedAt }).where(eq(order.id, orderId));

    const after = await request(app.getHttpServer())
      .get('/v1/member/orders')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(after.body[0]).toEqual(
      expect.objectContaining({ id: orderId, storeContactedAt: contactedAt.toISOString() }),
    );

    await db.update(order).set({ storeContactedAt: null }).where(eq(order.id, orderId));
  });

  it("scopes staff order visibility to the order's store — a different store sees nothing", async () => {
    const storeAView = await request(app.getHttpServer())
      .get('/v1/staff/orders')
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .expect(200);
    expect(storeAView.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: orderId })]));

    const storeBView = await request(app.getHttpServer())
      .get('/v1/staff/orders')
      .set('Authorization', `Bearer ${storeBStaffToken}`)
      .expect(200);
    expect(storeBView.body).toEqual([]);

    await request(app.getHttpServer())
      .patch(`/v1/staff/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${storeBStaffToken}`)
      .send({ status: 'OUT_FOR_DELIVERY' })
      .expect(404); // store B genuinely cannot see this order exists
  });

  it('rejects an illegal status transition (skipping straight to DELIVERED)', async () => {
    await request(app.getHttpServer())
      .patch(`/v1/staff/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .send({ status: 'DELIVERED' })
      .expect(409);
  });

  it('walks the legal transition path and rejects reopening a terminal order', async () => {
    await request(app.getHttpServer())
      .patch(`/v1/staff/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .send({ status: 'OUT_FOR_DELIVERY' })
      .expect(200);

    await request(app.getHttpServer())
      .patch(`/v1/staff/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .send({ status: 'DELIVERED' })
      .expect(200);

    await request(app.getHttpServer())
      .patch(`/v1/staff/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .send({ status: 'PROCESSING' })
      .expect(409); // DELIVERED is terminal
  });

  it('submits a manual-transfer receipt claim against the caller\'s own order', async () => {
    const receipt = await request(app.getHttpServer())
      .post(`/v1/member/orders/${orderId}/receipt`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ payerName: 'Commerce Member', reference: 'UTR12345', amount: 200, fileName: 'receipt.jpg' })
      .expect(201);
    expect(receipt.body.reference).toBe('UTR12345');
    expect(Number(receipt.body.amount)).toBe(200);
  });

  it("rejects a receipt claim against an order that isn't the caller's own", async () => {
    await db.insert(users).values({ phone: '9000000098', name: 'Other Member', firebaseUid: 'member-commerce-other' });
    firebase.register('other-member-token', { uid: 'member-commerce-other' });
    const otherLogin = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'other-member-token' })
      .expect(200);

    await request(app.getHttpServer())
      .post(`/v1/member/orders/${orderId}/receipt`)
      .set('Authorization', `Bearer ${otherLogin.body.accessToken}`)
      .send({ reference: 'stolen-claim' })
      .expect(404);
  });

  it('sends a bill as staff and reads it as the owning member', async () => {
    await request(app.getHttpServer())
      .put(`/v1/staff/orders/${orderId}/bill`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .send({ image: 'data:image/png;base64,AAAA' })
      .expect(200);

    const bill = await request(app.getHttpServer())
      .get(`/v1/member/orders/${orderId}/bill`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(bill.body.image).toBe('data:image/png;base64,AAAA');
  });

  it('rejects checkout of an empty cart', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/orders')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .set('Idempotency-Key', 'checkout-key-2')
      .send({})
      .expect(403);
  });

  it("rejects checkout with a deliveryAddressId that belongs to someone else", async () => {
    const [stranger] = await db
      .insert(users)
      .values({ phone: '9000000099', name: 'Stranger', firebaseUid: 'member-commerce-stranger' })
      .returning();
    const [strangerAddress] = await db
      .insert(memberAddress)
      .values({ memberId: stranger.id, house: '1', area: 'Somewhere', pincode: '000000' })
      .returning();

    await request(app.getHttpServer())
      .post('/v1/member/cart/lines')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ productId, qty: 1 })
      .expect(201);

    await request(app.getHttpServer())
      .post('/v1/member/orders')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .set('Idempotency-Key', 'checkout-key-stolen-address')
      .send({ deliveryAddressId: strangerAddress.id })
      .expect(403);

    // The rejected attempt must not have consumed the cart or created an order.
    const cart = await request(app.getHttpServer())
      .get('/v1/member/cart')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(cart.body.lines).toHaveLength(1);
  });

  it("advances the buyer's own referral status to TRANSACTED on their first paid order", async () => {
    const [inviter] = await db
      .insert(users)
      .values({ phone: '9000000050', name: 'Inviter', firebaseUid: 'member-commerce-inviter' })
      .returning();
    const [invitee] = await db
      .insert(users)
      .values({ phone: '9000000051', name: 'Invitee', firebaseUid: 'member-commerce-invitee' })
      .returning();
    await db.insert(referral).values({
      inviterMemberId: inviter.id,
      inviteeMemberId: invitee.id,
      inviteePhone: invitee.phone,
      status: 'REGISTERED',
      registeredAt: new Date(),
    });

    firebase.register('invitee-token', { uid: 'member-commerce-invitee' });
    const inviteeLogin = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'invitee-token' })
      .expect(200);
    const inviteeToken = inviteeLogin.body.accessToken as string;

    await request(app.getHttpServer())
      .post('/v1/member/cart/lines')
      .set('Authorization', `Bearer ${inviteeToken}`)
      .send({ productId, qty: 1 })
      .expect(201);
    await request(app.getHttpServer())
      .post('/v1/member/orders')
      .set('Authorization', `Bearer ${inviteeToken}`)
      .set('Idempotency-Key', 'checkout-key-invitee-1')
      .send({})
      .expect(201);

    const [updatedReferral] = await db.select().from(referral).where(eq(referral.inviteeMemberId, invitee.id));
    expect(updatedReferral.status).toBe('TRANSACTED');
    expect(updatedReferral.transactedAt).not.toBeNull();
  });

  describe('wallet checkout', () => {
    let walletMemberToken: string;
    let walletMethodId: number;
    let walletId: number;

    beforeAll(async () => {
      const [walletMember] = await db
        .insert(users)
        .values({ phone: '9000000060', name: 'Wallet Checkout Member', firebaseUid: 'member-commerce-wallet' })
        .returning();
      firebase.register('wallet-member-token', { uid: 'member-commerce-wallet' });
      const login = await request(app.getHttpServer())
        .post('/v1/member/auth/session')
        .send({ idToken: 'wallet-member-token' })
        .expect(200);
      walletMemberToken = login.body.accessToken;

      const [method] = await db
        .insert(paymentMethod)
        .values({ code: 'wallet', name: 'Wallet balance', isLive: true })
        .returning();
      walletMethodId = method.id;

      // Funded directly, bypassing the card-submission/approval flow — this
      // suite only cares about checkout's own debit logic, not how the
      // balance got there (wallet.e2e-spec.ts already covers that).
      const [createdWallet] = await db.insert(wallet).values({ memberId: walletMember.id, balance: '1000' }).returning();
      walletId = createdWallet.id;
    });

    it('debits the wallet in full and marks the order PAID when walletAmount covers the whole total', async () => {
      await request(app.getHttpServer())
        .post('/v1/member/cart/lines')
        .set('Authorization', `Bearer ${walletMemberToken}`)
        .send({ productId, qty: 3 }) // 3 × ₹100 = ₹300
        .expect(201);

      const res = await request(app.getHttpServer())
        .post('/v1/member/orders')
        .set('Authorization', `Bearer ${walletMemberToken}`)
        .set('Idempotency-Key', 'checkout-key-wallet-full')
        .send({ paymentMethodId: walletMethodId, walletAmount: 300 })
        .expect(201);

      expect(res.body.paymentStatus).toBe('PAID');

      const [row] = await db.select().from(wallet).where(eq(wallet.id, walletId));
      expect(Number(row.balance)).toBe(700); // 1000 - 300

      const entries = await db.select().from(walletEntry).where(eq(walletEntry.walletId, walletId));
      const spend = entries.find((e) => Number(e.amount) === -300);
      expect(spend?.label).toBe(`Order ${res.body.code}`);
    });

    it('caps the debit at the client-supplied walletAmount and leaves the order PENDING when it falls short of the total', async () => {
      await request(app.getHttpServer())
        .post('/v1/member/cart/lines')
        .set('Authorization', `Bearer ${walletMemberToken}`)
        .send({ productId, qty: 6 }) // 6 × ₹100 = ₹600 total, only ₹400 asked of the wallet
        .expect(201);

      const res = await request(app.getHttpServer())
        .post('/v1/member/orders')
        .set('Authorization', `Bearer ${walletMemberToken}`)
        .set('Idempotency-Key', 'checkout-key-wallet-partial')
        .send({ paymentMethodId: walletMethodId, walletAmount: 400 })
        .expect(201);

      expect(Number(res.body.paidTotal)).toBe(600);
      // Never flips PAID on a partial wallet share — the rest is still owed,
      // same as an order paid by cash.
      expect(res.body.paymentStatus).toBe('PENDING');

      const [row] = await db.select().from(wallet).where(eq(wallet.id, walletId));
      expect(Number(row.balance)).toBe(300); // 700 - 400, not 700 - 600

      const entries = await db.select().from(walletEntry).where(eq(walletEntry.walletId, walletId));
      const spend = entries.find((e) => Number(e.amount) === -400);
      expect(spend?.label).toBe(`Order ${res.body.code} (wallet share)`);
    });
  });
});
