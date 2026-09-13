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
import { adminUser, product, productCategory, shieldStore, users } from '../../src/db/schema';
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
});
