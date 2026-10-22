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
import { adminUser } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';

/**
 * The Super Admin's own audit trail — every staff login (success/failure)
 * logged directly by AuthService.loginStaff, and every mutating
 * /v1/staff/* request logged generically by AuditInterceptor. See
 * app-audit.ts's own doc on the table both write to.
 */
describe('Staff audit log (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let superAdminToken: string;
  let adminToken: string;

  async function auditEntries(path?: string) {
    const res = await request(app.getHttpServer())
      .get(`/v1/staff/audit-log${path ? `?q=${encodeURIComponent(path)}` : ''}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    return res.body.items as Array<Record<string, unknown>>;
  }

  beforeAll(async () => {
    db = createTestDb();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(REDIS_CLIENT)
      .useValue(createTestRedis())
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();

    await db.insert(adminUser).values({
      loginId: 'superadmin-audit@example.com',
      name: 'Audit Super Admin',
      passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
      role: 'SUPERADMIN',
    });
    superAdminToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'superadmin-audit@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;

    await db.insert(adminUser).values({
      loginId: 'admin-audit@example.com',
      name: 'Audit Admin',
      passwordHash: await hash('correct-horse-battery-staple', 4),
      role: 'ADMIN',
    });
    adminToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'admin-audit@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('logs a successful staff login', async () => {
    const entries = await auditEntries();
    expect(entries).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ action: 'LOGIN', staffLoginId: 'superadmin-audit@example.com', statusCode: 200 }),
      ]),
    );
  });

  it('logs a failed staff login — wrong password, and an unknown login id', async () => {
    await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ loginId: 'superadmin-audit@example.com', password: 'wrong-password' })
      .expect(401);
    await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ loginId: 'no-such-login@example.com', password: 'whatever' })
      .expect(401);

    const entries = await auditEntries();
    const failures = entries.filter((e) => e.action === 'LOGIN_FAILED');
    expect(failures).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ staffLoginId: 'superadmin-audit@example.com', statusCode: 401 }),
        expect.objectContaining({ staffLoginId: 'no-such-login@example.com', statusCode: 401 }),
      ]),
    );
  });

  it('logs a deactivated account refusing to sign in, distinctly from a bad password', async () => {
    await db.insert(adminUser).values({
      loginId: 'deactivated-audit@example.com',
      name: 'Deactivated Staff',
      passwordHash: await hash('correct-horse-battery-staple', 4),
      role: 'PHARMACY',
      isActive: false,
    });
    await request(app.getHttpServer())
      .post('/v1/staff/auth/session')
      .send({ loginId: 'deactivated-audit@example.com', password: 'correct-horse-battery-staple' })
      .expect(403);

    const entries = await auditEntries();
    expect(entries).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ staffLoginId: 'deactivated-audit@example.com', action: 'LOGIN_FAILED', statusCode: 403 }),
      ]),
    );
  });

  it('logs a CREATE action for a mutating staff request, with the password redacted', async () => {
    await request(app.getHttpServer())
      .post('/v1/staff/admins')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ loginId: 'new-pharmacy-audit@example.com', name: 'New Pharmacy Staff', password: 'super-secret-pw', role: 'PHARMACY' })
      .expect(201);

    const entries = await auditEntries('/v1/staff/admins');
    const created = entries.find((e) => e.action === 'CREATE' && e.path === '/v1/staff/admins');
    expect(created).toBeDefined();
    expect(created!.staffLoginId).toBe('superadmin-audit@example.com');
    const body = created!.requestBody as Record<string, unknown>;
    expect(body.password).toBe('[redacted]');
    expect(body.loginId).toBe('new-pharmacy-audit@example.com');
  });

  it('logs an UPDATE action for a PATCH request', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/staff/admins')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ loginId: 'to-update-audit@example.com', name: 'Before Update', password: 'super-secret-pw', role: 'PHARMACY' })
      .expect(201);

    await request(app.getHttpServer())
      .patch(`/v1/staff/admins/${created.body.id}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ name: 'After Update' })
      .expect(200);

    const entries = await auditEntries(`/v1/staff/admins/${created.body.id}`);
    expect(entries).toEqual(
      expect.arrayContaining([expect.objectContaining({ action: 'UPDATE', method: 'PATCH', statusCode: 200 })]),
    );
  });

  it('does not log a plain read (GET)', async () => {
    await request(app.getHttpServer())
      .get('/v1/staff/admins')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);

    const entries = await auditEntries();
    expect(entries.some((e) => e.method === 'GET')).toBe(false);
  });

  it('rejects an ADMIN role from reading the audit log — SUPERADMIN only', async () => {
    await request(app.getHttpServer())
      .get('/v1/staff/audit-log')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(403);
  });

  it('filters by action and staffId', async () => {
    const only200Logins = await request(app.getHttpServer())
      .get('/v1/staff/audit-log?action=LOGIN')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    expect(only200Logins.body.items.every((e: { action: string }) => e.action === 'LOGIN')).toBe(true);
    expect(only200Logins.body.items.length).toBeGreaterThan(0);

    const [me] = await db.select().from(adminUser).where(eq(adminUser.loginId, 'superadmin-audit@example.com')).limit(1);
    const forMe = await request(app.getHttpServer())
      .get(`/v1/staff/audit-log?staffId=${me.id}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    expect(forMe.body.items.every((e: { staffId: number }) => e.staffId === me.id)).toBe(true);
  });
});
