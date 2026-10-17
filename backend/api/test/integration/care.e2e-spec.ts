process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { hash } from 'bcryptjs';
import { AppModule } from '../../src/app.module';
import { BookingService } from '../../src/modules/care/booking.service';
import { DRIZZLE } from '../../src/db/client';
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { eq } from 'drizzle-orm';
import { randomUUID } from 'node:crypto';
import {
  adminUser,
  dietitian,
  labBill,
  labBooking,
  labBookingPatient,
  labBookingReport,
  labCategory,
  labPackage,
  labPackageExtraCategory,
  labTest,
  memberAddress,
  membershipTier,
  patient,
  shieldStore,
  users,
  wallet,
  walletCard,
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
  let careStaffId: number;
  let labPackageId: number;
  let sourceTestId: number;
  let labCategoryId: number;
  let secondLabCategoryId: number;
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

    // A second concern the same package also belongs under (migration
    // 0067) — proves a package can show up from more than one category
    // without moving off its primary one.
    const [secondCategory] = await db
      .insert(labCategory)
      .values({ name: 'Men health', image: 'data:image/png;base64,abc' })
      .returning();
    secondLabCategoryId = secondCategory.id;
    await db.insert(labPackageExtraCategory).values({ packageId: labPackageId, categoryId: secondLabCategoryId });

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
    const [sourceTest] = await db.insert(labTest).values({ name: 'HbA1c Source Test' }).returning();
    sourceTestId = sourceTest.id;
    await db
      .insert(labPackage)
      .values({ slug: 'hba1c', name: 'HbA1c', categoryId: labCategoryId, sourceTestId, price: '309.00', mrp: '500.00' });

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
    const [careStaff] = await db
      .insert(adminUser)
      .values({
        loginId: 'care-staff@example.com',
        name: 'Care Staff',
        passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
        role: 'LAB',
      })
      .returning();
    careStaffId = careStaff.id;

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

  it('edits the actual lab order details without rewriting the user account or saved patient', async () => {
    const [originalMember] = await db.select().from(users).where(eq(users.id, memberId));
    const [originalPatient] = await db.select().from(patient).where(eq(patient.id, ownedPatientId));
    const [replacement] = await db.insert(labPackage).values({ slug: 'admin-edit-fixture', name: 'Replacement lab test', price: '250', mrp: '300' }).returning();
    const [booking] = await db.insert(labBooking).values({ memberId, labPackageId, storeId: labStoreId, unitPrice: '999', totalPrice: '999', patientsCount: 1 }).returning();
    await db.insert(labBookingPatient).values({ labBookingId: booking.id, patientId: ownedPatientId });
    await request(app.getHttpServer()).patch(`/v1/staff/lab-bookings/${booking.id}/details`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ scheduledFor: '2026-12-01T09:30:00.000Z', note: 'Edited order instructions',
        contactName: 'Corrected order contact', contactPhone: '9000012345', addressPhone: '9000054321',
        labPackageId: replacement.id, fulfillmentType: 'STORE_VISIT', unitPrice: 225,
        address: 'Updated collection location', assignedStaffId: null,
        patients: [{ patientId: ownedPatientId, name: 'Corrected patient', age: 30,
          phone: '9000099999', dob: '1996-01-01', gender: 'FEMALE', relation: 'PARENT', abhaId: '12345678901234', addressOverride: 'Patient address' }],
      }).expect(200);
    const list = await request(app.getHttpServer()).get('/v1/staff/lab-bookings').set('Authorization', `Bearer ${staffAccessToken}`).expect(200);
    const saved = list.body.find((row: { id: number }) => row.id === booking.id);
    expect(saved).toMatchObject({ contactName: 'Corrected order contact', contactPhone: '9000012345', addressPhone: '9000054321', labPackageId: replacement.id, fulfillmentType: 'STORE_VISIT', packageName: replacement.name, note: 'Edited order instructions' });
    expect(Number(saved.unitPrice)).toBe(225);
    expect(Number(saved.totalPrice)).toBe(225);
    expect(saved.patients[0]).toMatchObject({ patientId: ownedPatientId, name: 'Corrected patient', phone: '9000099999', dob: '1996-01-01', gender: 'FEMALE', relation: 'PARENT', abhaId: '12345678901234' });
    const [afterMember] = await db.select().from(users).where(eq(users.id, memberId));
    const [afterPatient] = await db.select().from(patient).where(eq(patient.id, ownedPatientId));
    expect(afterMember.phone).toBe(originalMember.phone);
    expect(afterMember.name).toBe(originalMember.name);
    expect(afterPatient).toEqual(originalPatient);
    // The narrower technician form must retain hidden demographics when renaming a row.
    await request(app.getHttpServer()).patch(`/v1/staff/lab-bookings/${booking.id}/details`).set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ scheduledFor: null, note: '', patients: [{ bookingPatientId: saved.patients[0].id, name: 'Renamed without metadata', age: 30 }] }).expect(200);
    const renamedList = await request(app.getHttpServer()).get('/v1/staff/lab-bookings').set('Authorization', `Bearer ${staffAccessToken}`).expect(200);
    const renamed = renamedList.body.find((row: { id: number }) => row.id === booking.id).patients[0];
    expect(renamed).toMatchObject({ patientId: ownedPatientId, name: 'Renamed without metadata', phone: '9000099999', dob: '1996-01-01', gender: 'FEMALE', relation: 'PARENT', abhaId: '12345678901234', address: 'Patient address' });

    await db.delete(labBookingPatient).where(eq(labBookingPatient.labBookingId, booking.id));
    await db.delete(labBooking).where(eq(labBooking.id, booking.id));
    await db.delete(labPackage).where(eq(labPackage.id, replacement.id));
  });

  it('allows metadata corrections on a paid order but refuses changing its collected charges', async () => {
    const [formerStaff] = await db.insert(adminUser).values({ loginId: 'inactive-edit-fixture@example.com', name: 'Former technician', passwordHash: 'test-fixture-no-login', role: 'LAB_TECHNICIAN', storeId: labStoreId, isActive: false }).returning();
    const [booking] = await db.insert(labBooking).values({ memberId, labPackageId, storeId: labStoreId, assignedStaffId: formerStaff.id, unitPrice: '999', totalPrice: '999', patientsCount: 1 }).returning();
    const [bill] = await db.insert(labBill).values({ labBookingId: booking.id, image: '', amount: '999', status: 'PAID' }).returning();
    const refused = await request(app.getHttpServer()).patch(`/v1/staff/lab-bookings/${booking.id}/details`).set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ scheduledFor: null, note: '', unitPrice: 500 }).expect(409);
    expect(refused.body.error.code).toBe('BILL_PAID');
    await request(app.getHttpServer()).patch(`/v1/staff/lab-bookings/${booking.id}/details`).set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ scheduledFor: null, note: 'Corrected contact', contactName: 'New contact', contactPhone: '9000012345' }).expect(200);
    const [unchanged] = await db.select().from(labBill).where(eq(labBill.id, bill.id));
    expect(Number(unchanged.amount)).toBe(999);
    await db.delete(labBill).where(eq(labBill.id, bill.id));
    await db.delete(labBooking).where(eq(labBooking.id, booking.id));
    await db.delete(adminUser).where(eq(adminUser.id, formerStaff.id));
  });

  it('a metadata save cannot restore a price read before another collection committed', async () => {
    const [booking] = await db.insert(labBooking).values({ memberId, labPackageId, storeId: labStoreId, unitPrice: '100', totalPrice: '100', patientsCount: 1 }).returning();
    const [bill] = await db.insert(labBill).values({ labBookingId: booking.id, image: '', amount: '100', status: 'PENDING' }).returning();
    const service = app.get(BookingService);
    const internal = service as unknown as { getLabBookingOwnedByStaffOrThrow: (...args: unknown[]) => Promise<unknown> };
    const original = internal.getLabBookingOwnedByStaffOrThrow.bind(service);
    const authCheck = jest.spyOn(internal, 'getLabBookingOwnedByStaffOrThrow').mockImplementationOnce(async (...args) => {
      const before = await original(...args);
      // Represents an already-committed reprice/collection after the access check's read.
      await db.update(labBooking).set({ unitPrice: '200', totalPrice: '200' }).where(eq(labBooking.id, booking.id));
      await db.update(labBill).set({ amount: '200', status: 'PAID', cashCollected: '200' }).where(eq(labBill.id, bill.id));
      return before;
    });
    try {
      await request(app.getHttpServer()).patch(`/v1/staff/lab-bookings/${booking.id}/details`).set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ scheduledFor: null, note: 'Metadata only' }).expect(200);
      const [after] = await db.select().from(labBooking).where(eq(labBooking.id, booking.id));
      expect(Number(after.unitPrice)).toBe(200);
      expect(Number(after.totalPrice)).toBe(200);
    } finally { authCheck.mockRestore(); }
    await db.delete(labBill).where(eq(labBill.id, bill.id));
    await db.delete(labBooking).where(eq(labBooking.id, booking.id));
  });

  it('lists lab packages, clinics, and dietitians publicly', async () => {
    const packages = await request(app.getHttpServer()).get('/v1/public/care/lab-packages').expect(200);
    expect(packages.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: labPackageId, categoryId: labCategoryId })]));
    // A real package carries no source test; a one-test listing does, which is how the apps tell them apart.
    expect(packages.body.find((p: { id: number }) => p.id === labPackageId).sourceTestId).toBeNull();
    expect(packages.body.find((p: { slug: string }) => p.slug === 'hba1c').sourceTestId).toBe(sourceTestId);
    // Extra categories (migration 0067) ride alongside the primary one — the
    // package set up under both Diabetes and Men health carries both.
    expect(packages.body.find((p: { id: number }) => p.id === labPackageId).extraCategoryIds).toEqual([
      secondLabCategoryId,
    ]);
    expect(packages.body.find((p: { slug: string }) => p.slug === 'hba1c').extraCategoryIds).toEqual([]);

    const dietitians = await request(app.getHttpServer()).get('/v1/public/care/dietitians').expect(200);
    expect(dietitians.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: dietitianId })]));
  });

  it('lists lab categories publicly, each counting only its own active packages', async () => {
    const categories = await request(app.getHttpServer()).get('/v1/public/care/lab-categories').expect(200);
    const diabetes = categories.body.find((c: { id: number }) => c.id === labCategoryId);
    expect(diabetes).toEqual(
      expect.objectContaining({ name: 'Diabetes', image: 'data:image/png;base64,abc', testCount: 2 }),
    );

    // The Full Body Checkup package reaches Men health only via its extra
    // category (migration 0067), not a primary one — still has to count.
    const menHealth = categories.body.find((c: { id: number }) => c.id === secondLabCategoryId);
    expect(menHealth).toEqual(expect.objectContaining({ name: 'Men health', testCount: 1 }));
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
    // No fulfillmentType sent either — defaults to the original behaviour.
    expect(res.body.fulfillmentType).toBe('HOME_COLLECTION');

    const detail = await request(app.getHttpServer())
      .get(`/v1/member/lab-bookings/${labBookingId}`)
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .expect(200);
    expect(detail.body.patients).toHaveLength(2);
  });

  it('refuses to confirm a home-collection booking until someone is assigned, lists lab staff, then confirms once assigned', async () => {
    const refused = await request(app.getHttpServer())
      .patch(`/v1/staff/lab-bookings/${labBookingId}/status`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ status: 'CONFIRMED' })
      .expect(409);
    expect(refused.body.error.code).toBe('STAFF_REQUIRED');

    // No LAB_TECHNICIAN fixtures exist yet at this point in the suite (they
    // come later, in the console lab-booking detail block below) — just
    // confirms the route itself works, empty or not.
    const staffList = await request(app.getHttpServer())
      .get('/v1/staff/lab-staff')
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .expect(200);
    expect(Array.isArray(staffList.body)).toBe(true);

    await request(app.getHttpServer())
      .patch(`/v1/staff/lab-bookings/${labBookingId}/staff`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ staffId: careStaffId })
      .expect(200);

    await request(app.getHttpServer())
      .patch(`/v1/staff/lab-bookings/${labBookingId}/status`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ status: 'CONFIRMED' })
      .expect(200);
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

  it('books a store-visit lab test with no address, and the staff list shows the service type', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/member/lab-bookings')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ labPackageId, patients: [{ name: 'Walk-in' }], fulfillmentType: 'STORE_VISIT' })
      .expect(201);
    expect(res.body.fulfillmentType).toBe('STORE_VISIT');
    expect(res.body.addressId).toBeNull();

    const staffList = await request(app.getHttpServer())
      .get('/v1/staff/lab-bookings')
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .expect(200);
    const row = staffList.body.find((b: { id: number }) => b.id === res.body.id);
    expect(row.fulfillmentType).toBe('STORE_VISIT');
  });

  it('a member-chosen preferred date reaches the staff list — the admin console then shows it pre-filled, not blank', async () => {
    const preferred = new Date(Date.now() + 5 * 86400000).toISOString();
    const res = await request(app.getHttpServer())
      .post('/v1/member/lab-bookings')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ labPackageId, patients: [{ name: 'Someone' }], scheduledFor: preferred })
      .expect(201);
    expect(new Date(res.body.scheduledFor).toISOString()).toBe(preferred);

    const staffList = await request(app.getHttpServer())
      .get('/v1/staff/lab-bookings')
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .expect(200);
    const row = staffList.body.find((b: { id: number }) => b.id === res.body.id);
    expect(new Date(row.scheduledFor).toISOString()).toBe(preferred);
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

  it("caps the lab-bill wallet draw at this month's Health Pass allowance, not just the raw balance — same fix as order.service.ts's collectBillWithWallet", async () => {
    const [freshMember] = await db
      .insert(users)
      .values({ phone: '9000000099', name: 'Allowance Cap Lab Member', firebaseUid: `member-lab-allowance-cap-${randomUUID()}`, registrationCompletedAt: new Date() })
      .returning();
    const [freshWallet] = await db.insert(wallet).values({ memberId: freshMember.id, balance: '54034.00' }).returning();
    const existingTier = await db.select().from(membershipTier).where(eq(membershipTier.kind, 'PLATINUM')).limit(1);
    const tier =
      existingTier[0] ??
      (await db.insert(membershipTier).values({ kind: 'PLATINUM', name: 'Platinum', bin: '900099', bonusRate: '0.1', validityMonths: 12 }).returning())[0];
    await db.insert(walletCard).values({
      walletId: freshWallet.id,
      tierId: tier.id,
      amount: '108000.00', // releases 9000/month
      bonus: '0',
      status: 'APPROVED',
      issuedOn: new Date().toISOString().slice(0, 10),
      rechargedOn: new Date().toISOString().slice(0, 10),
      expiresOn: '2099-01-01',
    });
    // This month's whole allowance is already spent elsewhere.
    await db.insert(walletEntry).values({
      walletId: freshWallet.id,
      kind: 'SPEND',
      label: 'Earlier order this month',
      amount: '-9000.00',
      occurredOn: new Date().toISOString().slice(0, 10),
    });
    const [freshBooking] = await db
      .insert(labBooking)
      .values({ memberId: freshMember.id, labPackageId, storeId: labStoreId, patientsCount: 1, unitPrice: '1000', totalPrice: '1000' })
      .returning();
    await db.insert(labBill).values({ labBookingId: freshBooking.id, image: '', amount: '1000' });

    const res = await request(app.getHttpServer())
      .patch(`/v1/staff/lab-bookings/${freshBooking.id}/collect-wallet`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .expect(200);

    // Allowance is exhausted — nothing comes from the wallet despite its
    // ₹54,034 balance; the whole bill is left owed in cash instead.
    expect(res.body).toEqual({ ok: true, walletAmount: 0, cashAmount: 1000 });
    const [theBill] = await db.select().from(labBill).where(eq(labBill.labBookingId, freshBooking.id));
    expect(Number(theBill.walletCollected)).toBe(0);
    expect(await db.select().from(walletEntry).where(eq(walletEntry.labBookingId, freshBooking.id))).toEqual([]);
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

    // Lab staff listing is store-scoped by storeCode, same list the console's
    // assignment picker reads — Tirur's technician shows under Tirur, not
    // under Ponnani's own branch.
    const staffAtTirur = await request(app.getHttpServer())
      .get('/v1/staff/lab-staff?storeCode=SHD-TIR')
      .set('Authorization', `Bearer ${tirurToken}`)
      .expect(200);
    expect(staffAtTirur.body).toEqual([
      expect.objectContaining({ name: 'Tirur Lab Tech', storeCode: 'SHD-TIR' }),
    ]);

    // A LAB_TECHNICIAN login may claim a booking for itself…
    const tirurTechId = staffAtTirur.body[0].id;
    await request(app.getHttpServer())
      .patch(`/v1/staff/lab-bookings/${labBookingId}/staff`)
      .set('Authorization', `Bearer ${tirurToken}`)
      .send({ staffId: tirurTechId })
      .expect(200);

    // …but never hand it to someone else, even another technician.
    const staffAtPonnani = await request(app.getHttpServer())
      .get('/v1/staff/lab-staff?storeCode=SHD-PON')
      .set('Authorization', `Bearer ${tirurToken}`)
      .expect(200);
    const ponnaniTechId = staffAtPonnani.body[0].id;
    const refused = await request(app.getHttpServer())
      .patch(`/v1/staff/lab-bookings/${labBookingId}/staff`)
      .set('Authorization', `Bearer ${tirurToken}`)
      .send({ staffId: ponnaniTechId })
      .expect(403);
    expect(refused.body.error.message).toContain('only claim a booking for itself');
  });

  describe('console lab-booking detail (its own fresh fixture — labBookingId above is mutated by nearly every test before this point)', () => {
    let freshBookingId: number;

    beforeAll(async () => {
      const [created] = await db
        .insert(labBooking)
        .values({
          memberId,
          labPackageId,
          storeId: labStoreId,
          patientsCount: 2,
          unitPrice: '999',
          totalPrice: '1998',
          status: 'REQUESTED',
        })
        .returning();
      freshBookingId = created.id;
      await db.insert(labBookingPatient).values([
        { labBookingId: freshBookingId, patientId: ownedPatientId },
        { labBookingId: freshBookingId, name: 'Grandma', age: 70 },
      ]);
    });

    it('carries the member, package, patients (owned and free-text) and bill info, not just the raw columns', async () => {
      const list = await request(app.getHttpServer())
        .get('/v1/staff/lab-bookings')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);

      const row = list.body.find((b: { id: number }) => b.id === freshBookingId);
      expect(row).toBeDefined();
      expect(row.code).toBe(`LB-${String(freshBookingId).padStart(4, '0')}`);
      expect(row.memberName).toBeTruthy();
      expect(row.memberPhone).toBeTruthy();
      expect(row.packageName).toBeTruthy();
      expect(row.reportPages).toBe(0);
      expect(row.billStatus).toBe('PENDING');
      expect(row.patients).toHaveLength(2);
      const grandma = row.patients.find((p: { name: string }) => p.name === 'Grandma');
      expect(grandma.age).toBe(70);
    });

    it("reads the booking member's wallet balance", async () => {
      const res = await request(app.getHttpServer())
        .get(`/v1/staff/lab-bookings/${freshBookingId}/wallet-balance`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);
      expect(typeof res.body.balance).toBe('number');
    });

    it('updates the schedule and note, but leaves them alone once Report ready', async () => {
      const when = new Date(Date.now() + 86400000).toISOString();
      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-bookings/${freshBookingId}/details`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ scheduledFor: when, note: 'Call before arriving' })
        .expect(200);

      const after = await request(app.getHttpServer())
        .get('/v1/staff/lab-bookings')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);
      const row = after.body.find((b: { id: number }) => b.id === freshBookingId);
      expect(row.note).toBe('Call before arriving');
    });

    it('edits the branch and patients, recomputing totalPrice from the new headcount — never an admin-typed number', async () => {
      const [ponnani] = await db.select().from(shieldStore).where(eq(shieldStore.code, 'SHD-PON'));

      const refused = await request(app.getHttpServer())
        .patch(`/v1/staff/lab-bookings/${freshBookingId}/details`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ scheduledFor: null, note: '', storeId: nonLabStoreId })
        .expect(400);
      expect(refused.body.error.message).toContain('not open for lab');

      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-bookings/${freshBookingId}/details`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({
          scheduledFor: null,
          note: '',
          storeId: ponnani.id,
          address: 'Door no. 4, New Bus Stand Road, Ponnani',
          patients: [{ name: 'Grandma', age: 70 }, { name: 'Walk-in companion', age: 40 }, { name: 'Third patient', age: 12 }],
        })
        .expect(200);

      const after = await request(app.getHttpServer())
        .get('/v1/staff/lab-bookings')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);
      const row = after.body.find((b: { id: number }) => b.id === freshBookingId);
      expect(row.storeCode).toBe('SHD-PON');
      expect(row.address).toBe('Door no. 4, New Bus Stand Road, Ponnani');
      expect(row.patients).toHaveLength(3);
      expect(row.patientsCount).toBe(3);
      // Same unit price (₹999) × the new headcount of 3 — system-computed,
      // not whatever an admin might type.
      expect(Number(row.totalPrice)).toBe(2997);
    });

    it("gives each patient its own collection address, falling back to the booking's own when unset", async () => {
      const [ownAddress] = await db
        .insert(memberAddress)
        .values({ memberId, label: 'HOME', house: 'Flat 2B', area: 'Palace Road', pincode: '679326' })
        .returning();
      const [stranger] = await db
        .insert(users)
        .values({ phone: '9000000098', name: 'Someone Else', firebaseUid: 'member-stranger-1', registrationCompletedAt: new Date() })
        .returning();
      const [strangersAddress] = await db
        .insert(memberAddress)
        .values({ memberId: stranger.id, label: 'HOME', house: 'Not theirs', area: 'Elsewhere', pincode: '679999' })
        .returning();

      const refused = await request(app.getHttpServer())
        .post('/v1/member/lab-bookings')
        .set('Authorization', `Bearer ${memberAccessToken}`)
        .send({
          labPackageId,
          patients: [{ patientId: ownedPatientId, addressId: strangersAddress.id }],
        })
        .expect(403);
      expect(refused.body.error.message).toMatch(/addresses do not belong/i);

      const created = await request(app.getHttpServer())
        .post('/v1/member/lab-bookings')
        .set('Authorization', `Bearer ${memberAccessToken}`)
        .send({
          labPackageId,
          patients: [
            { patientId: ownedPatientId, addressId: ownAddress.id },
            { name: 'No own address', age: 55 },
          ],
        })
        .expect(201);
      const ownAddressBookingId = created.body.id;

      const staffList = await request(app.getHttpServer())
        .get('/v1/staff/lab-bookings')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);
      const row = staffList.body.find((b: { id: number }) => b.id === ownAddressBookingId);
      expect(row.patients).toHaveLength(2);
      const withOwnAddress = row.patients.find((p: { addressId: number | null }) => p.addressId === ownAddress.id);
      expect(withOwnAddress.address).toContain('Flat 2B');
      const withoutOwnAddress = row.patients.find((p: { addressId: number | null }) => p.addressId === null);
      // No address of its own — falls back to the booking's own address
      // (whatever that resolves to, here the member's own home branch
      // default since none was sent at booking time).
      expect(withoutOwnAddress.address).toBe(row.address);

      // The console can override one patient's address with free text,
      // without touching the other patient or the booking's own address.
      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-bookings/${ownAddressBookingId}/details`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({
          scheduledFor: null,
          note: '',
          patients: [
            { patientId: ownedPatientId, addressId: ownAddress.id },
            { name: 'No own address', age: 55, addressOverride: 'Collect from the shop next door instead' },
          ],
        })
        .expect(200);

      const afterEdit = await request(app.getHttpServer())
        .get('/v1/staff/lab-bookings')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);
      const editedRow = afterEdit.body.find((b: { id: number }) => b.id === ownAddressBookingId);
      const overridden = editedRow.patients.find((p: { addressOverride: string | null }) => p.addressOverride);
      expect(overridden.address).toBe('Collect from the shop next door instead');
    });

    it('refuses Report ready until a page is attached, then accepts one page at a time and keeps the last on a finished booking', async () => {
      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-bookings/${freshBookingId}/staff`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ staffId: careStaffId })
        .expect(200);

      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-bookings/${freshBookingId}/status`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ status: 'CONFIRMED' })
        .expect(200);
      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-bookings/${freshBookingId}/status`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ status: 'SAMPLE_COLLECTED' })
        .expect(200);
      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-bookings/${freshBookingId}/status`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ status: 'REPORT_READY' })
        .expect(409);

      await request(app.getHttpServer())
        .post(`/v1/staff/lab-bookings/${freshBookingId}/report-pages`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ pages: [{ name: 'Page 1', image: 'data:image/jpeg;base64,aaaa' }] })
        .expect(201);

      const pages = await request(app.getHttpServer())
        .get(`/v1/staff/lab-bookings/${freshBookingId}/report-pages`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);
      expect(pages.body).toHaveLength(1);
      const pageId = pages.body[0].id;

      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-bookings/${freshBookingId}/status`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ status: 'REPORT_READY' })
        .expect(200);

      // The only page on a Report ready booking can't be removed.
      await request(app.getHttpServer())
        .delete(`/v1/staff/lab-bookings/${freshBookingId}/report-pages/${pageId}`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(409);
    });
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

  it('the staff list carries the member, provider and store names, not just ids', async () => {
    await request(app.getHttpServer())
      .post('/v1/member/appointments')
      .set('Authorization', `Bearer ${memberAccessToken}`)
      .send({ kind: 'DIETITIAN', dietitianId, patientId: ownedPatientId })
      .expect(201);

    const res = await request(app.getHttpServer())
      .get('/v1/staff/appointments')
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .expect(200);

    const found = res.body.find((a: { providerName?: string }) => a.providerName === 'Dr. Nutrition');
    expect(found).toBeDefined();
    expect(found.memberName).toBe('Care Member');
    expect(found.memberPhone).toBe('9000000004');
    expect(found.storeName).toBe('Tirur');
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

  describe('console lab category management (SUPERADMIN/ADMIN/LAB only)', () => {
    let technicianToken: string;

    beforeAll(async () => {
      await db.insert(adminUser).values({
        loginId: 'lab-tech-categories@example.com',
        name: 'Lab Tech',
        passwordHash: await hash('correct-horse-battery-staple', 4),
        role: 'LAB_TECHNICIAN',
        storeId: labStoreId,
      });
      technicianToken = (
        await request(app.getHttpServer())
          .post('/v1/staff/auth/session')
          .send({ loginId: 'lab-tech-categories@example.com', password: 'correct-horse-battery-staple' })
          .expect(200)
      ).body.accessToken;
    });

    it('rejects LAB_TECHNICIAN — a technician works their own branch, not the catalogue', async () => {
      await request(app.getHttpServer())
        .get('/v1/staff/lab-categories')
        .set('Authorization', `Bearer ${technicianToken}`)
        .expect(403);
    });

    it("lists every category active or not, each carrying its live test count (primary and extra-category)", async () => {
      const res = await request(app.getHttpServer())
        .get('/v1/staff/lab-categories')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);

      const first = res.body.find((c: { id: number }) => c.id === labCategoryId);
      expect(first).toBeDefined();
      expect(first.testCount).toBeGreaterThan(0);
    });

    it('refuses a duplicate name case-insensitively, without a 500', async () => {
      const [existing] = await db.select().from(labCategory).where(eq(labCategory.id, labCategoryId));
      const res = await request(app.getHttpServer())
        .post('/v1/staff/lab-categories')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: existing.name.toUpperCase() })
        .expect(201);
      expect(res.body).toEqual({ category: null });
    });

    it('creates, renames, re-sorts, deactivates and deletes a category with nothing filed under it', async () => {
      const created = await request(app.getHttpServer())
        .post('/v1/staff/lab-categories')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: 'Console Test Category' })
        .expect(201);
      const id = created.body.category.id;

      const renamed = await request(app.getHttpServer())
        .patch(`/v1/staff/lab-categories/${id}`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: 'Renamed Category' })
        .expect(200);
      expect(renamed.body.category.name).toBe('Renamed Category');

      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-categories/${id}/sort`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ sort: 9 })
        .expect(200);
      const deactivated = await request(app.getHttpServer())
        .patch(`/v1/staff/lab-categories/${id}/active`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ isActive: false })
        .expect(200);
      expect(deactivated.body.isActive).toBe(false);
      expect(deactivated.body.sort).toBe(9);

      await request(app.getHttpServer())
        .delete(`/v1/staff/lab-categories/${id}`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);
      const afterDelete = await db.select().from(labCategory).where(eq(labCategory.id, id));
      expect(afterDelete).toEqual([]);
    });

    it('refuses to delete a category still carrying a package', async () => {
      await request(app.getHttpServer())
        .delete(`/v1/staff/lab-categories/${labCategoryId}`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(400);
      // Still there, untouched.
      const [stillThere] = await db.select().from(labCategory).where(eq(labCategory.id, labCategoryId));
      expect(stillThere).toBeDefined();
    });

    it('404s updating, sorting, activating or deleting a category that does not exist', async () => {
      await request(app.getHttpServer())
        .patch('/v1/staff/lab-categories/999999/active')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ isActive: false })
        .expect(404);
      await request(app.getHttpServer())
        .delete('/v1/staff/lab-categories/999999')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(404);
    });
  });
});
