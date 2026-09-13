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
import { adminUser, dietitian, labPackage, patient, users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('Care Services (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let memberAccessToken: string;
  let staffAccessToken: string;
  let labPackageId: number;
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

    const [pkg] = await db
      .insert(labPackage)
      .values({ slug: 'full-body', name: 'Full Body Checkup', price: '999.00', mrp: '1499.00' })
      .returning();
    labPackageId = pkg.id;

    const [diet] = await db.insert(dietitian).values({ name: 'Dr. Nutrition', fee: '500.00' }).returning();
    dietitianId = diet.id;

    const [member] = await db
      .insert(users)
      .values({ phone: '9000000004', name: 'Care Member', firebaseUid: 'member-care-1' })
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

    memberAccessToken = (
      await request(app.getHttpServer()).post('/v1/member/auth/session').send({ idToken: 'member-token' }).expect(200)
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
    expect(packages.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: labPackageId })]));

    const dietitians = await request(app.getHttpServer()).get('/v1/public/care/dietitians').expect(200);
    expect(dietitians.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: dietitianId })]));
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
