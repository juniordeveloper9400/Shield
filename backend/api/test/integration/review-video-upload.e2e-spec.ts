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
import {
  PUBLIC_MEDIA_STORAGE,
  type PublicMediaStorage,
  type PublicMediaUpload,
} from '../../src/storage/public-media-storage';
import { adminUser } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

const BASE = 'https://media.example.test';

/** An in-memory stand-in for the Supabase bucket: records what would be signed and deleted. */
class FakePublicMediaStorage implements PublicMediaStorage {
  configured = true;
  failWith: string | null = null;
  deleted: string[] = [];
  signedKeys: string[] = [];

  isConfigured() {
    return this.configured;
  }
  async createUpload(input: { key: string }): Promise<PublicMediaUpload> {
    if (this.failWith) throw new Error(this.failWith);
    this.signedKeys.push(input.key);
    return {
      uploadUrl: `https://upload.example.test/${input.key}?token=fake`,
      publicUrl: `${BASE}/${input.key}`,
      method: 'PUT',
      headers: { 'x-upsert': 'false' },
      fields: { cacheControl: '31536000' },
      expiresInSeconds: 7200,
    };
  }
  keyFromPublicUrl(url: string) {
    return url.startsWith(`${BASE}/`) ? url.slice(BASE.length + 1) : null;
  }
  async delete(key: string) {
    this.deleted.push(key);
  }
}

