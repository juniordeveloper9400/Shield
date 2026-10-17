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
import { adminUser } from '../../src/db/schema';
import { createTestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('Lab Charges settings', () => {
  let app: INestApplication;
  let token: string;
  let technicianToken: string;
  beforeAll(async () => {
    const db = createTestDb();
    const module = await Test.createTestingModule({ imports: [AppModule] }).overrideProvider(DRIZZLE).useValue(db)
      .overrideProvider(REDIS_CLIENT).useValue(createTestRedis()).overrideProvider(FIREBASE_VERIFIER).useValue(new FakeFirebaseVerifier()).compile();
    app = module.createNestApplication();
    await app.init();
    for (const role of ['ADMIN', 'LAB_TECHNICIAN'] as const) {
      const loginId = `charges-${role}@example.com`;
      await db.insert(adminUser).values({ loginId, name: role, role, passwordHash: await hash('test-charges-password', 4) });
      const login = await request(app.getHttpServer()).post('/v1/staff/auth/session').send({ loginId, password: 'test-charges-password' }).expect(200);
      if (role === 'ADMIN') token = login.body.accessToken; else technicianToken = login.body.accessToken;
    }
  });
  afterAll(async () => { await app.close(); });

  it('creates, lists, edits and deletes technician and distance charges', async () => {
    const base = '/v1/staff/lab-charges';
    const tech = await request(app.getHttpServer()).post(base).set('Authorization', `Bearer ${token}`)
      .send({ name: 'Technician visit', kind: 'TECHNICIAN', amount: 75, isActive: true }).expect(201);
    const distance = await request(app.getHttpServer()).post(base).set('Authorization', `Bearer ${token}`)
      .send({ name: 'Home collection distance', kind: 'DISTANCE', firstKm: 3, firstAmount: 20, secondKm: 5, secondAmount: 50, extraPerKm: 15, isActive: true }).expect(201);
    const rows = await request(app.getHttpServer()).get(base).set('Authorization', `Bearer ${token}`).expect(200);
    expect(rows.body).toHaveLength(2);
    await request(app.getHttpServer()).patch(`${base}/${tech.body.id}`).set('Authorization', `Bearer ${token}`)
      .send({ name: 'Technician visit', kind: 'TECHNICIAN', amount: 100, isActive: true }).expect(200);
    const preview = await request(app.getHttpServer()).post(`${base}/preview`).set('Authorization', `Bearer ${token}`).send({ distanceKm: 6 }).expect(201);
    expect(preview.body).toMatchObject({ technician: 100, distance: 65, total: 165 });
    await request(app.getHttpServer()).delete(`${base}/${tech.body.id}`).set('Authorization', `Bearer ${token}`).expect(200);
    await request(app.getHttpServer()).delete(`${base}/${distance.body.id}`).set('Authorization', `Bearer ${token}`).expect(200);
    expect((await request(app.getHttpServer()).get(base).set('Authorization', `Bearer ${token}`).expect(200)).body).toEqual([]);
  });
  it('rejects invalid slabs and refuses technician access to rate management', async () => {
    await request(app.getHttpServer()).post('/v1/staff/lab-charges').set('Authorization', `Bearer ${token}`)
      .send({ name: 'Bad slabs', kind: 'DISTANCE', firstKm: 5, firstAmount: 20, secondKm: 3, secondAmount: 50, extraPerKm: -15 }).expect(400);
    await request(app.getHttpServer()).get('/v1/staff/lab-charges').set('Authorization', `Bearer ${technicianToken}`).expect(403);
  });
});
