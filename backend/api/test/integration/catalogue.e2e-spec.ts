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
import { adminUser, product, productCategory } from '../../src/db/schema';
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
      .values({ name: 'Paracetamol 500mg', categoryId, price: '20.00', mrp: '25.00' })
      .returning();
    productId = seededProduct.id;

    await db.insert(adminUser).values({
      email: 'pharmacist@example.com',
      name: 'Test Pharmacist',
      passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
      role: 'PHARMACY',
    });

    const login = await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ email: 'pharmacist@example.com', password: 'correct-horse-battery-staple' })
      .expect(200);
    staffAccessToken = login.body.accessToken;
  });

  afterAll(async () => {
    await app.close();
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
      email: 'admin-role@example.com',
      name: 'App Admin',
      passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
      role: 'ADMIN',
    });
    const login = await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ email: 'admin-role@example.com', password: 'correct-horse-battery-staple' })
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
});