describe('Customer review video upload (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let storage: FakePublicMediaStorage;
  let adminToken: string;
  let pharmacyToken: string;

  async function login(loginId: string, role: 'ADMIN' | 'PHARMACY') {
    await db.insert(adminUser).values({
      loginId,
      name: loginId,
      passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
      role,
    });
    const res = await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ loginId, password: 'correct-horse-battery-staple' })
      .expect(200);
    return res.body.accessToken as string;
  }

  beforeAll(async () => {
    db = createTestDb();
    storage = new FakePublicMediaStorage();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(REDIS_CLIENT)
      .useValue(createTestRedis())
      .overrideProvider(FIREBASE_VERIFIER)
      .useValue(new FakeFirebaseVerifier())
      .overrideProvider(PUBLIC_MEDIA_STORAGE)
      .useValue(storage)
      .compile();
    app = moduleRef.createNestApplication();
    await app.init();
    adminToken = await login('admin-upload@example.com', 'ADMIN');
    pharmacyToken = await login('pharmacy-upload@example.com', 'PHARMACY');
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    storage.configured = true;
    storage.failWith = null;
    storage.deleted = [];
    storage.signedKeys = [];
  });

  const uploadUrl = (token: string | null, body: unknown) => {
    const req = request(app.getHttpServer()).post('/v1/staff/catalogue/review-videos/upload-url');
    return (token ? req.set('Authorization', `Bearer ${token}`) : req).send(body as object);
  };

  it('requires staff auth, and only ADMIN / SUPERADMIN — not a pharmacy account', async () => {
    await uploadUrl(null, { contentType: 'video/mp4', size: 1000 }).expect(401);
    await uploadUrl(pharmacyToken, { contentType: 'video/mp4', size: 1000 }).expect(403);
  });

  it('hands out a signed upload for a random review-videos/ key, with what the browser must send', async () => {
    const res = await uploadUrl(adminToken, { contentType: 'video/mp4', size: 4_200_000 }).expect(201);
    expect(res.body.publicUrl).toMatch(new RegExp(`^${BASE}/review-videos/[0-9a-f-]{36}\\.mp4$`));
    expect(res.body.uploadUrl).toContain('review-videos/');
    expect(res.body.method).toBe('PUT');
    expect(res.body.headers).toEqual({ 'x-upsert': 'false' });
    expect(res.body.fields).toEqual({ cacheControl: '31536000' });
    expect(res.body.expiresInSeconds).toBe(7200);
    expect(storage.signedKeys).toHaveLength(1);
    expect(storage.signedKeys[0]).toMatch(/^review-videos\/[0-9a-f-]{36}\.mp4$/);

    const other = await uploadUrl(adminToken, { contentType: 'video/mp4', size: 4_200_000 }).expect(201);
    expect(other.body.publicUrl).not.toBe(res.body.publicUrl); // a new key every time — never overwrites a clip
  });

  it('picks the file extension from the content type', async () => {
    const webm = await uploadUrl(adminToken, { contentType: 'video/webm', size: 10 }).expect(201);
    expect(webm.body.publicUrl).toMatch(/\.webm$/);
    const mov = await uploadUrl(adminToken, { contentType: 'video/quicktime', size: 10 }).expect(201);
    expect(mov.body.publicUrl).toMatch(/\.mov$/);
  });

  it('refuses anything that is not a supported video, or is empty or too large', async () => {
    await uploadUrl(adminToken, { contentType: 'text/html', size: 1000 }).expect(400);
    await uploadUrl(adminToken, { contentType: 'application/x-msdownload', size: 1000 }).expect(400);
    await uploadUrl(adminToken, { contentType: 'video/mp4', size: 0 }).expect(400);
    await uploadUrl(adminToken, { contentType: 'video/mp4', size: 200 * 1024 * 1024 + 1 }).expect(400);
    await uploadUrl(adminToken, { contentType: 'video/mp4', size: 12.5 }).expect(400);
    await uploadUrl(adminToken, { contentType: 'video/mp4' }).expect(400);
    expect(storage.signedKeys).toHaveLength(0);
  });

  it('refuses a video over the configured limit (50 MB by default) before any upload starts', async () => {
    const limit = 50 * 1024 * 1024;
    const over = await uploadUrl(adminToken, { contentType: 'video/mp4', size: limit + 1 }).expect(400);
    expect(over.body.error.code).toBe('VIDEO_TOO_LARGE');
    expect(over.body.error.message).toMatch(/limit is 50 MB/);
    expect(storage.signedKeys).toHaveLength(0);

    await uploadUrl(adminToken, { contentType: 'video/mp4', size: limit }).expect(201); // the limit itself is fine
    expect(storage.signedKeys).toHaveLength(1);
  });

  it('says clearly that storage is not set up when Supabase is not configured', async () => {
    storage.configured = false;
    const res = await uploadUrl(adminToken, { contentType: 'video/mp4', size: 1000 }).expect(503);
    expect(res.body.error.code).toBe('STORAGE_NOT_CONFIGURED');
    expect(res.body.error.message).toMatch(/SUPABASE_URL/);
    expect(storage.signedKeys).toHaveLength(0);
  });

  it('passes on what went wrong when Supabase refuses, as a 502 the admin can act on', async () => {
    storage.failWith = 'Supabase can’t find the storage bucket “customer-reviews”.';
    const res = await uploadUrl(adminToken, { contentType: 'video/mp4', size: 1000 }).expect(502);
    expect(res.body.error.code).toBe('STORAGE_UNAVAILABLE');
    expect(res.body.error.message).toContain('customer-reviews');
  });

  it('deletes a stored clip by its public URL, but only ones under review-videos/ in our own bucket', async () => {
    const del = (token: string, url: string) =>
      request(app.getHttpServer())
        .post('/v1/staff/catalogue/review-videos/media/delete')
        .set('Authorization', `Bearer ${token}`)
        .send({ url });

    await del(pharmacyToken, `${BASE}/review-videos/x.mp4`).expect(403);

    expect((await del(adminToken, `${BASE}/review-videos/x.mp4`).expect(201)).body).toEqual({ deleted: true });
    expect(storage.deleted).toEqual(['review-videos/x.mp4']);

    // Not our prefix, not our bucket, not a stored file at all: ignored, never an error, never a delete.
    for (const url of [
      `${BASE}/prescriptions/x.jpg`,
      'https://www.youtube.com/shorts/dvLRFi4zBWk',
      'assets/reviews/tirur_store.mp4',
      'https://other.example.test/review-videos/x.mp4',
    ]) {
      expect((await del(adminToken, url).expect(201)).body).toEqual({ deleted: false });
    }
    expect(storage.deleted).toEqual(['review-videos/x.mp4']);
  });

  it('removes the file from storage when a clip is deleted, or when its video is replaced', async () => {
    const auth = { Authorization: `Bearer ${adminToken}` };
    const created = await request(app.getHttpServer())
      .post('/v1/staff/catalogue/review-videos')
      .set(auth)
      .send({ name: 'Uploaded', videoUrl: `${BASE}/review-videos/one.mp4` })
      .expect(201);

    // Editing something else leaves the file alone.
    await request(app.getHttpServer())
      .patch(`/v1/staff/catalogue/review-videos/${created.body.id}`)
      .set(auth)
      .send({ name: 'Uploaded (renamed)' })
      .expect(200);
    expect(storage.deleted).toEqual([]);

    // Replacing the video removes the old file.
    await request(app.getHttpServer())
      .patch(`/v1/staff/catalogue/review-videos/${created.body.id}`)
      .set(auth)
      .send({ videoUrl: `${BASE}/review-videos/two.mp4` })
      .expect(200);
    expect(storage.deleted).toEqual(['review-videos/one.mp4']);

    // Deleting the clip removes the current one.
    await request(app.getHttpServer())
      .delete(`/v1/staff/catalogue/review-videos/${created.body.id}`)
      .set(auth)
      .expect(200);
    expect(storage.deleted).toEqual(['review-videos/one.mp4', 'review-videos/two.mp4']);
  });

  it('still deletes the clip when removing its file fails — an orphaned file must not block the admin', async () => {
    const auth = { Authorization: `Bearer ${adminToken}` };
    const created = await request(app.getHttpServer())
      .post('/v1/staff/catalogue/review-videos')
      .set(auth)
      .send({ name: 'Flaky', videoUrl: `${BASE}/review-videos/flaky.mp4` })
      .expect(201);
    const original = storage.delete.bind(storage);
    storage.delete = async () => {
      throw new Error('R2 is down');
    };
    try {
      await request(app.getHttpServer())
        .delete(`/v1/staff/catalogue/review-videos/${created.body.id}`)
        .set(auth)
        .expect(200);
    } finally {
      storage.delete = original;
    }
    const remaining = await request(app.getHttpServer()).get('/v1/staff/catalogue/review-videos').set(auth).expect(200);
    expect(remaining.body.map((v: { name: string }) => v.name)).not.toContain('Flaky');
  });
});
