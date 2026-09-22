process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { createTestDb, type TestDb } from './create-test-db';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('Member addresses (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let token: string;
  let otherMemberToken: string;

  beforeAll(async () => {
    db = createTestDb();
    firebase = new FakeFirebaseVerifier();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(FIREBASE_VERIFIER)
      .useValue(firebase)
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();

    firebase.register('address-member-token', { uid: 'address-member-uid', phoneNumber: '+919700000060' });
    const register = await request(app.getHttpServer())
      .post('/v1/member/auth/register')
      .send({ idToken: 'address-member-token', name: 'Address Member' })
      .expect(200);
    token = register.body.accessToken;

    firebase.register('other-member-token', { uid: 'other-member-uid', phoneNumber: '+919700000061' });
    const otherRegister = await request(app.getHttpServer())
      .post('/v1/member/auth/register')
      .send({ idToken: 'other-member-token', name: 'Other Member' })
      .expect(200);
    otherMemberToken = otherRegister.body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects every address route with no token', async () => {
    await request(app.getHttpServer()).get('/v1/member/addresses').expect(401);
    await request(app.getHttpServer()).post('/v1/member/addresses').expect(401);
  });

  it('creates, lists, updates and soft-deletes an address', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/member/addresses')
      .set('Authorization', `Bearer ${token}`)
      .send({ house: '1 Main St', area: 'Melattur', pincode: '679326' })
      .expect(201);
    const addressId = created.body.id;
    expect(created.body.label).toBe('HOME'); // default

    const listed = await request(app.getHttpServer())
      .get('/v1/member/addresses')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(listed.body).toEqual(expect.arrayContaining([expect.objectContaining({ id: addressId })]));

    const updated = await request(app.getHttpServer())
      .patch(`/v1/member/addresses/${addressId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ house: '2 Second St', label: 'WORK' })
      .expect(200);
    expect(updated.body.house).toBe('2 Second St');
    expect(updated.body.label).toBe('WORK');

    await request(app.getHttpServer())
      .delete(`/v1/member/addresses/${addressId}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(204);

    const afterDelete = await request(app.getHttpServer())
      .get('/v1/member/addresses')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(afterDelete.body.map((a: { id: number }) => a.id)).not.toContain(addressId);
  });

  it('404s updating or deleting an address that does not exist or belongs to someone else', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/member/addresses')
      .set('Authorization', `Bearer ${token}`)
      .send({ house: '3 Third St', area: 'Melattur', pincode: '679326' })
      .expect(201);
    const addressId = created.body.id;

    await request(app.getHttpServer())
      .patch(`/v1/member/addresses/${addressId + 1000000}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ house: 'Nope' })
      .expect(404);

    // otherMemberToken does not own this address — same 404, not a 403 that
    // would confirm the id exists to someone probing it.
    await request(app.getHttpServer())
      .patch(`/v1/member/addresses/${addressId}`)
      .set('Authorization', `Bearer ${otherMemberToken}`)
      .send({ house: 'Hijacked' })
      .expect(404);
    await request(app.getHttpServer())
      .delete(`/v1/member/addresses/${addressId}`)
      .set('Authorization', `Bearer ${otherMemberToken}`)
      .expect(404);

    // Untouched by the other member's failed attempts.
    const stillThere = await request(app.getHttpServer())
      .get('/v1/member/addresses')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(stillThere.body.map((a: { id: number }) => a.id)).toContain(addressId);
  });

  it("rejects naming a patientId that does not belong to the authenticated member — on both create and update", async () => {
    await request(app.getHttpServer())
      .post('/v1/member/addresses')
      .set('Authorization', `Bearer ${token}`)
      .send({ house: '4 Fourth St', area: 'Melattur', pincode: '679326', patientId: 999999 })
      .expect(403);

    const created = await request(app.getHttpServer())
      .post('/v1/member/addresses')
      .set('Authorization', `Bearer ${token}`)
      .send({ house: '5 Fifth St', area: 'Melattur', pincode: '679326' })
      .expect(201);

    await request(app.getHttpServer())
      .patch(`/v1/member/addresses/${created.body.id}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ patientId: 999999 })
      .expect(403);
  });
});
