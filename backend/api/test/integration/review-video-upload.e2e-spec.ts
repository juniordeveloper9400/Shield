process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { createHash } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { hash } from 'bcryptjs';
import request, { type Response } from 'supertest';
import { AppModule } from '../../src/app.module';
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { DRIZZLE } from '../../src/db/client';
import { adminUser } from '../../src/db/schema';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

const binary = (response: Response, callback: (error: Error | null, body: Buffer) => void) => {
  const chunks: Buffer[] = [];
  response.on('data', (chunk) => chunks.push(Buffer.from(chunk)));
  response.on('end', () => callback(null, Buffer.concat(chunks)));
};

describe('Neon customer review video upload and playback (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let adminToken: string;
  let pharmacyToken: string;

  async function login(loginId: string, role: 'ADMIN' | 'PHARMACY') {
    await db.insert(adminUser).values({ loginId, name: loginId, passwordHash: await hash('correct-horse-battery-staple', 4), role });
    const response = await request(app.getHttpServer()).post('/v1/staff/auth/session')
      .send({ loginId, password: 'correct-horse-battery-staple' }).expect(200);
    return response.body.accessToken as string;
  }

  beforeAll(async () => {
    db = createTestDb();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE).useValue(db)
      .overrideProvider(REDIS_CLIENT).useValue(createTestRedis())
      .overrideProvider(FIREBASE_VERIFIER).useValue(new FakeFirebaseVerifier())
      .compile();
    app = moduleRef.createNestApplication();
    await app.init();
    adminToken = await login('admin-video@example.com', 'ADMIN');
    pharmacyToken = await login('pharmacy-video@example.com', 'PHARMACY');
  });

  afterAll(async () => app.close());
  const staff = () => ({ Authorization: `Bearer ${adminToken}` });

  async function upload(bytes: Buffer) {
    const created = await request(app.getHttpServer()).post('/v1/staff/catalogue/review-video-media').set(staff()).send({
      contentType: 'video/mp4', byteLength: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex'),
    }).expect(201);
    const id = created.body.id as string;
    await request(app.getHttpServer()).put(`/v1/staff/catalogue/review-video-media/${id}/chunks/0`)
      .set(staff()).send({ data: bytes.toString('base64') }).expect(200);
    return id;
  }

  it('restricts upload lifecycle operations to ADMIN and SUPERADMIN', async () => {
    const body = { contentType: 'video/mp4', byteLength: 3, sha256: '0'.repeat(64) };
    await request(app.getHttpServer()).post('/v1/staff/catalogue/review-video-media').send(body).expect(401);
    await request(app.getHttpServer()).post('/v1/staff/catalogue/review-video-media')
      .set('Authorization', `Bearer ${pharmacyToken}`).send(body).expect(403);
  });

  it('keeps incomplete bytes private, then serves completed bytes with browser range support', async () => {
    const bytes = Buffer.from('0123456789abcdef');
    const id = await upload(bytes);
    const url = `/v1/public/catalogue/review-video-media/${id}`;
    await request(app.getHttpServer()).get(url).expect(404);
    const completed = await request(app.getHttpServer()).post(`/v1/staff/catalogue/review-video-media/${id}/complete`)
      .set(staff()).expect(201);
    expect(completed.body.videoUrl).toBe(url);
    const full = await request(app.getHttpServer()).get(url).buffer(true).parse(binary).expect(200);
    expect(full.headers['content-type']).toMatch(/^video\/mp4/);
    expect(full.headers['accept-ranges']).toBe('bytes');
    expect(full.body).toEqual(bytes);
    const ranged = await request(app.getHttpServer()).get(url).set('Range', 'bytes=3-7')
      .buffer(true).parse(binary).expect(206);
    expect(ranged.headers['content-range']).toBe(`bytes 3-7/${bytes.length}`);
    expect(ranged.body).toEqual(bytes.subarray(3, 8));
    await request(app.getHttpServer()).get(url).set('Range', 'bytes=99-100').expect(416);
    await request(app.getHttpServer()).head(url).expect('Content-Length', String(bytes.length)).expect(200);
  });

  it('publishes an absolute feed URL and removes orphaned replaced bytes', async () => {
    const id = await upload(Buffer.from('first-video'));
    const videoUrl = `/v1/public/catalogue/review-video-media/${id}`;
    await request(app.getHttpServer()).post(`/v1/staff/catalogue/review-video-media/${id}/complete`).set(staff()).expect(201);
    const created = await request(app.getHttpServer()).post('/v1/staff/catalogue/review-videos').set(staff())
      .send({ name: 'Neon review', videoUrl }).expect(201);
    const feed = await request(app.getHttpServer()).get('/v1/public/catalogue/review-videos').expect(200);
    expect(feed.body[0].videoUrl).toMatch(new RegExp(`^http://127\\.0\\.0\\.1:\\d+${videoUrl}$`));
    await request(app.getHttpServer()).delete(`/v1/staff/catalogue/review-video-media/${id}`).set(staff()).expect(409);
    await request(app.getHttpServer()).patch(`/v1/staff/catalogue/review-videos/${created.body.id}`).set(staff())
      .send({ videoUrl: 'https://www.youtube.com/watch?v=legacy' }).expect(200);
    await request(app.getHttpServer()).get(videoUrl).expect(404);
  });
});
