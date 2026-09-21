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
import { adminUser, dietitian, labBookingReport, labCategory, labPackage, patient, users } from '../../src/db/schema';
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
  let dietitianId: number;
  let ownedPatientId: number;

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

    // Inactive: proves listLabCategories' testCount only tallies active packages.
    await db
      .insert(labPackage)
      .values({ slug: 'hidden-package', name: 'Hidden Package', categoryId: labCategoryId, isActive: false });

    const [diet] = await db.insert(dietitian).values({ name: 'Dr. Nutrition', fee: '500.00' }).returning();
    dietitianId = diet.id;

    const [member] = await db
      .insert(users)
      .values({ phone: '9000000004', name: 'Care Member', firebaseUid: 'member-care-1', registrationCompletedAt: new Date() })
      .returning();
    firebase.register('member-token', { uid: 'member-care-1' });

    const [seededPatient] = await db
      .insert(patient)
      .values({ memberId: member.id, name: 'Self', dob: '1990-01-01', relation: 'SELF' })
      .returning();
    ownedPatientId = seededPatient.id;

    await db.insert(adminUser).values({
      loginId: 'care-staff@example.com',
      name: 'Care Staff',
      passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
      role: 'APPOINTMENTS',
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

    const dietitians = await request(app.getHttpServer()).get('/v1/public/care/dietitians').expect(200);
    expect(dietitians.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: dietitianId })]));
  });

  it('lists lab categories publicly, each counting only its own active packages', async () => {
    const categories = await request(app.getHttpServer()).get('/v1/public/care/lab-categories').expect(200);
    const diabetes = categories.body.find((c: { id: number }) => c.id === labCategoryId);
    expect(diabetes).toEqual(
      expect.objectContaining({ name: 'Diabetes', image: 'data:image/png;base64,abc', testCount: 1 }),
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
