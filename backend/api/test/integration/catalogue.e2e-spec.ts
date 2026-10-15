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
import {
  adminUser,
  homeBanner,
  membershipTier,
  paymentMethod,
  product,
  productCategory,
  productSubcategory,
  shieldStore,
} from '../../src/db/schema';
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

    await db.insert(adminUser).values({
      loginId: 'superadmin@example.com',
      name: 'Test Super Admin',
      passwordHash: await hash('correct-horse-battery-staple', 4),
      role: 'SUPERADMIN',
    });
    const superAdminLogin = await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ loginId: 'superadmin@example.com', password: 'correct-horse-battery-staple' })
      .expect(200);
    superAdminToken = superAdminLogin.body.accessToken;
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

    // Categories & banners share one permission module key ('banners') —
    // SUPERADMIN/ADMIN only, not the PHARMACY staffAccessToken used
    // elsewhere in this file.
    await request(app.getHttpServer())
      .post('/v1/staff/catalogue/categories')
      .set('Authorization', `Bearer ${superAdminToken}`)
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

  describe('banners (migration 0069: one placement per strip)', () => {
    it('defaults to the home placement, and keeps a lab banner out of it', async () => {
      await db.insert(homeBanner).values({ title: 'Home sale', image: 'home.jpg', isActive: true, sort: 0 });
      await db
        .insert(homeBanner)
        .values({ title: 'Lab offer', image: 'lab.jpg', isActive: true, sort: 0, placement: 'lab' });

      const home = await request(app.getHttpServer()).get('/v1/public/catalogue/banners').expect(200);
      expect(home.body.map((b: { title: string }) => b.title)).toEqual(['Home sale']);

      const lab = await request(app.getHttpServer())
        .get('/v1/public/catalogue/banners')
        .query({ placement: 'lab' })
        .expect(200);
      expect(lab.body.map((b: { title: string }) => b.title)).toEqual(['Lab offer']);
    });

    it('an inactive banner never shows on either placement', async () => {
      await db
        .insert(homeBanner)
        .values({ title: 'Hidden lab banner', image: 'x.jpg', isActive: false, sort: 1, placement: 'lab' });

      const lab = await request(app.getHttpServer())
        .get('/v1/public/catalogue/banners')
        .query({ placement: 'lab' })
        .expect(200);
      expect(lab.body.map((b: { title: string }) => b.title)).not.toContain('Hidden lab banner');
    });
  });

  describe('console banner management (SUPERADMIN/ADMIN only)', () => {
    it('rejects a PHARMACY login — banners is not in that role\'s module list', async () => {
      await request(app.getHttpServer())
        .get('/v1/staff/catalogue/banners')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(403);
      await request(app.getHttpServer())
        .post('/v1/staff/catalogue/banners')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ title: 'Nope' })
        .expect(403);
    });

    it('lists every banner on a placement, active and inactive, in sort order', async () => {
      await db.insert(homeBanner).values({ title: 'Console A', image: 'a.jpg', isActive: true, sort: 1, placement: 'console-test' });
      await db.insert(homeBanner).values({ title: 'Console B (off)', image: 'b.jpg', isActive: false, sort: 0, placement: 'console-test' });

      const res = await request(app.getHttpServer())
        .get('/v1/staff/catalogue/banners')
        .query({ placement: 'console-test' })
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);

      expect(res.body.map((b: { title: string }) => b.title)).toEqual(['Console B (off)', 'Console A']);
    });

    it('creates a banner, appending after the current last one on its placement when sort is omitted', async () => {
      await db.insert(homeBanner).values({ title: 'Existing', image: 'x.jpg', sort: 4, placement: 'append-test' });

      const created = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/banners')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ placement: 'append-test', title: 'New one', image: 'new.jpg' })
        .expect(201);

      expect(created.body.sort).toBe(5);
      expect(created.body.isActive).toBe(true); // schema default
    });

    it('updates, re-sorts, deactivates and deletes a banner', async () => {
      const [created] = await db
        .insert(homeBanner)
        .values({ title: 'Original', image: 'o.jpg', sort: 0, placement: 'crud-test' })
        .returning();

      const updated = await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/banners/${created.id}`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ title: 'Renamed', subtitle: '', image: 'o.jpg', cta: '', target: '', isActive: true, sort: 0 })
        .expect(200);
      expect(updated.body.title).toBe('Renamed');

      await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/banners/${created.id}/sort`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ sort: 9 })
        .expect(200);

      const deactivated = await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/banners/${created.id}/active`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ isActive: false })
        .expect(200);
      expect(deactivated.body.isActive).toBe(false);
      expect(deactivated.body.sort).toBe(9); // the sort change above stuck

      await request(app.getHttpServer())
        .delete(`/v1/staff/catalogue/banners/${created.id}`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);

      const afterDelete = await request(app.getHttpServer())
        .get('/v1/staff/catalogue/banners')
        .query({ placement: 'crud-test' })
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);
      expect(afterDelete.body).toEqual([]);
    });

    it('404s updating, sorting, activating or deleting a banner that does not exist', async () => {
      await request(app.getHttpServer())
        .patch('/v1/staff/catalogue/banners/999999')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ title: 'x', subtitle: '', image: '', cta: '', target: '', isActive: true, sort: 0 })
        .expect(404);
      await request(app.getHttpServer())
        .delete('/v1/staff/catalogue/banners/999999')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(404);
    });
  });

  describe('console category & subcategory management (SUPERADMIN/ADMIN only)', () => {
    it('rejects a PHARMACY login', async () => {
      await request(app.getHttpServer())
        .get('/v1/staff/catalogue/categories')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(403);
    });

    it('lists every category active or not, each with its subcategories nested', async () => {
      const [cat] = await db
        .insert(productCategory)
        .values({ slug: 'console-cat-test', title: 'Console Cat', tabLabel: 'CC', isActive: false, sort: 0 })
        .returning();
      await db.insert(productSubcategory).values({ categoryId: cat.id, label: 'Sub A', sort: 1 });
      await db.insert(productSubcategory).values({ categoryId: cat.id, label: 'Sub B', sort: 0 });

      const res = await request(app.getHttpServer())
        .get('/v1/staff/catalogue/categories')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);

      const group = res.body.find((g: { slug: string }) => g.slug === 'console-cat-test');
      expect(group.isActive).toBe(false); // shows up despite being inactive
      expect(group.subcategories.map((s: { label: string }) => s.label)).toEqual(['Sub B', 'Sub A']);
    });

    it('refuses a duplicate slug, without a 500', async () => {
      await db.insert(productCategory).values({ slug: 'dup-slug-test', title: 'First', tabLabel: 'F' });

      const res = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/categories')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ slug: 'dup-slug-test', title: 'Second', tabLabel: 'S' })
        .expect(201);
      expect(res.body).toEqual({ category: null });
    });

    it("updating a category never changes its slug, even if one is sent", async () => {
      const [cat] = await db
        .insert(productCategory)
        .values({ slug: 'immutable-slug-test', title: 'Before', tabLabel: 'B' })
        .returning();

      const res = await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/categories/${cat.id}`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ slug: 'hijacked-slug', title: 'After', tabLabel: 'A' })
        .expect(200);

      expect(res.body.slug).toBe('immutable-slug-test');
      expect(res.body.title).toBe('After');
    });

    it('sets active and sort independently of a full update', async () => {
      const [cat] = await db
        .insert(productCategory)
        .values({ slug: 'active-sort-test', title: 'T', tabLabel: 'T', isActive: true, sort: 0 })
        .returning();

      await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/categories/${cat.id}/active`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ isActive: false })
        .expect(200);
      const sorted = await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/categories/${cat.id}/sort`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ sort: 7 })
        .expect(200);

      expect(sorted.body.isActive).toBe(false); // the earlier deactivation stuck
      expect(sorted.body.sort).toBe(7);
    });

    it('creates, updates and deletes a subcategory, clearing any product filed under it', async () => {
      const [cat] = await db
        .insert(productCategory)
        .values({ slug: 'subcat-crud-test', title: 'T', tabLabel: 'T' })
        .returning();

      const created = await request(app.getHttpServer())
        .post(`/v1/staff/catalogue/categories/${cat.id}/subcategories`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ label: 'New sub' })
        .expect(201);
      const subId = created.body.id;

      const [filedProduct] = await db
        .insert(product)
        .values({ name: 'Filed under sub', categoryId: cat.id, subcategoryId: subId, price: '10', mrp: '10' })
        .returning();

      await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/subcategories/${subId}`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ label: 'Renamed sub' })
        .expect(200);

      await request(app.getHttpServer())
        .delete(`/v1/staff/catalogue/subcategories/${subId}`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);

      const [afterDelete] = await db.select().from(product).where(eq(product.id, filedProduct.id));
      expect(afterDelete.subcategoryId).toBeNull();
    });

    it('404s updating or deleting a subcategory that does not exist', async () => {
      await request(app.getHttpServer())
        .patch('/v1/staff/catalogue/subcategories/999999')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ label: 'x' })
        .expect(404);
      await request(app.getHttpServer())
        .delete('/v1/staff/catalogue/subcategories/999999')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(404);
    });
  });

  describe('public stores list', () => {
    let memberAccessToken: string;

    beforeAll(async () => {
      firebase.register('catalogue-member-token', { uid: 'catalogue-member-uid', phoneNumber: '+919700000055' });
      const register = await request(app.getHttpServer())
        .post('/v1/member/auth/register')
        .send({ idToken: 'catalogue-member-token', name: 'Catalogue Member' })
        .expect(200);
      memberAccessToken = register.body.accessToken;
    });

    it('never includes bank account fields, even though the row has them', async () => {
      await db.insert(shieldStore).values({
        code: 'SHD-PUB',
        name: 'Public Branch',
        area: 'A',
        city: 'A',
        state: 'Kerala',
        pincode: '676001',
        isActive: true,
        bankAccountName: 'Sahakar 360',
        bankAccountNumber: '1234567890',
        bankIfsc: 'SBIN0001234',
        bankName: 'State Bank of India',
      });

      const res = await request(app.getHttpServer()).get('/v1/public/catalogue/stores').expect(200);
      const listed = res.body.find((s: { code: string }) => s.code === 'SHD-PUB');
      expect(listed).toBeDefined();
      expect(listed).not.toHaveProperty('bankAccountName');
      expect(listed).not.toHaveProperty('bankAccountNumber');
      expect(listed).not.toHaveProperty('bankIfsc');
      expect(listed).not.toHaveProperty('bankName');
    });

    it("gives a single active branch's bank details by its code, to a signed-in member", async () => {
      await db.insert(shieldStore).values({
        code: 'SHD-BANK',
        name: 'Bank Details Branch',
        area: 'A',
        city: 'A',
        state: 'Kerala',
        pincode: '676001',
        isActive: true,
        bankAccountName: 'Sahakar 360',
        bankAccountNumber: '1234567890',
        bankIfsc: 'SBIN0001234',
        bankName: 'State Bank of India',
      });

      const res = await request(app.getHttpServer())
        .get('/v1/public/catalogue/stores/SHD-BANK/bank-details')
        .set('Authorization', `Bearer ${memberAccessToken}`)
        .expect(200);
      expect(res.body).toEqual({
        bankAccountName: 'Sahakar 360',
        bankAccountNumber: '1234567890',
        bankIfsc: 'SBIN0001234',
        bankName: 'State Bank of India',
      });
    });

    it('rejects an unauthenticated request — code alone must not be enough to loop every branch’s bank details', async () => {
      await request(app.getHttpServer()).get('/v1/public/catalogue/stores/SHD-BANK/bank-details').expect(401);
    });

    it('404s for an unknown code, and for an inactive branch', async () => {
      await db.insert(shieldStore).values({
        code: 'SHD-OFF',
        name: 'Inactive Branch',
        area: 'A',
        city: 'A',
        state: 'Kerala',
        pincode: '676001',
        isActive: false,
        bankAccountNumber: '9999999999',
      });

      await request(app.getHttpServer())
        .get('/v1/public/catalogue/stores/SHD-NOPE/bank-details')
        .set('Authorization', `Bearer ${memberAccessToken}`)
        .expect(404);
      await request(app.getHttpServer())
        .get('/v1/public/catalogue/stores/SHD-OFF/bank-details')
        .set('Authorization', `Bearer ${memberAccessToken}`)
        .expect(404);
    });
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

    it('derives offersLabCollection from storeType — never trusts a client-sent value for it', async () => {
      const pharmacy = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/stores')
        .set('Authorization', `Bearer ${labAccessToken}`)
        .send({
          code: 'shd-pha',
          name: 'Pharmacy Only',
          area: 'A',
          city: 'B',
          state: 'Kerala',
          pincode: '676100',
          storeType: 'PHARMACY',
          // A lying client sending true anyway must still be ignored.
          offersLabCollection: true,
        })
        .expect(201);
      expect(pharmacy.body.store.storeType).toBe('PHARMACY');
      expect(pharmacy.body.store.offersLabCollection).toBe(false);

      const lab = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/stores')
        .set('Authorization', `Bearer ${labAccessToken}`)
        .send({ code: 'shd-lab', name: 'Lab Only', area: 'A', city: 'B', state: 'Kerala', pincode: '676100', storeType: 'LAB' })
        .expect(201);
      expect(lab.body.store.storeType).toBe('LAB');
      expect(lab.body.store.offersLabCollection).toBe(true);

      // No storeType sent at all — defaults to PHARMACY_LAB, same as every
      // branch before this existed.
      const defaulted = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/stores')
        .set('Authorization', `Bearer ${labAccessToken}`)
        .send({ code: 'shd-def', name: 'Default', area: 'A', city: 'B', state: 'Kerala', pincode: '676100' })
        .expect(201);
      expect(defaulted.body.store.storeType).toBe('PHARMACY_LAB');
      expect(defaulted.body.store.offersLabCollection).toBe(true);

      // Editing an existing branch's storeType re-derives the flag too.
      const toPharmacy = await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/stores/${lab.body.store.id}`)
        .set('Authorization', `Bearer ${labAccessToken}`)
        .send({ storeType: 'PHARMACY' })
        .expect(200);
      expect(toPharmacy.body.offersLabCollection).toBe(false);

      // A patch that never mentions storeType leaves both fields alone.
      const untouched = await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/stores/${pharmacy.body.store.id}`)
        .set('Authorization', `Bearer ${labAccessToken}`)
        .send({ name: 'Pharmacy Only (renamed)' })
        .expect(200);
      expect(untouched.body.storeType).toBe('PHARMACY');
      expect(untouched.body.offersLabCollection).toBe(false);
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

  describe('staff product management (its own fresh fixture — the seeded productId above is shared and heavily reused elsewhere)', () => {
    let staffCategoryId: number;

    beforeAll(async () => {
      const [cat] = await db
        .insert(productCategory)
        .values({ slug: 'wellness', title: 'Wellness', tabLabel: 'Wellness' })
        .returning();
      staffCategoryId = cat.id;
    });

    it('lists every product for staff regardless of status, with category/subcategory names joined in', async () => {
      const [sub] = await db
        .insert(productSubcategory)
        .values({ categoryId: staffCategoryId, label: 'Vitamins' })
        .returning();
      const [inactive] = await db
        .insert(product)
        .values({ name: 'Discontinued Syrup', categoryId: staffCategoryId, subcategoryId: sub.id, status: 'INACTIVE' })
        .returning();

      const res = await request(app.getHttpServer())
        .get('/v1/staff/catalogue/products')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);

      expect(res.body).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            id: inactive.id,
            status: 'INACTIVE',
            categorySlug: 'wellness',
            subcategoryLabel: 'Vitamins',
          }),
        ]),
      );
    });

    it('creates a product by category slug, with its detail page, FAQs and image gallery in one call', async () => {
      const created = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/products')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({
          name: 'Vitamin D3 Drops',
          categorySlug: 'wellness',
          price: 199,
          mrp: 249,
          image: 'data:image/png;base64,primary',
          extraImages: ['data:image/png;base64,extra1'],
          detail: {
            description: 'Daily vitamin D supplement.',
            highlights: 'Boosts immunity\nSupports bone health',
            faqs: [{ question: 'How much per day?', answer: 'One drop daily.' }],
          },
        })
        .expect(201);
      expect(created.body.status).toBe('ACTIVE');

      const detail = await request(app.getHttpServer())
        .get(`/v1/staff/catalogue/products/${created.body.id}/detail`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);
      expect(detail.body).toMatchObject({
        description: 'Daily vitamin D supplement.',
        highlights: 'Boosts immunity\nSupports bone health',
        hasDetail: true,
        faqs: [{ question: 'How much per day?', answer: 'One drop daily.' }],
        extraImages: ['data:image/png;base64,extra1'],
      });

      const pub = await request(app.getHttpServer())
        .get(`/v1/public/catalogue/products/${created.body.id}`)
        .expect(200);
      expect(pub.body.images).toEqual(['data:image/png;base64,primary', 'data:image/png;base64,extra1']);

      // Patching price, stock and extraImages through PATCH /v1/staff/catalogue/products/:id
      await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/products/${created.body.id}`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ price: 299, extraImages: ['data:image/png;base64,extra2', 'data:image/png;base64,extra3'] })
        .expect(200);

      const pubUpdated = await request(app.getHttpServer())
        .get(`/v1/public/catalogue/products/${created.body.id}`)
        .expect(200);
      expect(pubUpdated.body.images).toEqual([
        'data:image/png;base64,primary',
        'data:image/png;base64,extra2',
        'data:image/png;base64,extra3',
      ]);
    });

    it('rejects an unknown category slug', async () => {
      await request(app.getHttpServer())
        .post('/v1/staff/catalogue/products')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: 'Mystery Item', categorySlug: 'no-such-category', price: 10, mrp: 10 })
        .expect(400);
    });

    it('rewrites a product in full via PUT — core fields, detail and gallery all replaced together', async () => {
      const created = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/products')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: 'Zinc Tablets', categorySlug: 'wellness', price: 50, mrp: 60, detail: { description: 'Original.' } })
        .expect(201);

      await request(app.getHttpServer())
        .put(`/v1/staff/catalogue/products/${created.body.id}`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({
          name: 'Zinc Tablets (50mg)',
          categorySlug: 'wellness',
          price: 55,
          mrp: 65,
          detail: { description: 'Replaced.' },
        })
        .expect(200);

      const detail = await request(app.getHttpServer())
        .get(`/v1/staff/catalogue/products/${created.body.id}/detail`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);
      expect(detail.body.description).toBe('Replaced.');
    });

    it('sets a product inactive, then flips its home-feed sections', async () => {
      const created = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/products')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: 'Omega 3 Capsules', categorySlug: 'wellness', price: 300, mrp: 350 })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/products/${created.body.id}/status`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ status: 'inactive' })
        .expect(200);

      const sections = await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/products/${created.body.id}/sections`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ isPopular: true, isDeal: true, isOfferOfDay: false })
        .expect(200);
      expect(sections.body).toMatchObject({ status: 'INACTIVE', isPopular: true, isDeal: true, isOfferOfDay: false });
    });

    it('a home-feed section set with a future "until" still shows for members', async () => {
      const created = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/products')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: 'Multivitamin Tablets', categorySlug: 'wellness', price: 220, mrp: 260 })
        .expect(201);
      const futureIso = new Date(Date.now() + 60_000).toISOString();

      await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/products/${created.body.id}/sections`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ isPopular: true, isDeal: false, isOfferOfDay: false, popularUntil: futureIso })
        .expect(200);

      const member = await request(app.getHttpServer())
        .get(`/v1/public/catalogue/products/${created.body.id}`)
        .expect(200);
      expect(member.body.isPopular).toBe(true);
    });

    it('a home-feed section set with a past "until" no longer shows for members, though the console still sees the raw flag', async () => {
      const created = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/products')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: 'Electrolyte Powder', categorySlug: 'wellness', price: 90, mrp: 110 })
        .expect(201);
      const pastIso = new Date(Date.now() - 60_000).toISOString();

      await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/products/${created.body.id}/sections`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ isPopular: true, isDeal: false, isOfferOfDay: false, popularUntil: pastIso })
        .expect(200);

      const member = await request(app.getHttpServer())
        .get(`/v1/public/catalogue/products/${created.body.id}`)
        .expect(200);
      expect(member.body.isPopular).toBe(false);

      const staffList = await request(app.getHttpServer())
        .get('/v1/staff/catalogue/products')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);
      const staffRow = staffList.body.find((p: { id: number }) => p.id === created.body.id);
      expect(staffRow.isPopular).toBe(true);
      expect(staffRow.popularUntil).toBeTruthy();
    });

    it('turning a section off clears its "until" so turning it back on later starts fresh', async () => {
      const created = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/products')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: 'Herbal Tea Bags', categorySlug: 'wellness', price: 150, mrp: 180 })
        .expect(201);
      const futureIso = new Date(Date.now() + 60_000).toISOString();

      await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/products/${created.body.id}/sections`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ isPopular: true, isDeal: false, isOfferOfDay: false, popularUntil: futureIso })
        .expect(200);

      const turnedOff = await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/products/${created.body.id}/sections`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ isPopular: false, isDeal: false, isOfferOfDay: false })
        .expect(200);
      expect(turnedOff.body.popularUntil).toBeNull();
    });

    it('deletes a product, cascading its detail/FAQ/gallery rows with it', async () => {
      const created = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/products')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: 'Throwaway Item', categorySlug: 'wellness', price: 1, mrp: 1 })
        .expect(201);

      await request(app.getHttpServer())
        .delete(`/v1/staff/catalogue/products/${created.body.id}`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);

      await request(app.getHttpServer())
        .get(`/v1/staff/catalogue/products/${created.body.id}/detail`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(404);
    });

    it('registers a brand case-insensitively (no duplicate on a second, differently-cased name), renames and deletes it', async () => {
      const first = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/brands')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: 'Cetaphil' })
        .expect(201);

      const second = await request(app.getHttpServer())
        .post('/v1/staff/catalogue/brands')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: 'cetaphil' })
        .expect(201);
      expect(second.body.id).toBe(first.body.id);

      const renamed = await request(app.getHttpServer())
        .patch(`/v1/staff/catalogue/brands/${first.body.id}`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .send({ name: 'Cetaphil Dermatology' })
        .expect(200);
      expect(renamed.body.name).toBe('Cetaphil Dermatology');

      await request(app.getHttpServer())
        .delete(`/v1/staff/catalogue/brands/${first.body.id}`)
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);

      const list = await request(app.getHttpServer())
        .get('/v1/staff/catalogue/brands')
        .set('Authorization', `Bearer ${staffAccessToken}`)
        .expect(200);
      expect(list.body).not.toEqual(expect.arrayContaining([expect.objectContaining({ id: first.body.id })]));
    });

    it('rejects a LAB role from managing products — not in its module list', async () => {
      await db.insert(adminUser).values({
        loginId: 'lab-products-check@example.com',
        name: 'Lab Staff',
        passwordHash: await hash('correct-horse-battery-staple', 4),
        role: 'LAB',
      });
      const login = await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'lab-products-check@example.com', password: 'correct-horse-battery-staple' })
        .expect(200);

      await request(app.getHttpServer())
        .get('/v1/staff/catalogue/products')
        .set('Authorization', `Bearer ${login.body.accessToken}`)
        .expect(403);
    });
  });
});
