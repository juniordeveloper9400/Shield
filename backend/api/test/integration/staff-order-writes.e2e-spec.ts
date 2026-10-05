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
import { adminUser, bill, billLine, order, orderLine, shieldStore, users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

/**
 * The staff order-write endpoints that replaced shieldweb's direct-SQL
 * writes (orders.ts). Each one must be store-scoped and role-gated on the
 * server — that is the whole point of moving them off the browser.
 */
describe('Staff order writes (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let storeAId: number;
  let storeBId: number;
  let storeAOrderId: number;
  let cancelledOrderId: number;
  let pharmacyA: string;
  let pharmacyB: string;
  let adminToken: string;
  let labToken: string;

  const PASSWORD = 'correct-horse-battery-staple';

  beforeAll(async () => {
    db = createTestDb();
    const firebase = new FakeFirebaseVerifier();
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
    storeAId = storeA.id;
    storeBId = storeB.id;

    const [member] = await db
      .insert(users)
      .values({ phone: '9000000050', name: 'Writes Member', firebaseUid: 'member-writes-1', homeStoreId: storeA.id })
      .returning();

    const [placed] = await db
      .insert(order)
      .values({
        memberId: member.id,
        code: 'SHD-W-1',
        storeId: storeA.id,
        placedOn: new Date().toISOString().slice(0, 10),
        itemCount: 1,
        mrpTotal: '100.00',
        paidTotal: '0.00',
      })
      .returning();
    storeAOrderId = placed.id;
    await db.insert(orderLine).values({ orderId: placed.id, name: 'Vitamin C', pack: '', unitPrice: '100', mrp: '120', qty: 1 });

    const [cancelled] = await db
      .insert(order)
      .values({
        memberId: member.id,
        code: 'SHD-W-2',
        storeId: storeA.id,
        status: 'CANCELLED',
        placedOn: new Date().toISOString().slice(0, 10),
        itemCount: 1,
        mrpTotal: '50.00',
        paidTotal: '0.00',
      })
      .returning();
    cancelledOrderId = cancelled.id;

    const passwordHash = await hash(PASSWORD, 4);
    await db.insert(adminUser).values([
      { loginId: 'pa@example.com', name: 'Pharmacy A', passwordHash, role: 'PHARMACY', storeId: storeA.id },
      { loginId: 'pb@example.com', name: 'Pharmacy B', passwordHash, role: 'PHARMACY', storeId: storeB.id },
      { loginId: 'admin-w@example.com', name: 'Plain Admin', passwordHash, role: 'ADMIN' },
      { loginId: 'lab-w@example.com', name: 'Lab', passwordHash, role: 'LAB', storeId: storeA.id },
    ]);

    const session = async (loginId: string) =>
      (await request(app.getHttpServer()).post('/v1/staff/auth/session').send({ loginId, password: PASSWORD }).expect(200)).body
        .accessToken as string;
    pharmacyA = await session('pa@example.com');
    pharmacyB = await session('pb@example.com');
    adminToken = await session('admin-w@example.com');
    labToken = await session('lab-w@example.com');
  });

  afterAll(async () => {
    await app.close();
  });

  const http = () => app.getHttpServer();

  describe('review (Save / Convert to bill on the review page)', () => {
    it('lets the owning branch change a line\'s stock call and add a line by hand', async () => {
      const lines = await db.select().from(orderLine).where(eq(orderLine.orderId, storeAOrderId));
      await request(http())
        .patch(`/v1/staff/orders/${storeAOrderId}/review`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .send({
          lines: [{ id: lines[0].id, status: 'OUT_OF_STOCK' }],
          newLines: [{ name: 'Crocin', pack: '10 tabs', unitPrice: 30, qty: 2, status: 'AVAILABLE' }],
          storeId: storeAId,
        })
        .expect(200);

      const after = await db.select().from(orderLine).where(eq(orderLine.orderId, storeAOrderId));
      expect(after.find((l) => l.id === lines[0].id)?.stockStatus).toBe('OUT_OF_STOCK');
      expect(after.some((l) => l.name === 'Crocin')).toBe(true);
      const [o] = await db.select().from(order).where(eq(order.id, storeAOrderId));
      expect(o.itemCount).toBe(2);
      expect(o.reviewedAt).not.toBeNull();
      expect(Number(o.mrpTotal)).toBe(100); // checkout price is never rewritten
    });

    it('refuses a branch account reaching an order that belongs to another branch', async () => {
      await request(http())
        .patch(`/v1/staff/orders/${storeAOrderId}/review`)
        .set('Authorization', `Bearer ${pharmacyB}`)
        .send({ lines: [], newLines: [], storeId: storeBId })
        .expect(404);
    });

    it('refuses a branch account moving its own order to a different branch', async () => {
      await request(http())
        .patch(`/v1/staff/orders/${storeAOrderId}/review`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .send({ lines: [], newLines: [], storeId: storeBId })
        .expect(403);
      const [o] = await db.select().from(order).where(eq(order.id, storeAOrderId));
      expect(o.storeId).toBe(storeAId);
    });

    it('lets an admin move the order to another branch', async () => {
      await request(http())
        .patch(`/v1/staff/orders/${storeAOrderId}/review`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ lines: [], newLines: [], storeId: storeBId })
        .expect(200);
      const [o] = await db.select().from(order).where(eq(order.id, storeAOrderId));
      expect(o.storeId).toBe(storeBId);
      // Put it back so the rest of the suite sees the branch it started on.
      await request(http())
        .patch(`/v1/staff/orders/${storeAOrderId}/review`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ lines: [], newLines: [], storeId: storeAId })
        .expect(200);
    });

    it('refuses a role without the orders module (LAB), even for its own branch', async () => {
      await request(http())
        .patch(`/v1/staff/orders/${storeAOrderId}/review`)
        .set('Authorization', `Bearer ${labToken}`)
        .send({ lines: [], newLines: [], storeId: storeAId })
        .expect(403);
    });
  });

  describe('convert to bill, store contact and complete', () => {
    it('stamps converted-to-bill once, and refuses a cancelled order', async () => {
      await request(http())
        .patch(`/v1/staff/orders/${storeAOrderId}/converted-to-bill`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .expect(200);
      const [first] = await db.select().from(order).where(eq(order.id, storeAOrderId));
      expect(first.convertedToBillAt).not.toBeNull();

      await request(http())
        .patch(`/v1/staff/orders/${storeAOrderId}/converted-to-bill`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .expect(200);
      const [again] = await db.select().from(order).where(eq(order.id, storeAOrderId));
      expect(again.convertedToBillAt?.getTime()).toBe(first.convertedToBillAt?.getTime());

      await request(http())
        .patch(`/v1/staff/orders/${cancelledOrderId}/converted-to-bill`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .expect(409);
    });

    it('keeps the first store-contact stamp', async () => {
      const first = await request(http())
        .patch(`/v1/staff/orders/${storeAOrderId}/store-contacted`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .expect(200);
      const second = await request(http())
        .patch(`/v1/staff/orders/${storeAOrderId}/store-contacted`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .expect(200);
      expect(second.body.storeContactedAt).toBe(first.body.storeContactedAt);
    });

    it('refuses to complete an order with no priced bill, and completes one that has it', async () => {
      await request(http())
        .patch(`/v1/staff/orders/${storeAOrderId}/complete`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .expect(409);

      await request(http())
        .put(`/v1/staff/orders/${storeAOrderId}/invoice`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .send({ amount: 90, discountAmount: 10, lines: [{ name: 'Vitamin C', unitPrice: 100, qty: 1 }] })
        .expect(200);

      await request(http())
        .patch(`/v1/staff/orders/${storeAOrderId}/complete`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .expect(200);
      const [o] = await db.select().from(order).where(eq(order.id, storeAOrderId));
      expect(o.status).toBe('DELIVERED');
    });
  });

  describe('bills', () => {
    it('an itemised invoice replaces the lines and reflects the priced total onto the order', async () => {
      await request(http())
        .put(`/v1/staff/orders/${storeAOrderId}/invoice`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .send({
          amount: 180,
          discountAmount: 20,
          lines: [
            { name: 'Vitamin C', unitPrice: 100, qty: 1 },
            { name: 'Zinc', unitPrice: 40, qty: 2 },
          ],
        })
        .expect(200);
      const [b] = await db.select().from(bill).where(eq(bill.orderId, storeAOrderId));
      expect(Number(b.amount)).toBe(180);
      expect(Number(b.discountAmount)).toBe(20);
      const lines = await db.select().from(billLine).where(eq(billLine.billId, b.id));
      expect(lines.map((l) => l.name).sort()).toEqual(['Vitamin C', 'Zinc']);
    });

    it('a picture-only send keeps the priced amount and the discount', async () => {
      await request(http())
        .put(`/v1/staff/orders/${storeAOrderId}/picture`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .send({ image: 'data:image/png;base64,AAAA' })
        .expect(200);
      const [b] = await db.select().from(bill).where(eq(bill.orderId, storeAOrderId));
      expect(b.image).toBe('data:image/png;base64,AAAA');
      expect(Number(b.amount)).toBe(180);
      expect(Number(b.discountAmount)).toBe(20);
    });

    it('withdrawing a bill removes it and its lines', async () => {
      await request(http())
        .delete(`/v1/staff/orders/${storeAOrderId}/bill`)
        .set('Authorization', `Bearer ${pharmacyA}`)
        .expect(200);
      expect(await db.select().from(bill).where(eq(bill.orderId, storeAOrderId))).toHaveLength(0);
    });

    it('a branch account cannot withdraw another branch\'s bill', async () => {
      await request(http())
        .delete(`/v1/staff/orders/${storeAOrderId}/bill`)
        .set('Authorization', `Bearer ${pharmacyB}`)
        .expect(404);
    });
  });
});
