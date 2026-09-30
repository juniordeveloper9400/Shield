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
import { eq } from 'drizzle-orm';
import {
  adminUser,
  dietitian,
  labBill,
  labBookingReport,
  labCategory,
  labPackage,
  patient,
  shieldStore,
  users,
  wallet,
  walletEntry,
} from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('Care Services (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let memberAccessToken: string;
  let otherMemberAccessToken: string;
  let staffAccessToken: string;
  let labPackageId: number;
  let labCategoryId: number;
  let labStoreId: number;
  let nonLabStoreId: number;
  let dietitianId: number;
  let ownedPatientId: number;
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

    const [category] = await db
      .insert(labCategory)
      .values({ name: 'Diabetes', image: 'data:image/png;base64,abc' })
      .returning();
    labCategoryId = category.id;

    const [pkg] = await db
      .insert(labPackage)
      .values({ slug: 'full-body', name: 'Full Body Checkup', categoryId: labCategoryId, price: '999.00', mrp: '1499.00' })
      .returning();
    labPackageId = pkg.id;

    const [labStore] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-TIR', name: 'Tirur', area: 'Tirur', city: 'Malappuram', state: 'Kerala', pincode: '676101', isActive: true, offersLabCollection: true })
      .returning();
    labStoreId = labStore.id;
    const [notLabStore] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-KKT', name: 'Karinkallathani', area: 'Karinkallathani', city: 'Malappuram', state: 'Kerala', pincode: '676123', isActive: true, offersLabCollection: false })
      .returning();
    nonLabStoreId = notLabStore.id;

    // A test switched on with "Show in the app" is listed as its own one-profile row.
    await db
      .insert(labPackage)
      .values({ slug: 'hba1c', name: 'HbA1c', categoryId: labCategoryId, sourceTestId: 4242, price: '309.00', mrp: '500.00' });

    // Inactive: proves listLabCategories' testCount only tallies active packages.
    await db
      .insert(labPackage)
      .values({ slug: 'hidden-package', name: 'Hidden Package', categoryId: labCategoryId, isActive: false });

    const [diet] = await db.insert(dietitian).values({ name: 'Dr. Nutrition', fee: '500.00' }).returning();
    dietitianId = diet.id;

    const [member] = await db
      .insert(users)
      .values({ phone: '9000000004', name: 'Care Member', firebaseUid: 'member-care-1', registrationCompletedAt: new Date(), homeStoreId: labStoreId })
      .returning();
    memberId = member.id;
    firebase.register('member-token', { uid: 'member-care-1' });

    const [seededPatient] = await db
      .insert(patient)
      .values({ memberId: member.id, name: 'Self', dob: '1990-01-01', relation: 'SELF' })
      .returning();
    ownedPatientId = seededPatient.id;

    // LAB, not APPOINTMENTS: this token manages both lab bookings (now role-
    // gated, see staff-booking.controller.ts) and appointments (still open
    // to any staff role) below — LAB can do both; APPOINTMENTS could only
    // ever do the latter.
    await db.insert(adminUser).values({
      loginId: 'care-staff@example.com',
      name: 'Care Staff',
      passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
      role: 'LAB',
    });

    await db
      .insert(users)
      .values({ phone: '9000000005', name: 'Other Care Member', firebaseUid: 'member-care-2', registrationCompletedAt: new Date() });
    firebase.register('other-member-token', { uid: 'member-care-2' });

    memberAccessToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-token' }).expect(200)
    ).body.accessToken;
    otherMemberAccessToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'other-member-token' }).expect(200)
    ).body.accessToken;
    staffAccessToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'care-staff@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('lists lab packages, clinics, and dietitians publicly', async () => {
    const packages = await request(app.getHttpServer()).get('/v1/public/care/lab-packages').expect(200);
    expect(packages.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: labPackageId, categoryId: labCategoryId })]));
    // A real package carries no source test; a one-test listing does, which is how the apps tell them apart.
    expect(packages.body.find((p: { id: number }) => p.id === labPackageId).sourceTestId).toBeNull();
    expect(packages.body.find((p: { slug: string }) => p.slug === 'hba1c').sourceTestId).toBe(4242);

    const dietitians = await request(app.getHttpServer()).get('/v1/public/care/dietitians').expect(200);
    expect(dietitians.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: dietitianId })]));
  });

  it('lists lab categories publicly, each counting only its own active packages', async () => {
    const categories = await request(app.getHttpServer()).get('/v1/public/care/lab-categories').expect(200);
    const diabetes = categories.body.find((c: { id: number }) => c.id === labCategoryId);
    expect(diabetes).toEqual(
      expect.objectContaining({ name: 'Diabetes', image: 'data:image/png;base64,abc', testCount: 2 }),
    );
  });

  it('creates, updates, and soft-deletes a patient — the caller\'s own resource end to end', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/member/patients')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ name: 'Throwaway Patient', dob: '1990-01-01', abhaId: '12345678901234' })
      .expect(201);
    const throwawayId = created.body.id;
    expect(created.body.abhaId).toBe('12345678901234');

    const updated = await request(app.getHttpServer())
      .patch(`/v1/member/patients/${throwawayId}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ name: 'Renamed Patient' })
      .expect(200);
    expect(updated.body.name).toBe('Renamed Patient');
    expect(String(updated.body.dob)).toContain('1990-01-01'); // untouched fields survive a partial update
    expect(updated.body.abhaId).toBe('12345678901234'); // untouched by the partial update

    await request(app.getHttpServer())
      .patch(`/v1/member/patients/${ownedPatientId + 1000000}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ name: 'Nope' })
      .expect(404);

    await request(app.getHttpServer())
      .delete(`/v1/member/patients/${throwawayId}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(204);

    const list = await request(app.getHttpServer())
      .get('/v1/member/patients')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(list.body.map((p: { id: number }) => p.id)).not.toContain(throwawayId);

    // Deleted (or never-owned) patients are gone as far as further writes are concerned.
    await request(app.getHttpServer())
      .delete(`/v1/member/patients/${throwawayId}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(404);
  });

  it('rejects booking a lab test for a patient that is not the member\'s own', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/lab-bookings')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ labPackageId, patients: [{ patientId: 999999 }] })
      .expect(403);
  });

  it('lists lab-eligible branches publicly, and only the eligible one', async () => {
    const res = await request(app.getHttpServer()).get('/v1/public/care/lab-stores').expect(200);
    expect(res.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: labStoreId, code: 'SHD-TIR' })]));
    expect(res.body.map((s: { id: number }) => s.id)).not.toContain(nonLabStoreId);
  });

  let labBookingId: number;

  it('books a lab test for an owned patient plus a free-text patient, pricing server-side', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/lab-bookings')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ labPackageId, patients: [{ patientId: ownedPatientId }, { name: 'Grandma', age: 70 }] })
      .expect(201);

    labBookingId = res.body.id;
    expect(res.body.patientsCount).toBe(2);
    expect(Number(res.body.unitPrice)).toBe(999);
    expect(Number(res.body.totalPrice)).toBe(1998);
    // No storeId sent: it fell back to the member's own home branch.
    expect(res.body.storeId).toBe(labStoreId);

    const detail = await request(app.getHttpServer())
      .get(`/v1/member/lab-bookings/${labBookingId}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(detail.body.patients).toHaveLength(2);
  });

  it('enforces the lab booking state machine — no skipping straight to REPORT_READY', async () => {
    await request(app.getHttpServer())
      .patch(`/v1/staff/lab-bookings/${labBookingId}/status`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ status: 'REPORT_READY' })
      .expect(409);

    await request(app.getHttpServer())
      .patch(`/v1/staff/lab-bookings/${labBookingId}/status`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ status: 'CONFIRMED' })
      .expect(200);
  });

  it('lists the member bookings with the package name and a report page count of zero', async () => {
    const list = await request(app.getHttpServer())
      .get('/v1/member/lab-bookings')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(list.body).toEqual([
      expect.objectContaining({ id: labBookingId, packageName: 'Full Body Checkup', reportPages: 0 }),
    ]);
    // Never the pages themselves — they are fetched on demand.
    expect(JSON.stringify(list.body)).not.toContain('data:image');
  });

  it('books into a branch the member chose, refusing one not open for lab', async () => {
    const refused = await request(app.getHttpServer())
      .post('/v1/member/lab-bookings')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ labPackageId, patients: [{ name: 'Someone' }], storeId: nonLabStoreId })
      .expect(403);
    expect(refused.body.error.message).toContain('not open for lab');

    const [anotherStore] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-MEL', name: 'Melattur', area: 'Melattur', city: 'Malappuram', state: 'Kerala', pincode: '676102', isActive: true, offersLabCollection: true })
      .returning();
    const chosen = await request(app.getHttpServer())
      .post('/v1/member/lab-bookings')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ labPackageId, patients: [{ name: 'Someone' }], storeId: anotherStore.id })
      .expect(201);
    expect(chosen.body.storeId).toBe(anotherStore.id);
  });

  it('will not mark a booking Report ready until a report is attached, then shows it to its owner only', async () => {
    const setStatus = (status: string) =>
      request(app.getHttpServer())
        .patch(`/v1/staff/lab-bookings/${labBookingId}/status`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ status });

    await setStatus('SAMPLE_COLLECTED').expect(200);

    const refused = await setStatus('REPORT_READY').expect(409);
    expect(refused.body.error.code).toBe('REPORT_REQUIRED');

    await db.insert(labBookingReport).values([
      { labBookingId, name: 'page-2.jpg', image: 'data:image/jpeg;base64,BBBB', sort: 1 },
      { labBookingId, name: 'page-1.jpg', image: 'data:image/jpeg;base64,AAAA', sort: 0 },
    ]);
    await setStatus('REPORT_READY').expect(200);

    const report = await request(app.getHttpServer())
      .get(`/v1/member/lab-bookings/${labBookingId}/report`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(report.body.pages.map((p: { image: string }) => p.image)).toEqual([
      'data:image/jpeg;base64,AAAA',
      'data:image/jpeg;base64,BBBB',
    ]);

    const detail = await request(app.getHttpServer())
      .get(`/v1/member/lab-bookings/${labBookingId}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(detail.body).toEqual(expect.objectContaining({ packageName: 'Full Body Checkup', reportPages: 2 }));

    // Someone else's booking is simply not found — never leaked.
    await request(app.getHttpServer())
      .get(`/v1/member/lab-bookings/${labBookingId}/report`)
      .set('Authorization', `Bearer ${otherMemberAccessToken}`)
      .expect(404);
  });

  it('refuses to collect a lab bill that has not been sent yet', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/v1/staff/lab-bookings/${labBookingId}/collect-wallet`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .expect(200);
    expect(res.body).toEqual({ ok: false, reason: 'No bill has been sent for this booking yet.' });
  });

  it('prices a lab booking from its own package/patient count, then splits payment between wallet and cash under one OTP-gated collection', async () => {
    // The booking is 2 patients × ₹999 = ₹1998 (see the earlier booking
    // test) — a ₹98 discount prices the bill at ₹1900, entirely server-side:
    // nothing here ever sends an amount.
    const sent = await request(app.getHttpServer())
      .put(`/v1/staff/lab-bookings/${labBookingId}/bill`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ image: '', discountAmount: 98 })
      .expect(200);
    expect(Number(sent.body.amount)).toBe(1900);
    expect(sent.body.status).toBe('PENDING');

    // A wallet with less than the bill owes covers what it can; the rest is
    // cash — same split rule as order.service.ts's collectBillWithWallet.
    await db.insert(wallet).values({ memberId, balance: '500.00' });

    const collected = await request(app.getHttpServer())
      .patch(`/v1/staff/lab-bookings/${labBookingId}/collect-wallet`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .expect(200);
    expect(collected.body).toEqual({ ok: true, walletAmount: 500, cashAmount: 1400 });

    const [theWallet] = await db.select().from(wallet).where(eq(wallet.memberId, memberId));
    expect(Number(theWallet.balance)).toBe(0);

    const entries = await db.select().from(walletEntry).where(eq(walletEntry.walletId, theWallet.id));
    expect(entries).toHaveLength(1);
    expect(entries[0].kind).toBe('SPEND');
    expect(Number(entries[0].amount)).toBe(-500);
    expect(entries[0].labBookingId).toBe(labBookingId);

    const [theBill] = await db.select().from(labBill).where(eq(labBill.labBookingId, labBookingId));
    expect(theBill.status).toBe('PAID');
    expect(Number(theBill.walletCollected)).toBe(500);
    expect(Number(theBill.cashCollected)).toBe(1400);

    // Collecting again is refused, the same as an order's already-paid bill.
    const again = await request(app.getHttpServer())
      .patch(`/v1/staff/lab-bookings/${labBookingId}/collect-wallet`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .expect(200);
    expect(again.body).toEqual({ ok: false, reason: 'This bill is already paid.' });
  });

  it("a store's own LAB_TECHNICIAN sees and manages only that store's bookings, in full detail", async () => {
    const [otherStore] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-PON', name: 'Ponnani', area: 'Ponnani', city: 'Malappuram', state: 'Kerala', pincode: '679577', isActive: true, offersLabCollection: true })
      .returning();

    await db.insert(adminUser).values([
      { loginId: 'lab-tech-tirur@example.com', name: 'Tirur Lab Tech', passwordHash: await hash('correct-horse-battery-staple', 4), role: 'LAB_TECHNICIAN', storeId: labStoreId },
      { loginId: 'lab-tech-ponnani@example.com', name: 'Ponnani Lab Tech', passwordHash: await hash('correct-horse-battery-staple', 4), role: 'LAB_TECHNICIAN', storeId: otherStore.id },
      { loginId: 'pharmacy-tirur@example.com', name: 'Tirur Pharmacy', passwordHash: await hash('correct-horse-battery-staple', 4), role: 'PHARMACY', storeId: labStoreId },
    ]);
    const tirurToken = (
      await request(app.getHttpServer()).post('/v1/staff/auth/session').send({ loginId: 'lab-tech-tirur@example.com', password: 'correct-horse-battery-staple' }).expect(200)
    ).body.accessToken;
    const ponnaniToken = (
      await request(app.getHttpServer()).post('/v1/staff/auth/session').send({ loginId: 'lab-tech-ponnani@example.com', password: 'correct-horse-battery-staple' }).expect(200)
    ).body.accessToken;
    const pharmacyToken = (
      await request(app.getHttpServer()).post('/v1/staff/auth/session').send({ loginId: 'pharmacy-tirur@example.com', password: 'correct-horse-battery-staple' }).expect(200)
    ).body.accessToken;

    // labBookingId was routed to labStoreId (Tirur, the member's home
    // branch) back when it was first booked.
    const tirurList = await request(app.getHttpServer())
      .get('/v1/staff/lab-bookings')
      .set('Authorization', `Bearer ${tirurToken}`)
      .expect(200);
    expect(tirurList.body).toEqual(
      expect.arrayContaining([expect.objectContaining({ id: labBookingId, storeCode: 'SHD-TIR' })]),
    );

    // Ponnani's own lab technician has no bookings of their own yet — not
    // Tirur's, which is what an unscoped list would otherwise have leaked.
    const ponnaniList = await request(app.getHttpServer())
      .get('/v1/staff/lab-bookings')
      .set('Authorization', `Bearer ${ponnaniToken}`)
      .expect(200);
    expect(ponnaniList.body.map((b: { id: number }) => b.id)).not.toContain(labBookingId);

    // Nor can Ponnani's technician reach into Tirur's booking directly.
    await request(app.getHttpServer())
      .patch(`/v1/staff/lab-bookings/${labBookingId}/status`)
      .set('Authorization', `Bearer ${ponnaniToken}`)
      .send({ status: 'CANCELLED' })
      .expect(404);

    // The store's own PHARMACY admin — same branch as the booking — still
    // has no business on this API surface at all; they see lab orders
    // through shieldweb's own redacted, read-only view instead.
    await request(app.getHttpServer())
      .get('/v1/staff/lab-bookings')
      .set('Authorization', `Bearer ${pharmacyToken}`)
      .expect(403);
  });

  it('auto-populates fee from the dietitian record for a DIETITIAN appointment', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/appointments')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ kind: 'DIETITIAN', dietitianId, patientId: ownedPatientId })
      .expect(201);

    expect(Number(res.body.fee)).toBe(500);
  });

  it('does not auto-populate fee for a CLINIC appointment (clinic_doctor.fee is free-text in the schema)', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/appointments')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ kind: 'CLINIC', doctorName: 'Dr. Smith' })
      .expect(201);

    expect(res.body.fee).toBeNull();
  });

  it('rejects booking an appointment for a patient that is not the member\'s own', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/appointments')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ kind: 'CLINIC', patientId: 999999 })
      .expect(403);
  });

  it('enforces the appointment state machine — a completed appointment cannot be reopened', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/member/appointments')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ kind: 'TELE' })
      .expect(201);
    const id = created.body.id;

    await request(app.getHttpServer())
      .patch(`/v1/staff/appointments/${id}/status`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ status: 'CONFIRMED' })
      .expect(200);
    await request(app.getHttpServer())
      .patch(`/v1/staff/appointments/${id}/status`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ status: 'COMPLETED' })
      .expect(200);
    await request(app.getHttpServer())
      .patch(`/v1/staff/appointments/${id}/status`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ status: 'CANCELLED' })
      .expect(409);
  });
});
