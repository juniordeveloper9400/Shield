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
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

const STAFF_PASSWORD = 'correct-horse-battery-staple';
const testPasswordHash = () => hash(STAFF_PASSWORD, 4); // low cost factor — this is a test, not production

/**
 * ModuleGuard (common/guards/module.guard.ts) — proves a per-account
 * `modules` override is a real, server-enforced restriction, not just a
 * sidebar preview: an account narrowed away from a module can no longer
 * call that module's own routes, an unmapped/shared route stays reachable
 * regardless (the documented safe default), and an account with no
 * customization (`modules: null`, every account until someone edits it)
 * keeps its full role access exactly as before this feature existed.
 */
describe('ModuleGuard — per-account module restriction (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;

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
  });

  afterAll(async () => {
    await app.close();
  });

  async function staffToken(loginId: string, role: 'SUPERADMIN' | 'LAB', modules: string[] | null) {
    await db.insert(adminUser).values({
      loginId,
      name: `${role} Staff`,
      passwordHash: await testPasswordHash(),
      role,
      modules,
    });
    const res = await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ loginId, password: STAFF_PASSWORD })
      .expect(200);
    return res.body.accessToken as string;
  }

  it('an account with no customization (modules: null) keeps its full role access', async () => {
    const token = await staffToken('mg-lab-default@example.com', 'LAB', null);
    await request(app.getHttpServer())
      .get('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    await request(app.getHttpServer())
      .get('/v1/staff/lab-bookings')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
  });

  it('narrows a role-eligible route the account was not granted, with its own 403', async () => {
    // LAB normally gets lab_tests, lab_orders and lab_bills — this account
    // is narrowed to lab_tests only.
    const token = await staffToken('mg-lab-narrow@example.com', 'LAB', ['dashboard', 'lab_tests']);

    await request(app.getHttpServer())
      .get('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    const refused = await request(app.getHttpServer())
      .get('/v1/staff/lab-bookings')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
    expect(refused.body.error.message).toMatch(/turned off/i);
  });

  it('a route not in the module table stays reachable regardless of the custom list — the safe default', async () => {
    // The plain store list is open to any staff role and deliberately left
    // out of module-routes.ts (shared by too many pages to gate on one) —
    // an account narrowed to only 'lab_tests' must still be able to read it.
    const token = await staffToken('mg-lab-stores@example.com', 'LAB', ['lab_tests']);
    await request(app.getHttpServer())
      .get('/v1/staff/catalogue/stores')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
  });

  it('an empty custom list refuses every mapped route, not just one', async () => {
    const token = await staffToken('mg-lab-empty@example.com', 'LAB', []);
    await request(app.getHttpServer())
      .get('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
    await request(app.getHttpServer())
      .get('/v1/staff/lab-bookings')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  it("role still wins first — narrowing modules never grants a route the role itself can't reach", async () => {
    // A LAB account customized to list 'admins' in its own modules still
    // can't reach /v1/staff/admins — RolesGuard refuses it before
    // ModuleGuard is ever consulted (SUPERADMIN/ADMIN only).
    const token = await staffToken('mg-lab-overreach@example.com', 'LAB', ['admins']);
    await request(app.getHttpServer())
      .get('/v1/staff/admins')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });
});
