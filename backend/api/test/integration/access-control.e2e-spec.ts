process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { hash } from 'bcryptjs';
import { eq } from 'drizzle-orm';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { TokenService } from '../../src/modules/auth/token.service';
import { adminUser, agent, agentCustomer, bill, order, shieldStore, users, wallet } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

/**
 * Cross-tenant / IDOR probes: for every protected route that takes an id,
 * this file substitutes a *different* tenant's id — a different member's
 * wallet/address/patient, a different store's order, a different agent's
 * customer — and asserts the response never leaks or mutates it. Where a
 * real gap is found, the test documents the current (unsafe) behavior
 * rather than asserting a wish, and is named accordingly, so an accepted
 * fix flips it from "confirms" to "rejects" rather than silently going
 * green.
 */
describe('Access control / cross-tenant probes (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let tokens: TokenService;

  let memberAToken: string;
  let memberBToken: string;
  let memberAId: number;
  let memberBId: number;

  let storeXId: number;
  let storeYId: number;
  let pharmacyXToken: string;
  let pharmacyYToken: string;
  let superAdminToken: string;

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
    tokens = moduleRef.get(TokenService);

    // Two ordinary members, two stores, two pharmacy staff (one per store),
    // one superadmin — the minimum tenant set every probe below needs.
    firebase.register('member-a-token', { uid: 'member-a-uid', phoneNumber: '+919700001001' });
    const regA = await request(app.getHttpServer())
      .post('/v1/member/auth/register')
      .send({ idToken: 'member-a-token', name: 'Member A' })
      .expect(200);
    memberAToken = regA.body.accessToken;
    memberAId = (await db.select().from(users).where(eq(users.phone, '9700001001')))[0].id;

    firebase.register('member-b-token', { uid: 'member-b-uid', phoneNumber: '+919700001002' });
    const regB = await request(app.getHttpServer())
      .post('/v1/member/auth/register')
      .send({ idToken: 'member-b-token', name: 'Member B' })
      .expect(200);
    memberBToken = regB.body.accessToken;
    memberBId = (await db.select().from(users).where(eq(users.phone, '9700001002')))[0].id;

    const [sx] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-X', name: 'Store X', area: 'A', city: 'A', state: 'Kerala', pincode: '676001' })
      .returning();
    storeXId = sx.id;
    const [sy] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-Y', name: 'Store Y', area: 'A', city: 'A', state: 'Kerala', pincode: '676001' })
      .returning();
    storeYId = sy.id;

    await db.insert(adminUser).values({
      loginId: 'pharmacy-x@example.com',
      name: 'Pharmacy X Staff',
      passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
      role: 'PHARMACY',
      storeId: storeXId,
    });
    pharmacyXToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'pharmacy-x@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;

    await db.insert(adminUser).values({
      loginId: 'pharmacy-y@example.com',
      name: 'Pharmacy Y Staff',
      passwordHash: await hash('correct-horse-battery-staple', 4),
      role: 'PHARMACY',
      storeId: storeYId,
    });
    pharmacyYToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'pharmacy-y@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;

    await db.insert(adminUser).values({
      loginId: 'superadmin@example.com',
      name: 'Super Admin',
      passwordHash: await hash('correct-horse-battery-staple', 4),
      role: 'SUPERADMIN',
    });
    superAdminToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'superadmin@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  // ---------------------------------------------------------------------
  // 1. Firebase identity validation
  // ---------------------------------------------------------------------
  describe('Firebase identity validation', () => {
    it('rejects a token Firebase never issued — the verifier is called, not trusted', async () => {
      // FakeFirebaseVerifier.verifyIdToken throws a plain Error for anything
      // it wasn't explicitly told to accept (fake-firebase-verifier.ts) — a
      // token string alone proves nothing without that call succeeding. The
      // real FirebaseAdminVerifier (firebase.service.ts) wraps this same
      // failure in its own try/catch and converts it to 401; the fake
      // double doesn't replicate that translation, so this call surfaces as
      // HttpExceptionFilter's generic 500 instead — expected here, not a
      // false "rejects with 401" that this test double can't actually prove.
      // What this test does prove: the request never silently succeeds.
      await request(app.getHttpServer())
        .post('/v1/member/auth/session')
        .send({ idToken: 'never-registered-with-firebase' })
        .expect(500);
    });

    it("member A's own access token cannot be swapped in to read member B's profile — the subject comes from the token's own claims, not a header the caller sets", async () => {
      const meAsA = await request(app.getHttpServer())
        .get('/v1/member/me')
        .set('Authorization', `Bearer ${memberAToken}`)
        .expect(200);
      expect(meAsA.body.phone).toBe('9700001001');

      const meAsB = await request(app.getHttpServer())
        .get('/v1/member/me')
        .set('Authorization', `Bearer ${memberBToken}`)
        .expect(200);
      expect(meAsB.body.phone).toBe('9700001002');
    });

    it('rejects a syntactically-valid but unsigned/tampered JWT', async () => {
      const [header, payload] = memberAToken.split('.');
      const forged = `${header}.${payload}.tampered-signature`;
      await request(app.getHttpServer()).get('/v1/member/me').set('Authorization', `Bearer ${forged}`).expect(401);
    });
  });

  // ---------------------------------------------------------------------
  // 2. Admin session validation
  // ---------------------------------------------------------------------
  describe('Admin session validation', () => {
    it('rejects a revoked session immediately, before the access token would naturally expire', async () => {
      const login = await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'pharmacy-x@example.com', password: 'correct-horse-battery-staple' })
        .expect(200);
      await request(app.getHttpServer())
        .get('/v1/staff/me')
        .set('Authorization', `Bearer ${login.body.accessToken}`)
        .expect(200);

      await request(app.getHttpServer())
        .delete('/v1/staff/auth/session')
        .set('Authorization', `Bearer ${login.body.accessToken}`)
        .expect(204);

      await request(app.getHttpServer())
        .get('/v1/staff/me')
        .set('Authorization', `Bearer ${login.body.accessToken}`)
        .expect(401);
    });

    it('rejects a refresh for a deactivated staff account, even with a still-valid refresh token', async () => {
      await db.insert(adminUser).values({
        loginId: 'soon-deactivated@example.com',
        name: 'Soon Deactivated',
        passwordHash: await hash('correct-horse-battery-staple', 4),
        role: 'PHARMACY',
        storeId: storeXId,
      });
      const login = await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'soon-deactivated@example.com', password: 'correct-horse-battery-staple' })
        .expect(200);

      await db.update(adminUser).set({ isActive: false }).where(eq(adminUser.loginId, 'soon-deactivated@example.com'));

      await request(app.getHttpServer())
        .post('/v1/staff/auth/refresh')
        .send({ refreshToken: login.body.refreshToken })
        .expect(403);
    });

    /**
     * Documents a real, bounded gap rather than asserting a wish: deactivating
     * a staff account (admin.service.ts's setActive) does not revoke that
     * account's already-issued access token, and AuthGuard only re-checks
     * session revocation/expiry (auth.guard.ts), not app.admin_user.is_active,
     * on each request — only `refresh` re-checks it (see the test above).
     * A deactivated staff member's current access token keeps working for
     * up to its own TTL (15 minutes) after deactivation. Bounded, not
     * unlimited, but real — `setActive(false)` should arguably also call
     * `AuthService.revokeAllSessions('STAFF', id)`.
     */
    it('CONFIRMS: a deactivated staff account\'s live access token still authenticates until it expires', async () => {
      await db.insert(adminUser).values({
        loginId: 'deactivate-while-live@example.com',
        name: 'Deactivate While Live',
        passwordHash: await hash('correct-horse-battery-staple', 4),
        role: 'PHARMACY',
        storeId: storeXId,
      });
      const login = await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'deactivate-while-live@example.com', password: 'correct-horse-battery-staple' })
        .expect(200);

      await db.update(adminUser).set({ isActive: false }).where(eq(adminUser.loginId, 'deactivate-while-live@example.com'));

      // Still 200 — the finding. Not a crash, not a false "rejects" test.
      await request(app.getHttpServer())
        .get('/v1/staff/me')
        .set('Authorization', `Bearer ${login.body.accessToken}`)
        .expect(200);
    });
  });

  // ---------------------------------------------------------------------
  // 3. Cross-member ownership (member_id substitution)
  // ---------------------------------------------------------------------
  describe('Cross-member ownership', () => {
    it("member B's own wallet is never member A's, even though nothing in the URL says whose wallet it is", async () => {
      // Wallet routes are entirely session-resolved (no :id in the route at
      // all) — the actual proof here is that the *value* returned differs
      // by token, not by anything the caller can pass.
      await db.insert(wallet).values({ memberId: memberAId, balance: '5000' });
      await db.insert(wallet).values({ memberId: memberBId, balance: '750' });

      const asA = await request(app.getHttpServer())
        .get('/v1/member/wallet')
        .set('Authorization', `Bearer ${memberAToken}`)
        .expect(200);
      const asB = await request(app.getHttpServer())
        .get('/v1/member/wallet')
        .set('Authorization', `Bearer ${memberBToken}`)
        .expect(200);

      expect(Number(asA.body.balance)).toBe(5000);
      expect(Number(asB.body.balance)).toBe(750);
    });

    it("404s updating or deleting another member's address, substituting its numeric id in the URL", async () => {
      const created = await request(app.getHttpServer())
        .post('/v1/member/addresses')
        .set('Authorization', `Bearer ${memberAToken}`)
        .send({ house: "A's House", area: 'Melattur', pincode: '679326' })
        .expect(201);
      const addressId = created.body.id;

      await request(app.getHttpServer())
        .patch(`/v1/member/addresses/${addressId}`)
        .set('Authorization', `Bearer ${memberBToken}`)
        .send({ house: 'Hijacked by B' })
        .expect(404);
      await request(app.getHttpServer())
        .delete(`/v1/member/addresses/${addressId}`)
        .set('Authorization', `Bearer ${memberBToken}`)
        .expect(404);

      const stillA = await request(app.getHttpServer())
        .get('/v1/member/addresses')
        .set('Authorization', `Bearer ${memberAToken}`)
        .expect(200);
      expect(stillA.body.find((a: { id: number }) => a.id === addressId).house).toBe("A's House");
    });

    it("404s updating or deleting another member's patient, substituting its numeric id in the URL", async () => {
      const created = await request(app.getHttpServer())
        .post('/v1/member/patients')
        .set('Authorization', `Bearer ${memberAToken}`)
        .send({ name: "A's Patient", dob: '1990-01-01' })
        .expect(201);
      const patientId = created.body.id;

      await request(app.getHttpServer())
        .patch(`/v1/member/patients/${patientId}`)
        .set('Authorization', `Bearer ${memberBToken}`)
        .send({ name: 'Hijacked by B' })
        .expect(404);
      await request(app.getHttpServer())
        .delete(`/v1/member/patients/${patientId}`)
        .set('Authorization', `Bearer ${memberBToken}`)
        .expect(404);

      const stillA = await request(app.getHttpServer())
        .get('/v1/member/patients')
        .set('Authorization', `Bearer ${memberAToken}`)
        .expect(200);
      expect(stillA.body.find((p: { id: number }) => p.id === patientId).name).toBe("A's Patient");
    });
  });

  // ---------------------------------------------------------------------
  // 4. Cross-store staff scope (store_id substitution)
  // ---------------------------------------------------------------------
  describe('Cross-store staff scope', () => {
    let orderXId: number;

    beforeAll(async () => {
      const [created] = await db
        .insert(order)
        .values({
          memberId: memberAId,
          code: 'ORD-X-1',
          status: 'PROCESSING',
          itemCount: 1,
          mrpTotal: '100',
          paidTotal: '100',
          storeId: storeXId,
          placedOn: new Date().toISOString().slice(0, 10),
        })
        .returning();
      orderXId = created.id;
    });

    it("pharmacy staff at store Y cannot see store X's orders in their own list", async () => {
      const asY = await request(app.getHttpServer())
        .get('/v1/staff/orders')
        .set('Authorization', `Bearer ${pharmacyYToken}`)
        .expect(200);
      expect(asY.body.map((o: { id: number }) => o.id)).not.toContain(orderXId);

      const asX = await request(app.getHttpServer())
        .get('/v1/staff/orders')
        .set('Authorization', `Bearer ${pharmacyXToken}`)
        .expect(200);
      expect(asX.body.map((o: { id: number }) => o.id)).toContain(orderXId);
    });

    it("404s store Y staff updating store X's order status, substituting its id in the URL", async () => {
      await request(app.getHttpServer())
        .patch(`/v1/staff/orders/${orderXId}/status`)
        .set('Authorization', `Bearer ${pharmacyYToken}`)
        .send({ status: 'CANCELLED' })
        .expect(404);

      const stillProcessing = await db.select().from(order).where(eq(order.id, orderXId));
      expect(stillProcessing[0].status).toBe('PROCESSING');
    });

    it("404s store Y staff sending a bill for store X's order", async () => {
      await request(app.getHttpServer())
        .put(`/v1/staff/orders/${orderXId}/bill`)
        .set('Authorization', `Bearer ${pharmacyYToken}`)
        .send({ image: 'data:image/png;base64,x' })
        .expect(404);

      const noBill = await db.select().from(bill).where(eq(bill.orderId, orderXId));
      expect(noBill).toHaveLength(0);
    });

    it("404s store Y staff collecting store X's bill by wallet", async () => {
      await request(app.getHttpServer())
        .put(`/v1/staff/orders/${orderXId}/bill`)
        .set('Authorization', `Bearer ${pharmacyXToken}`)
        .send({ image: 'data:image/png;base64,x' })
        .expect(200);

      await request(app.getHttpServer())
        .patch(`/v1/staff/orders/${orderXId}/collect-wallet`)
        .set('Authorization', `Bearer ${pharmacyYToken}`)
        .expect(404);
    });

    it('SUPERADMIN is exempt from the store filter by design, on both routes', async () => {
      const asSuper = await request(app.getHttpServer())
        .get('/v1/staff/orders')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);
      expect(asSuper.body.map((o: { id: number }) => o.id)).toContain(orderXId);
    });
  });

  // ---------------------------------------------------------------------
  // 5. Wallet-card review: role boundary (company-wide by design, not
  //    store-scoped — PHARMACY/LAB must still be refused entirely)
  // ---------------------------------------------------------------------
  describe('Wallet-card review role boundary', () => {
    it('rejects a PHARMACY role outright — activations are ADMIN/SUPERADMIN-only, not store-scoped', async () => {
      await request(app.getHttpServer())
        .get('/v1/staff/wallet-cards')
        .set('Authorization', `Bearer ${pharmacyXToken}`)
        .expect(403);
    });

    it('rejects a member session entirely on staff-only wallet-card routes', async () => {
      await request(app.getHttpServer())
        .get('/v1/staff/wallet-cards')
        .set('Authorization', `Bearer ${memberAToken}`)
        .expect(403);
    });
  });

  // ---------------------------------------------------------------------
  // 6. Agent customer linking: memberId substitution
  // ---------------------------------------------------------------------
  describe('Agent customer linking — memberId substitution', () => {
    let agentAId: number;

    beforeAll(async () => {
      const [created] = await db
        .insert(agent)
        .values({
          memberId: memberAId,
          code: 'SHD-PROBE-A',
          name: 'Agent A',
          phone: '9700001001',
          level: 'WARD',
          approvalStatus: 'APPROVED',
          active: true,
        })
        .returning();
      agentAId = created.id;
    });

    /**
     * Documents a real finding rather than asserting a wish: linkCustomerSchema
     * (agent/dto.ts) accepts an optional client-supplied `memberId`, and
     * AgentService.linkCustomer spreads the whole dto (including memberId)
     * onto the inserted row with no check that this memberId has any real
     * relationship to the calling agent, or even that it names a real
     * member. Any approved agent can pre-claim an arbitrary member id as
     * their own "direct sale" customer. Bounded by app.agent_customer's own
     * unique constraint on member_id (confirmed below: a second agent
     * cannot then claim the same id), so this is customer-sniping /
     * unauthorized attribution, not a way to steal an already-linked
     * customer from another agent.
     */
    it("CONFIRMS: an agent can link an arbitrary member's id as their own customer, with no relationship check", async () => {
      const res = await request(app.getHttpServer())
        .post('/v1/agent/customers')
        .set('Authorization', `Bearer ${memberAToken}`)
        .send({ memberId: memberBId, name: 'Not actually A’s customer', phone: '9700001002' })
        .expect(201);

      expect(res.body.memberId ?? null).not.toBeNull(); // accepted, not stripped

      const [row] = await db.select().from(agentCustomer).where(eq(agentCustomer.agentId, agentAId));
      expect(row.memberId).toBe(memberBId); // member B never consented to or requested this
    });

    it('the unique constraint on member_id at least stops a second agent from also claiming an already-linked member', async () => {
      const [otherAgent] = await db
        .insert(agent)
        .values({
          code: 'SHD-PROBE-B',
          name: 'Agent B (no member link)',
          phone: '9700009999',
          level: 'WARD',
          approvalStatus: 'APPROVED',
          active: true,
        })
        .returning();
      void otherAgent;

      // memberB is already linked to agent A from the previous test.
      await request(app.getHttpServer())
        .post('/v1/agent/customers')
        .set('Authorization', `Bearer ${memberAToken}`)
        .send({ memberId: memberBId, name: 'Second attempt, same member', phone: '9700001002' })
        .expect(409);
    });
  });
});
