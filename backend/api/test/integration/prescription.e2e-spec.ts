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
import { eq } from 'drizzle-orm';
import { adminUser, order, patient, prescription, prescriptionImage, shieldStore, users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { OtpService } from '../../src/modules/otp/otp.service';
import { FakeOtpService, memberLogin } from './fake-otp';

// A real (tiny, valid) 1x1 transparent PNG.
const PNG_DATA_URI =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

describe('Prescription (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let memberAccessToken: string;
  let storeAStaffToken: string;
  let storeBStaffToken: string;
  let adminAccessToken: string;
  let patientId: number;

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

    const [storeA] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-RXA', name: 'Store A', area: 'A', city: 'A', state: 'A', pincode: '111111' })
      .returning();
    const [storeB] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-RXB', name: 'Store B', area: 'B', city: 'B', state: 'B', pincode: '222222' })
      .returning();

    const [member] = await db
      .insert(users)
      .values({ phone: '9000000002', name: 'Rx Member', firebaseUid: 'member-rx-1', homeStoreId: storeA.id, registrationCompletedAt: new Date() })
      .returning();

    const [seededPatient] = await db
      .insert(patient)
      .values({ memberId: member.id, name: 'Self', dob: '1990-01-01', relation: 'SELF' })
      .returning();
    patientId = seededPatient.id;

    const testPasswordHash = await hash('correct-horse-battery-staple', 4); // low cost factor — this is a test, not production

    await db.insert(adminUser).values({
      loginId: 'rx-storea@example.com',
      name: 'Store A Pharmacist',
      passwordHash: testPasswordHash,
      role: 'PHARMACY',
      storeId: storeA.id,
    });

    await db.insert(adminUser).values({
      loginId: 'rx-storeb@example.com',
      name: 'Store B Pharmacist',
      passwordHash: testPasswordHash,
      role: 'PHARMACY',
      storeId: storeB.id,
    });

    // No storeId — an ADMIN account is unscoped like SUPERADMIN, not
    // store-bound like PHARMACY. Regression coverage for the bug where this
    // service only special-cased SUPERADMIN, leaving every plain ADMIN
    // account's prescriptions list (and "My Orders" by extension) empty.
    await db.insert(adminUser).values({
      loginId: 'rx-admin@example.com',
      name: 'Plain Admin',
      passwordHash: testPasswordHash,
      role: 'ADMIN',
    });

    memberAccessToken = (
      await memberLogin(app, '9000000002').expect(200)
    ).body.accessToken;
    storeAStaffToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'rx-storea@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;
    storeBStaffToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'rx-storeb@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;
    adminAccessToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'rx-admin@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  let prescriptionId: number;

  it('rejects uploading a prescription for a patient that is not the member\'s own', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/prescriptions')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ patientId: 999999, images: [PNG_DATA_URI] })
      .expect(403);
  });

  it('uploads a prescription, storing up to 3 images and never exposing the raw column names', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/prescriptions')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({
        patientId,
        images: [PNG_DATA_URI, PNG_DATA_URI],
        doctor: 'Dr. Rao',
        recurringFrom: '2026-01-01',
        recurringUntil: '2026-06-01',
      })
      .expect(201);

    prescriptionId = res.body.id;
    expect(res.body.images).toHaveLength(2);
    expect(res.body.images[0].image).toBe(PNG_DATA_URI);
    expect(res.body.images[0].rotation).toBe(0);
    expect(res.body.storagePath).toBeUndefined();
    expect(res.body.image).toBeUndefined();
    expect(res.body.imageRotation).toBeUndefined();
    expect(res.body.status).toBe('AWAITING_REVIEW');
    expect(String(res.body.recurringFrom)).toContain('2026-01-01');
    expect(String(res.body.recurringUntil)).toContain('2026-06-01');
  });

  it('rejects more than 3 images on a single prescription', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/prescriptions')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ patientId, images: [PNG_DATA_URI, PNG_DATA_URI, PNG_DATA_URI, PNG_DATA_URI] })
      .expect(400);
  });

  it('uploads a prescription with no photo — a script phoned in, not an error case', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/prescriptions')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ patientId, doctor: 'Dr. Rao (phone)' })
      .expect(201);
    expect(res.body.images).toEqual([]);
  });

  it("hides the pharmacist-only medicine status field from the member, but not from staff", async () => {
    const addLine = await request(app.getHttpServer())
      .post(`/v1/staff/prescriptions/${prescriptionId}/medicines`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .send({ name: 'Paracetamol', doseMorning: 1, doseNight: 1, totalUnits: 10 })
      .expect(201);
    expect(addLine.body.status).toBe('AVAILABLE'); // staff sees it

    const memberView = await request(app.getHttpServer())
      .get(`/v1/member/prescriptions/${prescriptionId}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(memberView.body.medicines).toHaveLength(1);
    expect(memberView.body.medicines[0]).not.toHaveProperty('status'); // hidden from the member
    expect(memberView.body.medicines[0].name).toBe('Paracetamol');

    const staffView = await request(app.getHttpServer())
      .get(`/v1/staff/prescriptions/${prescriptionId}`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .expect(200);
    expect(staffView.body.medicines[0].status).toBe('AVAILABLE'); // visible to staff
  });

  it('scopes staff prescription visibility to the store it belongs to', async () => {
    await request(app.getHttpServer())
      .get(`/v1/staff/prescriptions/${prescriptionId}`)
      .set('Authorization', `Bearer ${storeBStaffToken}`)
      .expect(404);
  });

  it('an ADMIN with no store assigned still sees it, same as SUPERADMIN', async () => {
    const list = await request(app.getHttpServer())
      .get('/v1/staff/prescriptions')
      .set('Authorization', `Bearer ${adminAccessToken}`)
      .expect(200);
    expect(list.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: prescriptionId })]));

    await request(app.getHttpServer())
      .get(`/v1/staff/prescriptions/${prescriptionId}`)
      .set('Authorization', `Bearer ${adminAccessToken}`)
      .expect(200);
  });

  it('rotates one image on a multi-page prescription without touching the others', async () => {
    const before = await request(app.getHttpServer())
      .get(`/v1/staff/prescriptions/${prescriptionId}`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .expect(200);
    expect(before.body.images).toHaveLength(2);
    const [firstImage, secondImage] = before.body.images;

    await request(app.getHttpServer())
      .patch(`/v1/staff/prescriptions/${prescriptionId}/images/${firstImage.id}/rotation`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .send({ rotation: 90 })
      .expect(200);

    const after = await request(app.getHttpServer())
      .get(`/v1/staff/prescriptions/${prescriptionId}`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .expect(200);
    const updatedFirst = after.body.images.find((i: { id: number }) => i.id === firstImage.id);
    const updatedSecond = after.body.images.find((i: { id: number }) => i.id === secondImage.id);
    expect(updatedFirst.rotation).toBe(90);
    expect(updatedSecond.rotation).toBe(0); // untouched
  });

  it('rejects rotating an image on a prescription from a different store', async () => {
    const staffView = await request(app.getHttpServer())
      .get(`/v1/staff/prescriptions/${prescriptionId}`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .expect(200);
    await request(app.getHttpServer())
      .patch(`/v1/staff/prescriptions/${prescriptionId}/images/${staffView.body.images[0].id}/rotation`)
      .set('Authorization', `Bearer ${storeBStaffToken}`)
      .send({ rotation: 180 })
      .expect(404);
  });

  it('enforces the prescription status state machine — no skipping READ', async () => {
    await request(app.getHttpServer())
      .patch(`/v1/staff/prescriptions/${prescriptionId}/status`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .send({ status: 'IN_CART' })
      .expect(409); // must go through READ first

    await request(app.getHttpServer())
      .patch(`/v1/staff/prescriptions/${prescriptionId}/status`)
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .send({ status: 'READ' })
      .expect(200);
  });

  let approvalId: number;
  let itemAcceptId: number;
  let itemRejectId: number;

  it('raises an approval from staff, store-scoped through the prescription', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/staff/approvals')
      .set('Authorization', `Bearer ${storeAStaffToken}`)
      .send({
        prescriptionId,
        pharmacistNote: 'Substitution needed for one item',
        items: [
          { name: 'Paracetamol 500mg', quantity: 10, price: 2.5 },
          { name: 'Crocin (substitute)', quantity: 10, price: 3 },
        ],
      })
      .expect(201);

    approvalId = res.body.id;
    expect(res.body.status).toBe('PENDING');
    expect(res.body.items).toHaveLength(2);
    itemAcceptId = res.body.items[0].id;
    itemRejectId = res.body.items[1].id;
  });

  it('rejects raising an approval from a different store', async () => {
    await request(app.getHttpServer())
      .post('/v1/staff/approvals')
      .set('Authorization', `Bearer ${storeBStaffToken}`)
      .send({ prescriptionId, items: [{ name: 'X', quantity: 1, price: 1 }] })
      .expect(403);
  });

  it('rejects a member response that does not cover every item', async () => {
    await request(app.getHttpServer())
      .post(`/v1/member/approvals/${approvalId}/respond`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ items: [{ approvalItemId: itemAcceptId, isAccepted: true }] })
      .expect(400);
  });

  it('lets the member accept one item and reject the other, computing PARTIALLY_APPROVED', async () => {
    const res = await request(app.getHttpServer())
      .post(`/v1/member/approvals/${approvalId}/respond`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({
        items: [
          { approvalItemId: itemAcceptId, isAccepted: true },
          { approvalItemId: itemRejectId, isAccepted: false },
        ],
      })
      .expect(201);

    expect(res.body.status).toBe('PARTIALLY_APPROVED');
  });

  it('rejects responding to an approval a second time', async () => {
    await request(app.getHttpServer())
      .post(`/v1/member/approvals/${approvalId}/respond`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({
        items: [
          { approvalItemId: itemAcceptId, isAccepted: true },
          { approvalItemId: itemRejectId, isAccepted: true },
        ],
      })
      .expect(403);
  });

  it('rejects submitting a prescription that does not belong to the caller', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/prescription-orders')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ prescriptionIds: [999999] })
      .expect(403);
  });

  it('rejects deleting a prescription that does not belong to the caller', async () => {
    await request(app.getHttpServer())
      .delete('/v1/member/prescriptions/999999')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(404);
  });

  it('deletes one of the caller\'s own prescriptions, dropping it from their list', async () => {
    const uploaded = await request(app.getHttpServer())
      .post('/v1/member/prescriptions')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ patientId, images: [PNG_DATA_URI] })
      .expect(201);
    const toDeleteId = uploaded.body.id;

    await request(app.getHttpServer())
      .delete(`/v1/member/prescriptions/${toDeleteId}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(204);

    await request(app.getHttpServer())
      .get(`/v1/member/prescriptions/${toDeleteId}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(404);

    const list = await request(app.getHttpServer())
      .get('/v1/member/prescriptions')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(list.body.map((r: { id: number }) => r.id)).not.toContain(toDeleteId);

    // A second delete of the same (now-deleted) row succeeds idempotently.
    await request(app.getHttpServer())
      .delete(`/v1/member/prescriptions/${toDeleteId}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(204);
  });

  it('submits a prescription for fulfilment: an unpriced order, track steps, and ORDERED status', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/prescription-orders')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ prescriptionIds: [prescriptionId] })
      .expect(201);

    expect(res.body.kind).toBe('PRESCRIPTION');
    expect(Number(res.body.mrpTotal)).toBe(0);
    expect(Number(res.body.paidTotal)).toBe(0);
    expect(res.body.itemCount).toBe(1); // one medicine line was added earlier

    const order = await request(app.getHttpServer())
      .get(`/v1/member/orders/${res.body.id}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(order.body.steps).toHaveLength(5);
    expect(order.body.steps[0].title).toBe('Prescription received');
    expect(order.body.steps[0].state).toBe('DONE');
    expect(order.body.steps[1].state).toBe('CURRENT');

    const rx = await request(app.getHttpServer())
      .get(`/v1/member/prescriptions/${prescriptionId}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(rx.body.status).toBe('ORDERED');

    // What "Prescription uploaded" on order tracking actually renders — the
    // real scan, not a generic icon standing in for it.
    const linked = await request(app.getHttpServer())
      .get(`/v1/member/orders/${res.body.id}/prescriptions`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(linked.body).toHaveLength(1);
    expect(linked.body[0].id).toBe(prescriptionId);
    expect(linked.body[0].image).toBe(rx.body.images[0].image);
  });

  describe('the order-tracking status on a prescription', () => {
    const getRx = async () =>
      (
        await request(app.getHttpServer())
          .get(`/v1/member/prescriptions/${prescriptionId}`)
          .set('Authorization', `Bearer ${memberAccessToken}`)
          .expect(200)
      ).body;

    it('links the order the prescription was placed into, at its first stage', async () => {
      const rx = await getRx();

      expect(rx.order).toEqual(
        expect.objectContaining({
          code: expect.stringMatching(/^RX-/),
          status: 'PROCESSING',
          storeContactedAt: null,
          billed: false,
        }),
      );
      expect(typeof rx.order.id).toBe('number');
    });

    it('follows the order through store contact and billing', async () => {
      const { order: linked } = await getRx();

      await db.update(order).set({ storeContactedAt: new Date('2026-09-20T10:15:00Z') }).where(eq(order.id, linked.id));
      const contacted = (await getRx()).order;
      expect(new Date(contacted.storeContactedAt).toISOString()).toBe('2026-09-20T10:15:00.000Z');
      expect(contacted.billed).toBe(false);

      // "billed" means converted to bill — the admin console's own
      // "Billing" milestone — not whether a priced `app.bill` row exists
      // yet, which lands later as its own separate step.
      await db.update(order).set({ convertedToBillAt: new Date('2026-09-21T09:00:00Z') }).where(eq(order.id, linked.id));
      expect((await getRx()).order.billed).toBe(true);

      await db.update(order).set({ status: 'DELIVERED' }).where(eq(order.id, linked.id));
      expect((await getRx()).order.status).toBe('DELIVERED');
    });

    it('carries the same order on the list, and null for a prescription never ordered', async () => {
      const list = (
        await request(app.getHttpServer())
          .get('/v1/member/prescriptions')
          .set('Authorization', `Bearer ${memberAccessToken}`)
          .expect(200)
      ).body as { id: number; order: { code: string } | null }[];

      const ordered = list.find((r) => r.id === prescriptionId);
      expect(ordered?.order?.code).toMatch(/^RX-/);
      // Other prescriptions in this file were uploaded but never ordered.
      expect(list.some((r) => r.id !== prescriptionId && r.order === null)).toBe(true);
    });
  });

  describe('console detail (its own fresh fixture — prescriptionId above is mutated by earlier tests)', () => {
    let storeAId: number;
    let freshRxId: number;
    let deliveryBoyToken: string;

    beforeAll(async () => {
      [storeAId] = (await db.select({ id: shieldStore.id }).from(shieldStore).where(eq(shieldStore.code, 'SHD-RXA'))).map((r) => r.id);
      const [member] = await db.select({ id: users.id }).from(users).where(eq(users.phone, '9000000002'));

      const [created] = await db
        .insert(prescription)
        .values({ memberId: member.id, patientId, storeId: null, code: 'RX-CONSOLE-TEST', fileName: 'script.jpg' })
        .returning();
      freshRxId = created.id;
      await db.insert(prescriptionImage).values([
        { prescriptionId: freshRxId, sort: 0, image: PNG_DATA_URI },
        { prescriptionId: freshRxId, sort: 1, image: PNG_DATA_URI },
      ]);

      await db.insert(adminUser).values({
        loginId: 'rx-delivery@example.com',
        name: 'Delivery',
        passwordHash: await hash('correct-horse-battery-staple', 4),
        role: 'DELIVERY',
        storeId: storeAId,
      });
      deliveryBoyToken = (
        await request(app.getHttpServer())
          .post('/v1/staff/auth/session')
          .send({ loginId: 'rx-delivery@example.com', password: 'correct-horse-battery-staple' })
          .expect(200)
      ).body.accessToken;
    });

    it("rejects a role that isn't SUPERADMIN/ADMIN/PHARMACY — prescriptions isn't in DELIVERY's module list", async () => {
      await request(app.getHttpServer())
        .get('/v1/staff/prescriptions')
        .set('Authorization', `Bearer ${deliveryBoyToken}`)
        .expect(403);
    });

    it("a store's own staff sees a never-pinned prescription through the member's home-store fallback, not just the admin role", async () => {
      const list = await request(app.getHttpServer())
        .get('/v1/staff/prescriptions')
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .expect(200);
      const row = list.body.find((r: { id: number }) => r.id === freshRxId);
      expect(row).toBeDefined();
      expect(row.storeCode).toBe('SHD-RXA'); // resolved via the member's own home store

      // Store B's own staff never sees it — the fallback resolves to A, not B.
      const otherList = await request(app.getHttpServer())
        .get('/v1/staff/prescriptions')
        .set('Authorization', `Bearer ${storeBStaffToken}`)
        .expect(200);
      expect(otherList.body.map((r: { id: number }) => r.id)).not.toContain(freshRxId);
    });

    it('replaces the intake card wholesale, moves to READ, and drops blank rows', async () => {
      await request(app.getHttpServer())
        .post(`/v1/staff/prescriptions/${freshRxId}/intake`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .send({
          medicines: [
            { name: 'Paracetamol', pack: '10 tabs', intake: '1-0-1', totalUnits: 20, routeTime: 'After food', status: 'available' },
            { name: '  ', intake: '1-1-1' }, // blank — dropped
          ],
        })
        .expect(201);

      const detail = await request(app.getHttpServer())
        .get(`/v1/staff/prescriptions/${freshRxId}`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .expect(200);
      expect(detail.body.status).toBe('READ');
      expect(detail.body.medicines).toHaveLength(1);
      expect(detail.body.medicines[0]).toEqual(
        expect.objectContaining({ name: 'Paracetamol', doseMorning: 1, doseAfternoon: 0, doseNight: 1, totalUnits: 20 }),
      );
    });

    it('"back to awaiting" is a legal reverse transition from READ — the console relies on this to undo a review', async () => {
      await request(app.getHttpServer())
        .patch(`/v1/staff/prescriptions/${freshRxId}/status`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .send({ status: 'AWAITING_REVIEW' })
        .expect(200);

      const detail = await request(app.getHttpServer())
        .get(`/v1/staff/prescriptions/${freshRxId}`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .expect(200);
      expect(detail.body.status).toBe('AWAITING_REVIEW');
    });

    it('updates the doctor/duration details, refusing an unknown duration token', async () => {
      await request(app.getHttpServer())
        .patch(`/v1/staff/prescriptions/${freshRxId}/details`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .send({ doctor: 'Dr. Rao', durationToken: 'one_month', customDays: 0 })
        .expect(200);

      const detail = await request(app.getHttpServer())
        .get(`/v1/staff/prescriptions/${freshRxId}`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .expect(200);
      expect(detail.body.doctor).toBe('Dr. Rao');
      expect(detail.body.duration).toBe('ONE_MONTH');

      await request(app.getHttpServer())
        .patch(`/v1/staff/prescriptions/${freshRxId}/details`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .send({ doctor: 'Dr. Rao', durationToken: 'not-a-real-duration', customDays: 0 })
        .expect(403);
    });

    it('pins the branch directly, overriding the fallback chain', async () => {
      const [storeB] = await db.select({ id: shieldStore.id }).from(shieldStore).where(eq(shieldStore.code, 'SHD-RXB'));
      await request(app.getHttpServer())
        .patch(`/v1/staff/prescriptions/${freshRxId}/branch`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .send({ storeId: storeB.id })
        .expect(200);

      // Store A can no longer reach it — it's pinned to B now.
      await request(app.getHttpServer())
        .get(`/v1/staff/prescriptions/${freshRxId}`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .expect(404);
      const asB = await request(app.getHttpServer())
        .get(`/v1/staff/prescriptions/${freshRxId}`)
        .set('Authorization', `Bearer ${storeBStaffToken}`)
        .expect(200);
      expect(asB.body.storeCode).toBe('SHD-RXB');

      // Clear the pin back to the fallback chain for the rest of this block.
      await request(app.getHttpServer())
        .patch(`/v1/staff/prescriptions/${freshRxId}/branch`)
        .set('Authorization', `Bearer ${storeBStaffToken}`)
        .send({ storeId: null })
        .expect(200);
    });

    it('rotates the legacy image (no prescription_image rows) under a legacy-<id> id', async () => {
      const [legacyRx] = await db
        .insert(prescription)
        .values({ memberId: (await db.select({ id: users.id }).from(users).where(eq(users.phone, '9000000002')))[0].id, patientId, code: 'RX-LEGACY-TEST', image: PNG_DATA_URI, imageRotation: 0 })
        .returning();

      const detail = await request(app.getHttpServer())
        .get(`/v1/staff/prescriptions/${legacyRx.id}`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .expect(200);
      expect(detail.body.images).toHaveLength(1);
      expect(detail.body.images[0].id).toBe(`legacy-${legacyRx.id}`);

      await request(app.getHttpServer())
        .patch(`/v1/staff/prescriptions/${legacyRx.id}/images/legacy-${legacyRx.id}/rotation`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .send({ rotation: 180 })
        .expect(200);

      const [row] = await db.select({ imageRotation: prescription.imageRotation }).from(prescription).where(eq(prescription.id, legacyRx.id));
      expect(row.imageRotation).toBe(180);
    });

    it('re-points the prescription at a different patient of the same member, refusing one that belongs to someone else', async () => {
      const [member] = await db.select({ id: users.id }).from(users).where(eq(users.phone, '9000000002'));
      const [ownPatient] = await db.insert(patient).values({ memberId: member.id, name: 'Spouse', dob: '1992-02-02', relation: 'SPOUSE' }).returning();

      const [otherMember] = await db.insert(users).values({ phone: '9000000099', name: 'Someone Else', firebaseUid: 'member-rx-other' }).returning();
      const [otherPatient] = await db.insert(patient).values({ memberId: otherMember.id, name: 'Not Mine', dob: '1990-01-01', relation: 'SELF' }).returning();

      await request(app.getHttpServer())
        .patch(`/v1/staff/prescriptions/${freshRxId}/patient`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .send({ patientId: otherPatient.id })
        .expect(403);

      await request(app.getHttpServer())
        .patch(`/v1/staff/prescriptions/${freshRxId}/patient`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .send({ patientId: ownPatient.id })
        .expect(200);

      const detail = await request(app.getHttpServer())
        .get(`/v1/staff/prescriptions/${freshRxId}`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .expect(200);
      expect(detail.body.patientName).toBe('Spouse');
    });

    it('admin-recovery: creates an order for a prescription that somehow has none, then bills against its intake', async () => {
      const created = await request(app.getHttpServer())
        .post(`/v1/staff/prescriptions/${freshRxId}/order`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .send({ fulfillmentType: 'STORE_PICKUP' })
        .expect(201);
      const orderId = created.body.id;

      const medicines = await request(app.getHttpServer())
        .get(`/v1/staff/orders/${orderId}/prescription-medicines`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .expect(200);
      expect(medicines.body).toEqual(expect.arrayContaining([expect.objectContaining({ name: 'Paracetamol' })]));

      // Store B has no claim on this order's prescription.
      await request(app.getHttpServer())
        .get(`/v1/staff/orders/${orderId}/prescription-medicines`)
        .set('Authorization', `Bearer ${storeBStaffToken}`)
        .expect(404);
    });

    it('changes fulfilment only while the order is still processing', async () => {
      const createdOrder = await request(app.getHttpServer())
        .post(`/v1/staff/prescriptions/${freshRxId}/order`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .send({ fulfillmentType: 'STORE_PICKUP' })
        .expect(201);
      const orderId = createdOrder.body.id;

      const whileProcessing = await request(app.getHttpServer())
        .patch(`/v1/staff/prescriptions/${freshRxId}/fulfillment`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .send({ fulfillmentType: 'HOME_DELIVERY' })
        .expect(200);
      expect(whileProcessing.body).toEqual({ changed: true });
      const [afterChange] = await db.select({ fulfillmentType: order.fulfillmentType }).from(order).where(eq(order.id, orderId));
      expect(afterChange.fulfillmentType).toBe('HOME_DELIVERY');

      await db.update(order).set({ status: 'DELIVERED' }).where(eq(order.id, orderId));
      const afterDelivered = await request(app.getHttpServer())
        .patch(`/v1/staff/prescriptions/${freshRxId}/fulfillment`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .send({ fulfillmentType: 'STORE_PICKUP' })
        .expect(200);
      expect(afterDelivered.body).toEqual({ changed: false }); // already delivered — nothing left to change
    });

    it('deletes without touching its order, unlike the member-facing delete', async () => {
      const [toDelete] = await db
        .insert(prescription)
        .values({ memberId: (await db.select({ id: users.id }).from(users).where(eq(users.phone, '9000000002')))[0].id, patientId, code: 'RX-DELETE-TEST' })
        .returning();

      await request(app.getHttpServer())
        .delete(`/v1/staff/prescriptions/${toDelete.id}`)
        .set('Authorization', `Bearer ${storeAStaffToken}`)
        .expect(200);

      const [row] = await db.select({ deletedAt: prescription.deletedAt }).from(prescription).where(eq(prescription.id, toDelete.id));
      expect(row.deletedAt).not.toBeNull();
    });
  });
});
