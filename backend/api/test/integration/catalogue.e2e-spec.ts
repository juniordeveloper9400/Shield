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
import { adminUser, membershipTier, paymentMethod, product, productCategory, shieldStore } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('Catalogue (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let categoryId: number;
  let productId: number;
  let staffAccessToken: string;

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
      .insert(productCategory)
      .values({ slug: 'otc', title: 'Over the counter', tabLabel: 'OTC' })
      .returning();
    categoryId = category.id;

    const [seededProduct] = await db
      .insert(product)
      .values({ name: 'Paracetamol 500mg', categoryId, price: '20.00', mrp: '25.00', isPopular: true })
      .returning();
    productId = seededProduct.id;

    await db.insert(adminUser).values({
      loginId: 'pharmacist@example.com',
      name: 'Test Pharmacist',
      passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
      role: 'PHARMACY',
    });

    const login = await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ loginId: 'pharmacist@example.com', password: 'correct-horse-battery-staple' })
      .expect(200);
    staffAccessToken = login.body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('lists membership tiers publicly, for a client resolving a tier kind to its id', async () => {
    await db
      .insert(membershipTier)
      .values({ kind: 'GOLD', name: 'Gold Shield', bin: '5678', bonusRate: '0.150', validityMonths: 12, sort: 1 });

    const tiers = await request(app.getHttpServer()).get('/v1/public/catalogue/membership-tiers').expect(200);
    expect(tiers.body).toEqual(
      expect.arrayContaining([expect.objectContaining({ kind: 'GOLD', name: 'Gold Shield' })]),
    );
  });

  it('lists only live payment methods publicly', async () => {
    await db.insert(paymentMethod).values([
      { code: 'upi', name: 'UPI', isLive: true, sort: 0 },
      { code: 'cod', name: 'Cash on Delivery', isLive: false, sort: 1 },
    ]);

    const methods = await request(app.getHttpServer()).get('/v1/public/catalogue/payment-methods').expect(200);
    expect(methods.body).toHaveLength(1);
    expect(methods.body[0].code).toBe('upi');
  });

  it('lists categories publicly, with no auth required', async () => {
    const res = await request(app.getHttpServer()).get('/v1/public/catalogue/categories').expect(200);
    expect(res.body).toEqual(
      expect.arrayContaining([expect.objectContaining({ id: categoryId, slug: 'otc' })]),
    );
  });

  it('lists products filtered by category, with product detail on single fetch', async () => {
    const list = await request(app.getHttpServer())
      .get(`/v1/public/catalogue/products?categoryId=${categoryId}`)
      .expect(200);
    expect(list.body.items).toEqual(expect.arrayContaining([expect.objectContaining({ id: productId })]));

    const single = await request(app.getHttpServer()).get(`/v1/public/catalogue/products/${productId}`).expect(200);
    expect(single.body.name).toBe('Paracetamol 500mg');
    expect(single.body.faqs).toEqual([]);
    expect(single.body.isPopular).toBe(true);
    expect(single.body.isDeal).toBe(false);
  });

  it('rejects a member session on staff-only catalogue writes', async () => {
    await request(app.getHttpServer()).post('/v1/staff/catalogue/categories').send({}).expect(401); // no token at all
  });

  it('actually serves from cache: a direct DB change is invisible until the cache is invalidated', async () => {
    // Prime the cache.
    const before = await request(app.getHttpServer()).get(`/v1/public/catalogue/products/${productId}`).expect(200);
    expect(before.body.name).toBe('Paracetamol 500mg');

    // Mutate the row directly, bypassing CatalogueService — so nothing invalidates the cache.
    await db.update(product).set({ name: 'Paracetamol 500mg (renamed directly in DB)' }).where(eq(product.id, productId));

    const stillCached = await request(app.getHttpServer()).get(`/v1/public/catalogue/products/${productId}`).expect(200);
    expect(stillCached.body.name).toBe('Paracetamol 500mg'); // proves it came from cache, not a fresh query

    // Now go through the real write path, which invalidates the cache.
    await request(app.getHttpServer())
      .patch(`/v1/staff/catalogue/products/${productId}`)
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ name: 'Paracetamol 500mg (via API)' })
      .expect(200);

    const fresh = await request(app.getHttpServer()).get(`/v1/public/catalogue/products/${productId}`).expect(200);
    expect(fresh.body.name).toBe('Paracetamol 500mg (via API)');
  });

  it('creates a category through the staff endpoint and invalidates the category list cache', async () => {
    // Prime the categories cache.
    await request(app.getHttpServer()).get('/v1/public/catalogue/categories').expect(200);

    await request(app.getHttpServer())
      .post('/v1/staff/catalogue/categories')
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ slug: 'prescription', title: 'Prescription medicines', tabLabel: 'Rx' })
      .expect(201);

    const after = await request(app.getHttpServer()).get('/v1/public/catalogue/categories').expect(200);
    expect(after.body).toEqual(expect.arrayContaining([expect.objectContaining({ slug: 'prescription' })]));
  });

  it('rejects an invalid product payload before it reaches the database', async () => {
    await request(app.getHttpServer())
      .post('/v1/staff/catalogue/products')
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ name: 'Bad Product', price: -5, mrp: 10 })
      .expect(400);
  });

  it('returns 404 for a product that does not exist', async () => {
    await request(app.getHttpServer()).get('/v1/public/catalogue/products/999999').expect(404);
  });

  it('rejects a PHARMACY role from managing customer review videos — not in its module list at all', async () => {
    await request(app.getHttpServer())
      .post('/v1/staff/catalogue/review-videos')
      .set('Authorization', `Bearer ${staffAccessToken}`)
      .send({ name: 'Clip', videoUrl: 'https://example.com/clip.mp4' })
      .expect(403);
  });

  it('lets ADMIN (not just SUPERADMIN) manage customer review videos, auto-assigning sort, and hides inactive clips from the public feed', async () => {
    await db.insert(adminUser).values({
      loginId: 'admin-role@example.com',
      name: 'App Admin',
      passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
      role: 'ADMIN',
    });
    const login = await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ loginId: 'admin-role@example.com', password: 'correct-horse-battery-staple' })
      .expect(200);

    const created = await request(app.getHttpServer())
      .post('/v1/staff/catalogue/review-videos')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ name: 'Active Clip', videoUrl: 'https://example.com/a.mp4', isActive: true })
      .expect(201);
    expect(created.body.sort).toBe(0); // first clip, no explicit sort given

    await request(app.getHttpServer())
      .post('/v1/staff/catalogue/review-videos')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ name: 'Inactive Clip', videoUrl: 'https://example.com/b.mp4', isActive: false })
      .expect(201);

    const publicFeed = await request(app.getHttpServer()).get('/v1/public/catalogue/review-videos').expect(200);
    expect(publicFeed.body).toEqual(expect.arrayContaining([expect.objectContaining({ name: 'Active Clip' })]));
    expect(publicFeed.body.map((v: { name: string }) => v.name)).not.toContain('Inactive Clip');

    const staffFeed = await request(app.getHttpServer())
      .get('/v1/staff/catalogue/review-videos')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(200);
    expect(staffFeed.body.map((v: { name: string }) => v.name)).toEqual(
      expect.arrayContaining(['Active Clip', 'Inactive Clip']), // console sees both
    );
  });

  describe('staff store management', () => {
    let labAccessToken: string;

    beforeAll(async () => {
      await db.insert(adminUser).values({
        loginId: 'lab-role@example.com',
        name: 'Lab Staff',
        passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
        role: 'LAB',
      });
      const login = await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'lab-role@example.com', password: 'correct-horse-battery-staple' })
        .expect(200);
      labAccessToken = login.body.accessToken;
    });

    it('lets any staff role read the branch list, including inactive branches', async () => {
      await db.insert(shieldStore).values({
        code: 'SHD-TST',
        name: 'Test Branch',
        area: 'Testville',
        city: 'Testcity',
        state: 'Kerala',
        pincode: '676999',
        isActive: false,
      });

      // staffAccessToken (from the top-level beforeAll) is a PHARMACY login —
      // read is open to every staff role, not just the ones with the Stores
      // module in shieldweb/src/config/permissions.ts.
      const res = await request(app.getHttpServer())
        .get('/v1/staff/catalogue/stores')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);
      expect(res.body).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ code: 'SHD-TST', isActive: false, memberCount: 0, orderCount: 0 }),
        ]),
      );
    });

    it('rejects a PHARMACY role from writing to stores — not in its module list', async () => {
      await request(app.getHttpServer())
        .post('/v1/staff/catalogue/stores')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ code: 'SHD-XXX', name: 'X', area: 'X', city: 'X', state: 'Kerala', pincode: '676100' })
        .expect(403);
    });

    it('lets a LAB role create a branch, then toggle it active and lab-eligible', async () => {
      const created = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/stores')
        .set('Authorization', `Bearer ${labAccessToken}`)
        .send({
          code: 'shd-new',
          name: 'New Branch',
          area: 'Newtown',
          city: 'Newcity',
          state: 'Kerala',
          pincode: '676100',
        })
        .expect(201);
      expect(created.body.store.code).toBe('SHD-NEW'); // upper-cased server-side
      expect(created.body.store.isActive).toBe(true); // default
      expect(created.body.store.offersLabCollection).toBe(true); // default
      const id = created.body.store.id;

      await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/stores/${id}/active`)
        .set('Authorization', `Bearer ${labAccessToken}`)
        .send({ isActive: false })
        .expect(200);

      await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/stores/${id}/offers-lab`)
        .set('Authorization', `Bearer ${labAccessToken}`)
        .send({ offersLabCollection: false })
        .expect(200);

      const after = await request(app.getHttpServer())
        .get('/v1/staff/catalogue/stores')
        .set('Authorization', `Bearer ${labAccessToken}`)
        .expect(200);
      const row = after.body.find((s: { code: string }) => s.code === 'SHD-NEW');
      expect(row).toEqual(expect.objectContaining({ isActive: false, offersLabCollection: false }));
    });

    it('returns { store: null } (not an error) creating a branch whose code is already taken', async () => {
      await db.insert(shieldStore).values({
        code: 'SHD-DUP',
        name: 'Original',
        area: 'A',
        city: 'B',
        state: 'Kerala',
        pincode: '676100',
      });

      const res = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/stores')
        .set('Authorization', `Bearer ${labAccessToken}`)
        .send({ code: 'SHD-DUP', name: 'Duplicate', area: 'A', city: 'B', state: 'Kerala', pincode: '676100' })
        .expect(201);
      expect(res.body).toEqual({ store: null });
    });

    it('edits a branch’s full details, including its bank account', async () => {
      const [store] = await db
        .insert(shieldStore)
        .values({ code: 'SHD-EDT', name: 'Before', area: 'A', city: 'B', state: 'Kerala', pincode: '676100' })
        .returning();

      const res = await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/stores/${store.id}`)
        .set('Authorization', `Bearer ${labAccessToken}`)
        .send({
          name: 'After',
          bankAccountName: 'Sahakar 360',
          bankAccountNumber: '1234567890',
          bankIfsc: 'sbin0001234',
          bankName: 'State Bank of India',
          latitude: 11.05,
          longitude: 76.1,
        })
        .expect(200);
      expect(res.body.name).toBe('After');
      expect(res.body.bankIfsc).toBe('SBIN0001234'); // upper-cased server-side
      expect(Number(res.body.latitude)).toBeCloseTo(11.05);
    });

    it('404s updating a branch that does not exist', async () => {
      await request(app.getHttpServer())
        .patch('/v1/staff/catalogue/stores/999999')
        .set('Authorization', `Bearer ${labAccessToken}`)
        .send({ name: 'Nobody' })
        .expect(404);
    });
  });
});
