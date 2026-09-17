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
import { adminUser, patient, shieldStore, users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

// A real (tiny, valid) 1x1 transparent PNG.
const PNG_DATA_URI =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

describe('Prescription (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let memberAccessToken: string;
  let storeAStaffToken: string;
  let storeBStaffToken: string;
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
      .values({ phone: '9000000002', name: 'Rx Member', firebaseUid: 'member-rx-1', homeStoreId: storeA.id })
      .returning();
    firebase.register('member-token', { uid: 'member-rx-1' });

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

    memberAccessToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-token' }).expect(200)
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
});
