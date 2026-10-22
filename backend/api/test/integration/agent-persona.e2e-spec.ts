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
import { agent, users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { OtpService } from '../../src/modules/otp/otp.service';
import { FakeOtpService, memberLogin } from './fake-otp';

/**
 * GET /v1/agent/me — the "is this signed-in member also an agent" check a
 * client used to run directly against app.agent with the compiled-in Neon
 * credential (lib/data/neon/persona_repository.dart, now gone). No geo
 * fixtures needed: areaId/parentId are both nullable on app.agent.
 */
describe('Agent self-profile (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;

  beforeAll(async () => {
    db = createTestDb();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(REDIS_CLIENT)
      .useValue(createTestRedis())
      .overrideProvider(OtpService)
      .useValue(new FakeOtpService())
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  async function tokenFor(phone: string, firebaseUid: string) {
    await db.insert(users).values({ phone, name: 'Persona Member', firebaseUid, registrationCompletedAt: new Date() });
    const res = await memberLogin(app, phone).expect(200);
    return { accessToken: res.body.accessToken as string, phone };
  }

  it("returns the agent row, with the parent's code, for a member who is one", async () => {
    const { accessToken, phone } = await tokenFor('9199999201', 'persona-agent-uid');
    const [member] = await db.select().from(users).where(eq(users.phone, phone)).limit(1);
    const [parentRow] = await db
      .insert(agent)
      .values({ code: 'AG-PARENT-1', name: 'Parent Agent', phone: '9199999202', level: 'STATE' })
      .returning();
    await db.insert(agent).values({
      memberId: member.id,
      code: 'AG-SELF-1',
      name: 'Persona Member',
      phone,
      level: 'DISTRICT',
      parentId: parentRow.id,
      earned: '1500.00',
      redeemed: '500.00',
      personalSales: '20000.00',
    });

    const res = await request(app.getHttpServer())
      .get('/v1/agent/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    expect(res.body.code).toBe('AG-SELF-1');
    expect(res.body.level).toBe('DISTRICT');
    expect(Number(res.body.earned)).toBe(1500);
    expect(res.body.parentCode).toBe('AG-PARENT-1');
  });

  it('is refused for a member who is not an agent', async () => {
    const { accessToken } = await tokenFor('9199999203', 'persona-nonagent-uid');
    await request(app.getHttpServer())
      .get('/v1/agent/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(403);
  });

  it('rejects an unauthenticated call', async () => {
    await request(app.getHttpServer()).get('/v1/agent/me').expect(401);
  });
});
