process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { eq } from 'drizzle-orm';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { adminUser, agentRequest, membershipTier, users, wallet, walletCard } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('Admin/Ops (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let superAdminToken: string;
  let pharmacyToken: string;

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

    await db.insert(adminUser).values({
      email: 'root-superadmin@example.com',
      name: 'Root Super Admin',
      firebaseUid: 'staff-root-superadmin',
      role: 'SUPERADMIN',
    });
    firebase.register('superadmin-token', { uid: 'staff-root-superadmin', email: 'root-superadmin@example.com' });
    superAdminToken = (
      await request(app.getHttpServer()).post('/v1/staff/auth/session').send({ idToken: 'superadmin-token' }).expect(200)
    ).body.accessToken;

    await db.insert(adminUser).values({
      email: 'pharmacy-admin@example.com',
      name: 'Pharmacy Admin',
      firebaseUid: 'staff-pharmacy-admin',
      role: 'PHARMACY',
    });
    firebase.register('pharmacy-token', { uid: 'staff-pharmacy-admin', email: 'pharmacy-admin@example.com' });
    pharmacyToken = (
      await request(app.getHttpServer()).post('/v1/staff/auth/session').send({ idToken: 'pharmacy-token' }).expect(200)
    ).body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects a non-SUPERADMIN staff role from managing staff accounts', async () => {
    await request(app.getHttpServer())
      .get('/v1/staff/admins')
      .set('Authorization', `Bearer ${pharmacyToken}`)
      .expect(403);
  });

  let newStaffId: number;

  it('lets SUPERADMIN create a staff account', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/staff/admins')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ email: 'new-lab-tech@example.com', name: 'New Lab Tech', role: 'LAB' })
      .expect(201);

    newStaffId = res.body.id;
    expect(res.body.isActive).toBe(true);
    expect(res.body.firebaseUid).toBeNull(); // not linked until their first login
  });

  it('rejects creating a second staff account with the same email', async () => {
    await request(app.getHttpServer())
      .post('/v1/staff/admins')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ email: 'new-lab-tech@example.com', name: 'Duplicate', role: 'LAB' })
      .expect(409);
  });

  it('lets SUPERADMIN deactivate a staff account', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/v1/staff/admins/${newStaffId}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ isActive: false })
      .expect(200);
    expect(res.body.isActive).toBe(false);
  });

  it('a deactivated staff account cannot log in even with a valid Firebase token', async () => {
    await db.update(adminUser).set({ firebaseUid: 'staff-deactivated-test' }).where(eq(adminUser.id, newStaffId));
    firebase.register('deactivated-token', { uid: 'staff-deactivated-test' });

    await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ idToken: 'deactivated-token' })
      .expect(403);
  });

  it('reports accurate, pre-aggregated dashboard counts', async () => {
    const [member] = await db
      .insert(users)
      .values({ phone: '9300000001', name: 'Dashboard Member', firebaseUid: 'member-dashboard-1' })
      .returning();
    const [dashboardWallet] = await db.insert(wallet).values({ memberId: member.id }).returning();
    const [tier] = await db.insert(membershipTier).values({ kind: 'GOLD', name: 'Gold', bin: '5678' }).returning();

    await db.insert(agentRequest).values({ requestedLevel: 'NATIONAL', name: 'Candidate', phone: '9300000002' });
    await db.insert(walletCard).values({
      walletId: dashboardWallet.id,
      tierId: tier.id,
      amount: '20000.00',
      bonus: '2000.00',
      issuedOn: '2026-01-01',
      rechargedOn: '2026-01-01',
      expiresOn: '2027-01-01',
    });

    const summary = await request(app.getHttpServer())
      .get('/v1/staff/dashboard/summary')
      .set('Authorization', `Bearer ${pharmacyToken}`)
      .expect(200);

    expect(summary.body.pendingAgentRequests).toBeGreaterThanOrEqual(1);
    expect(summary.body.pendingWalletCards).toBeGreaterThanOrEqual(1);
    expect(summary.body.totalMembers).toBeGreaterThanOrEqual(1);
    expect(summary.body.totalStaff).toBeGreaterThanOrEqual(2);
  });

  it('actually throttles the auth endpoint after its tighter per-route limit — not just the global default', async () => {
    firebase.register('throttle-test-token', { uid: 'no-such-user-throttle-test' });

    const results: number[] = [];
    for (let i = 0; i < 12; i++) {
      const res = await request(app.getHttpServer())
        .post('/v1/member/auth/session')
        .send({ idToken: 'throttle-test-token' });
      results.push(res.status);
    }

    // AuthThrottle allows 10/60s on this route — the 11th+ request in the
    // same window must be rejected with 429, well before the global 120/60s
    // default would ever kick in.
    expect(results.filter((s) => s === 429).length).toBeGreaterThan(0);
    expect(results.slice(0, 10).every((s) => s === 404)).toBe(true); // unregistered identity, but not yet throttled
  });
});
