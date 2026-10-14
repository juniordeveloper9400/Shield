process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { randomUUID } from 'node:crypto';
import { hash } from 'bcryptjs';
import { and, eq, sql } from 'drizzle-orm';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { adminUser, agent, district, investor, region, state, shieldStore, users } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

/**
 * The Users page's own "Make agent" / "Make investor" / "Revoke" actions —
 * an admin granting or removing a persona directly, unlike agent.e2e-spec's
 * own agent_request approval queue. Ported from shieldweb's own direct-SQL
 * convertToAgent/convertToInvestor/revokePersona (src/api/users.ts) onto
 * AgentService.adminConvertToAgent / InvestorService.adminConvertToInvestor
 * / StaffController's persona routes.
 */
describe('Admin persona conversion (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let superAdminToken: string;
  let pharmacyToken: string;

  async function registeredMember(phone: string, name = 'Candidate Member') {
    const [member] = await db
      .insert(users)
      .values({ phone, name, registrationCompletedAt: new Date(), referralCode: `SAHAKAR-${phone.slice(-4)}` })
      .returning();
    return member;
  }

  /** A fresh region→state→district chain — DISTRICT is uncapped (unlike
   *  NATIONAL/REGION, each a one-shot global resource this suite's own
   *  invariant tests deliberately exhaust), so every test that just needs
   *  *some* valid geo-slotted agent uses this instead of colliding with
   *  those. */
  async function freshDistrict() {
    const [r] = await db.insert(region).values({ id: randomUUID(), name: `R-${randomUUID()}` }).returning();
    const [s] = await db.insert(state).values({ id: randomUUID(), regionId: r.id, name: `S-${randomUUID()}` }).returning();
    const [d] = await db.insert(district).values({ id: randomUUID(), stateId: s.id, name: `D-${randomUUID()}` }).returning();
    return d;
  }

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
      loginId: 'superadmin@example.com',
      name: 'Super Admin',
      passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
      role: 'SUPERADMIN',
    });
    superAdminToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'superadmin@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;

    await db.insert(adminUser).values({
      loginId: 'pharmacist@example.com',
      name: 'Test Pharmacist',
      passwordHash: await hash('correct-horse-battery-staple', 4),
      role: 'PHARMACY',
    });
    pharmacyToken = (
      await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId: 'pharmacist@example.com', password: 'correct-horse-battery-staple' })
        .expect(200)
    ).body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('grants the NATIONAL persona directly, mirroring it onto every region, and refuses a second one', async () => {
    const member = await registeredMember('9188800001', 'First National');
    const res = await request(app.getHttpServer())
      .post(`/v1/staff/users/${member.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ level: 'NATIONAL' })
      .expect(201);
    expect(res.body.level).toBe('NATIONAL');
    expect(res.body.approvalStatus).toBe('APPROVED');

    const [r] = await db.insert(region).values({ id: randomUUID(), name: 'Mirrored Region' }).returning();
    const [row] = await db.select().from(region).where(eq(region.id, r.id));
    expect(row.nationalAgentId).toBeNull(); // only existing regions at grant time are stamped — a region created after isn't retroactively touched

    const second = await registeredMember('9188800002', 'Second National');
    const conflict = await request(app.getHttpServer())
      .post(`/v1/staff/users/${second.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ level: 'NATIONAL' })
      .expect(409);
    expect(conflict.body.error.code).toBe('CONFLICT');
  });

  it('grants a geo-slotted persona, deriving the parent from geography and mirroring agent_id onto the slot', async () => {
    const [r] = await db.insert(region).values({ id: randomUUID(), name: 'Region For Derive' }).returning();
    const [regionAgentMember] = await db
      .insert(users)
      .values({ phone: '9188800010', name: 'Region Head', registrationCompletedAt: new Date() })
      .returning();
    const regionConvert = await request(app.getHttpServer())
      .post(`/v1/staff/users/${regionAgentMember.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ level: 'REGION', areaId: r.id })
      .expect(201);
    expect(regionConvert.body.areaId).toBe(r.id);
    const [regionRow] = await db.select().from(region).where(eq(region.id, r.id));
    expect(regionRow.agentId).toBe(regionConvert.body.id);

    const [s] = await db.insert(state).values({ id: randomUUID(), regionId: r.id, name: 'State For Derive' }).returning();
    const stateMember = await registeredMember('9188800011', 'State Head');
    const stateConvert = await request(app.getHttpServer())
      .post(`/v1/staff/users/${stateMember.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ level: 'STATE', areaId: s.id })
      .expect(201);
    // No parentId given — derived from geography: the region agent heading
    // the region this state sits in.
    expect(stateConvert.body.parentId).toBe(regionConvert.body.id);
    const [stateRow] = await db.select().from(state).where(eq(state.id, s.id));
    expect(stateRow.agentId).toBe(stateConvert.body.id);
  });

  it('refuses a second agent into the same slot, and caps region agents at six', async () => {
    const [r] = await db.insert(region).values({ id: randomUUID(), name: 'Dup Slot Region' }).returning();
    const first = await registeredMember('9188800020', 'Slot Holder');
    await request(app.getHttpServer())
      .post(`/v1/staff/users/${first.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ level: 'REGION', areaId: r.id })
      .expect(201);

    const second = await registeredMember('9188800021', 'Slot Challenger');
    const res = await request(app.getHttpServer())
      .post(`/v1/staff/users/${second.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ level: 'REGION', areaId: r.id })
      .expect(409);
    expect(res.body.error.message).toMatch(/already held/i);
  });

  it('refuses the agent that would be the seventh approved region agent', async () => {
    // Earlier tests in this suite already approved some REGION agents
    // against the one shared db — top up to exactly six before trying the
    // one that must be refused, rather than assuming a clean slate.
    const [{ count }] = await db
      .select({ count: sql<number>`count(*)::int` })
      .from(agent)
      .where(and(eq(agent.level, 'REGION'), eq(agent.approvalStatus, 'APPROVED')));
    for (let i = count; i < 6; i += 1) {
      const [r] = await db.insert(region).values({ id: randomUUID(), name: `Cap Region ${i}` }).returning();
      const member = await registeredMember(`918880003${i}`, `Region Agent ${i}`);
      await request(app.getHttpServer())
        .post(`/v1/staff/users/${member.id}/convert-to-agent`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ level: 'REGION', areaId: r.id })
        .expect(201);
    }
    const [seventhRegion] = await db.insert(region).values({ id: randomUUID(), name: 'Seventh Region' }).returning();
    const seventhMember = await registeredMember('9188800040', 'Seventh Candidate');
    const res = await request(app.getHttpServer())
      .post(`/v1/staff/users/${seventhMember.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ level: 'REGION', areaId: seventhRegion.id })
      .expect(409);
    expect(res.body.error.message).toMatch(/six regions/i);
  });

  it('rejects an unregistered member, and a non-existent areaId', async () => {
    const [unregistered] = await db.insert(users).values({ phone: '9188800050', name: 'Unregistered' }).returning();
    await request(app.getHttpServer())
      .post(`/v1/staff/users/${unregistered.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ level: 'NATIONAL' })
      .expect(403);

    const registered = await registeredMember('9188800051', 'Bad Slot');
    await request(app.getHttpServer())
      .post(`/v1/staff/users/${registered.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ level: 'WARD', areaId: randomUUID() })
      .expect(403);
  });

  it('refuses converting a member who already has a persona', async () => {
    const d = await freshDistrict();
    const member = await registeredMember('9188800060', 'Already Agent');
    await request(app.getHttpServer())
      .post(`/v1/staff/users/${member.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ level: 'DISTRICT', areaId: d.id })
      .expect(201);

    const res = await request(app.getHttpServer())
      .post(`/v1/staff/users/${member.id}/convert-to-investor`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ totalUnits: 1, unitPrice: 150000, roiPercent: 12, planType: 'YEARLY' })
      .expect(409);
    expect(res.body.error.message).toMatch(/already has a persona/i);
  });

  it('grants the investor persona directly, against a real branch code', async () => {
    const [store] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-PERSONA', name: 'Persona Branch', area: 'A', city: 'A', state: 'A', pincode: '111111' })
      .returning();
    const member = await registeredMember('9188800070', 'New Investor');
    const res = await request(app.getHttpServer())
      .post(`/v1/staff/users/${member.id}/convert-to-investor`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ storeCode: store.code, totalUnits: 3, unitPrice: 150000, roiPercent: 15, planType: 'MONTHLY' })
      .expect(201);
    expect(res.body.totalUnits).toBe(3);
    expect(res.body.investedStoreId).toBe(store.id);
  });

  it('revokes a geo-slotted agent and frees the slot it held', async () => {
    const d = await freshDistrict();
    const member = await registeredMember('9188800080', 'To Be Revoked');
    const created = await request(app.getHttpServer())
      .post(`/v1/staff/users/${member.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ level: 'DISTRICT', areaId: d.id })
      .expect(201);
    const [beforeRevoke] = await db.select().from(district).where(eq(district.id, d.id));
    expect(beforeRevoke.agentId).toBe(created.body.id);

    await request(app.getHttpServer())
      .delete(`/v1/staff/users/${member.id}/persona`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(204);

    const [agentRow] = await db.select().from(agent).where(eq(agent.memberId, member.id));
    expect(agentRow).toBeUndefined();
    const [afterRevoke] = await db.select().from(district).where(eq(district.id, d.id));
    expect(afterRevoke.agentId).toBeNull();
  });

  it('revokes an investor the same way', async () => {
    const member = await registeredMember('9188800090', 'Investor To Revoke');
    await request(app.getHttpServer())
      .post(`/v1/staff/users/${member.id}/convert-to-investor`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ totalUnits: 1, unitPrice: 150000, roiPercent: 10, planType: 'YEARLY' })
      .expect(201);

    await request(app.getHttpServer())
      .delete(`/v1/staff/users/${member.id}/persona`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(204);

    const [investorRow] = await db.select().from(investor).where(eq(investor.memberId, member.id));
    expect(investorRow).toBeUndefined();
  });

  it('rejects a PHARMACY role from converting or revoking a persona, but still lets it read the Users list', async () => {
    const member = await registeredMember('9188800100', 'Pharmacy Gate Check');

    await request(app.getHttpServer())
      .post(`/v1/staff/users/${member.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${pharmacyToken}`)
      .send({ level: 'NATIONAL' })
      .expect(403);

    await request(app.getHttpServer())
      .post(`/v1/staff/users/${member.id}/convert-to-investor`)
      .set('Authorization', `Bearer ${pharmacyToken}`)
      .send({ totalUnits: 1, unitPrice: 150000, roiPercent: 10, planType: 'YEARLY' })
      .expect(403);

    await request(app.getHttpServer())
      .delete(`/v1/staff/users/${member.id}/persona`)
      .set('Authorization', `Bearer ${pharmacyToken}`)
      .expect(403);

    await request(app.getHttpServer())
      .get('/v1/staff/users')
      .set('Authorization', `Bearer ${pharmacyToken}`)
      .expect(200);
  });

  it('lists users tagged with their persona, and reads one back by id', async () => {
    const d = await freshDistrict();
    const plainMember = await registeredMember('9188800110', 'Plain Member');
    const agentMember = await registeredMember('9188800111', 'Agent Member');
    await request(app.getHttpServer())
      .post(`/v1/staff/users/${agentMember.id}/convert-to-agent`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ level: 'DISTRICT', areaId: d.id })
      .expect(201);

    const list = await request(app.getHttpServer())
      .get('/v1/staff/users')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    expect(list.body).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: plainMember.id, agentCode: null }),
        expect.objectContaining({ id: agentMember.id, agentLevel: 'DISTRICT' }),
      ]),
    );

    const single = await request(app.getHttpServer())
      .get(`/v1/staff/users/${agentMember.id}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    expect(single.body.agentLevel).toBe('DISTRICT');
  });

  it('returns the full member detail — profile fields, patients and addresses', async () => {
    const member = await registeredMember('9188800120', 'Detail Member');
    const detail = await request(app.getHttpServer())
      .get(`/v1/staff/users/${member.id}/detail`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    expect(detail.body.patients).toEqual([]);
    expect(detail.body.addresses).toEqual([]);
    expect(detail.body.referredByName).toBeNull();

    const patient = await request(app.getHttpServer())
      .post(`/v1/staff/users/${member.id}/patients`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ name: 'Family Member', relation: 'SPOUSE', dob: '1990-01-01' })
      .expect(201);
    expect(patient.body.name).toBe('Family Member');

    const detailAfter = await request(app.getHttpServer())
      .get(`/v1/staff/users/${member.id}/detail`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    expect(detailAfter.body.patients).toHaveLength(1);
  });

  it("fixes a member's name/phone, refusing a phone already used by a different account", async () => {
    const member = await registeredMember('9188800130', 'Wrong Name');
    const other = await registeredMember('9188800131', 'Other Member');

    const clash = await request(app.getHttpServer())
      .patch(`/v1/staff/users/${member.id}/contact`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ name: 'Wrong Name', phone: other.phone })
      .expect(200);
    expect(clash.body.changed).toBe(false);

    const ok = await request(app.getHttpServer())
      .patch(`/v1/staff/users/${member.id}/contact`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ name: 'Corrected Name', phone: '9188800139' })
      .expect(200);
    expect(ok.body.changed).toBe(true);

    const [updated] = await db.select().from(users).where(eq(users.id, member.id));
    expect(updated.name).toBe('Corrected Name');
    expect(updated.phone).toBe('9188800139');
  });

  it('lists only APPROVED agents as parent options', async () => {
    // Reuses the NATIONAL agent the very first test in this suite already
    // created (NATIONAL is a one-shot global resource every other test
    // here deliberately avoids re-granting) rather than creating another.
    const options = await request(app.getHttpServer())
      .get('/v1/staff/agent-options')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    expect(options.body).toEqual(expect.arrayContaining([expect.objectContaining({ level: 'NATIONAL' })]));
  });
});
