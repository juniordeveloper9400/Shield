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
import { product, productCategory, shieldStore, users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('Registration is required to act, and is read back reliably (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let activeStoreId: number;
  let inactiveStoreId: number;
  let productId: number;
  let phoneCounter = 9100000000;

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

    const [open] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-OPEN', name: 'Open Branch', area: 'A', city: 'A', state: 'A', pincode: '111111', isActive: true })
      .returning();
    const [closed] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-CLOSED', name: 'Closed Branch', area: 'B', city: 'B', state: 'B', pincode: '222222', isActive: false })
      .returning();
    activeStoreId = open.id;
    inactiveStoreId = closed.id;

    const [category] = await db.insert(productCategory).values({ slug: 'otc', title: 'OTC', tabLabel: 'OTC' }).returning();
    const [seeded] = await db
      .insert(product)
      .values({ name: 'Vitamin C', categoryId: category.id, price: '100.00', mrp: '120.00' })
      .returning();
    productId = seeded.id;
  });

  afterAll(async () => {
    await app.close();
  });

  /** A signed-in member, registered or not, with their access token. */
  async function member(opts: { registered?: boolean; homeStoreId?: number } = {}) {
    const phone = String(++phoneCounter);
    const uid = `uid-${phone}`;
    const [row] = await db
      .insert(users)
      .values({
        phone,
        name: 'Test Member',
        firebaseUid: uid,
        homeStoreId: opts.homeStoreId,
        registrationCompletedAt: opts.registered ? new Date() : undefined,
      })
      .returning();
    firebase.register(`token-${phone}`, { uid });
    const login = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: `token-${phone}` })
      .expect(200);
    return { id: row.id, token: login.body.accessToken as string };
  }

  const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

  const gatedActions = (token: string): [string, () => request.Test][] => [
    ['add to cart', () => request(app.getHttpServer()).post('/v1/member/cart/lines').set(auth(token)).send({ productId, qty: 1 })],
    [
      'checkout',
      () => request(app.getHttpServer()).post('/v1/member/orders').set(auth(token)).set('Idempotency-Key', 'k-1').send({}),
    ],
    [
      'upload a prescription',
      () => request(app.getHttpServer()).post('/v1/member/prescriptions').set(auth(token)).send({ images: [] }),
    ],
    [
      'order a prescription',
      () => request(app.getHttpServer()).post('/v1/member/prescription-orders').set(auth(token)).send({ prescriptionIds: [1] }),
    ],
    ['book a lab test', () => request(app.getHttpServer()).post('/v1/member/lab-bookings').set(auth(token)).send({})],
    ['book an appointment', () => request(app.getHttpServer()).post('/v1/member/appointments').set(auth(token)).send({})],
    ['buy a wallet card', () => request(app.getHttpServer()).post('/v1/member/wallet/cards').set(auth(token)).send({})],
  ];

  // The login endpoint is rate-limited, so the tests share a few members
  // instead of signing a new one in per test. Each is only ever changed by the
  // test that owns it.
  let unregistered: { id: number; token: string };
  let registering: { id: number; token: string };
  let registeredNoBranch: { id: number; token: string };
  let registeredClosedBranch: { id: number; token: string };
  let linking: { id: number; token: string };

  beforeAll(async () => {
    unregistered = await member();
    registering = await member();
    registeredNoBranch = await member({ registered: true });
    registeredClosedBranch = await member({ registered: true, homeStoreId: inactiveStoreId });
    linking = await member();
  });

  describe('an unregistered member', () => {
    it('is refused every action that creates something, with REGISTRATION_REQUIRED', async () => {
      for (const [label, act] of gatedActions(unregistered.token)) {
        const res = await act();
        expect({ label, status: res.status }).toEqual({ label, status: 403 });
        expect(res.body.error.code).toBe('REGISTRATION_REQUIRED');
        expect(res.body.error.message).toMatch(/registration/i);
      }
    });

    it('can still read their account and cart', async () => {
      const { token } = unregistered;
      await request(app.getHttpServer()).get('/v1/member/me').set(auth(token)).expect(200);
      await request(app.getHttpServer()).get('/v1/member/cart').set(auth(token)).expect(200);
      await request(app.getHttpServer()).get('/v1/member/orders').set(auth(token)).expect(200);
    });

    it('is let through the moment they register — no new session needed', async () => {
      const { token } = registering;
      await request(app.getHttpServer()).post('/v1/member/cart/lines').set(auth(token)).send({ productId, qty: 1 }).expect(403);

      await request(app.getHttpServer())
        .patch('/v1/member/me')
        .set(auth(token))
        .send({ name: 'Now Registered', homeStoreCode: 'SHD-OPEN' })
        .expect(200);

      const added = await request(app.getHttpServer())
        .post('/v1/member/cart/lines')
        .set(auth(token))
        .send({ productId, qty: 1 })
        .expect(201);
      expect(added.body.qty).toBe(1);
    });
  });

  describe('a registered member', () => {
    it('is not stopped by the registration check on any of those actions', async () => {
      for (const [label, act] of gatedActions(registeredNoBranch.token)) {
        const res = await act();
        // Past the registration gate — whatever comes next (validation, not found) is another rule's answer.
        expect({ label, code: res.body?.error?.code }).not.toEqual({ label, code: 'REGISTRATION_REQUIRED' });
      }
    });
  });

  describe('reading the registration back', () => {
    it('reports a registered member as registered, with their branch code, even after the branch is switched off', async () => {
      const me = await request(app.getHttpServer()).get('/v1/member/me').set(auth(registeredClosedBranch.token)).expect(200);
      expect(me.body.registrationCompletedAt).not.toBeNull();
      expect(me.body.homeStoreId).toBe(inactiveStoreId);
      expect(me.body.homeStoreCode).toBe('SHD-CLOSED');
    });

    it('reports no branch code — not an error — for a member with no branch', async () => {
      const me = await request(app.getHttpServer()).get('/v1/member/me').set(auth(registeredNoBranch.token)).expect(200);
      expect(me.body.registrationCompletedAt).not.toBeNull();
      expect(me.body.homeStoreCode).toBeNull();
    });
  });

  describe('saving the registration', () => {
    it('refuses a branch that is not taking new members — clearly, and without half-registering the member', async () => {
      const res = await request(app.getHttpServer())
        .patch('/v1/member/me')
        .set(auth(unregistered.token))
        .send({ name: 'Asha', homeStoreCode: 'SHD-CLOSED' })
        .expect(403);
      expect(res.body.error.code).toBe('STORE_UNAVAILABLE');
      expect(res.body.error.message).toMatch(/Choose another branch/);

      const [row] = await db.select().from(users).where(eq(users.id, unregistered.id));
      expect(row.registrationCompletedAt).toBeNull(); // not registered, and not silently saved without a branch
      expect(row.homeStoreId).toBeNull();
    });

    it('refuses an unknown branch code', async () => {
      await request(app.getHttpServer())
        .patch('/v1/member/me')
        .set(auth(unregistered.token))
        .send({ homeStoreCode: 'SHD-NOPE' })
        .expect(403);
    });

    it('links the branch by code, returns the code back, and reads it back', async () => {
      const { token } = linking;
      const saved = await request(app.getHttpServer())
        .patch('/v1/member/me')
        .set(auth(token))
        .send({ name: 'Asha', dob: '1994-09-04', homeStoreCode: 'SHD-OPEN' })
        .expect(200);
      expect(saved.body.registrationCompletedAt).not.toBeNull();
      expect(saved.body.homeStoreId).toBe(activeStoreId);
      expect(saved.body.homeStoreCode).toBe('SHD-OPEN');

      const me = await request(app.getHttpServer()).get('/v1/member/me').set(auth(token)).expect(200);
      expect(me.body.homeStoreCode).toBe('SHD-OPEN');
    });

    it('still accepts the branch by numeric id, as before', async () => {
      const res = await request(app.getHttpServer())
        .patch('/v1/member/me')
        .set(auth(linking.token))
        .send({ homeStoreId: activeStoreId })
        .expect(200);
      expect(res.body.homeStoreCode).toBe('SHD-OPEN');
    });

    it('lets a member keep editing their profile after their own branch is switched off', async () => {
      const res = await request(app.getHttpServer())
        .patch('/v1/member/me')
        .set(auth(registeredClosedBranch.token))
        .send({ address: '2 Second St', homeStoreCode: 'SHD-CLOSED' }) // the app re-sends the branch it holds
        .expect(200);
      expect(res.body.address).toBe('2 Second St');
      expect(res.body.homeStoreCode).toBe('SHD-CLOSED');
    });
  });
});
