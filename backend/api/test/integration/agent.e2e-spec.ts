process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { randomUUID } from 'node:crypto';
import { hash } from 'bcryptjs';
import { eq } from 'drizzle-orm';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { adminUser, agent, agentRequest, assembly, authSession, district, lsgd, region, state, users, ward } from '../../src/db/schema';
import { TokenService } from '../../src/modules/auth/token.service';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

describe('Agent & Geography (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let tokens: TokenService;
  let superAdminToken: string;
  let wardId: string;

  async function memberToken(phone: string, firebaseUid: string, name: string) {
    // registrationCompletedAt set: submitRequest/approveRequest both now
    // refuse an agent request for a member who hasn't finished registering
    // (see agent.service.ts) — every test in this file that gets this far
    // is exercising the agent flow itself, not that gate, which has its
    // own dedicated test below.
    await db.insert(users).values({ phone, name, firebaseUid, registrationCompletedAt: new Date() });
    firebase.register(`token-${firebaseUid}`, { uid: firebaseUid });
    const res = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: `token-${firebaseUid}` })
      .expect(200);
    return res.body.accessToken as string;
  }

  /**
   * A real, valid member access token — same shape AuthGuard checks
   * (verified JWT + a live app.backend.auth_session row) — minted directly
   * rather than through a real Firebase sign-in over
   * POST /v1/member/auth/session. Every spec in this file shares one
   * in-memory throttle bucket on that route (10/60s — see AuthThrottle),
   * and this file now runs enough genuinely-necessary sign-ins that one
   * more tips a later, unrelated test into a 429. Use this instead
   * whenever a test needs *a* valid session for some member, not to
   * exercise the sign-in route itself.
   */
  async function directMemberToken(userId: number): Promise<string> {
    const [session] = await db
      .insert(authSession)
      .values({
        subjectType: 'MEMBER',
        subjectId: String(userId),
        expiresAt: new Date(Date.now() + 60_000),
      })
      .returning();
    const { token } = await tokens.issueAccessToken({
      sessionId: session.id,
      subjectType: 'MEMBER',
      subjectId: String(userId),
    });
    return token;
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
    tokens = moduleRef.get(TokenService);

    // Real geo chain, real uuidv7-shaped ids (a random v4 is fine for a test double).
    const [r] = await db.insert(region).values({ id: randomUUID(), name: 'Region 1' }).returning();
    const [s] = await db.insert(state).values({ id: randomUUID(), regionId: r.id, name: 'State 1' }).returning();
    const [d] = await db.insert(district).values({ id: randomUUID(), stateId: s.id, name: 'District 1' }).returning();
    const [a] = await db.insert(assembly).values({ id: randomUUID(), districtId: d.id, name: 'Assembly 1' }).returning();
    const [l] = await db.insert(lsgd).values({ id: randomUUID(), assemblyId: a.id, type: 'grama_panchayat', name: 'LSGD 1' }).returning();
    const [w] = await db.insert(ward).values({ id: randomUUID(), lsgdId: l.id, wardNumber: 1 }).returning();
    wardId = w.id;

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
  });

  afterAll(async () => {
    await app.close();
  });

  it('lists the seeded geo hierarchy publicly, one tier at a time', async () => {
    const regions = await request(app.getHttpServer()).get('/v1/public/geo/regions').expect(200);
    expect(regions.body).toHaveLength(1);

    const states = await request(app.getHttpServer()).get(`/v1/public/geo/regions/${regions.body[0].id}/states`).expect(200);
    expect(states.body).toHaveLength(1);
  });

  it('lists the whole geo hierarchy flattened in one call, for a client that builds its tree eagerly', async () => {
    const tree = await request(app.getHttpServer()).get('/v1/public/geo/tree').expect(200);
    expect(tree.body).toHaveLength(6); // region, state, district, assembly, lsgd, ward — one of each seeded
    const byLevel = Object.fromEntries(tree.body.map((n: { level: string; id: string }) => [n.level, n.id]));
    expect(byLevel).toHaveProperty('region');
    expect(byLevel).toHaveProperty('ward', wardId);
  });

  let nationalAgentId: number;

  it('approves a NATIONAL agent request', async () => {
    const token = await memberToken('9100000001', 'member-agent-national-1', 'National Candidate');

    const submit = await request(app.getHttpServer())
      .post('/v1/agent/requests')
      .set('Authorization', `Bearer ${token}`)
      .send({ requestedLevel: 'NATIONAL' })
      .expect(201);

    const approve = await request(app.getHttpServer())
      .post(`/v1/staff/agent-requests/${submit.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(201);

    nationalAgentId = approve.body.id;
    expect(approve.body.level).toBe('NATIONAL');
    expect(approve.body.approvalStatus).toBe('APPROVED');

    // region.national_agent_id must now point at the new agent.
    const [r] = await db.select().from(region);
    expect(r.nationalAgentId).toBe(nationalAgentId);
  });

  it('THE bug fix: rejects approving a second NATIONAL agent while one already exists', async () => {
    const token = await memberToken('9100000002', 'member-agent-national-2', 'Second National Candidate');

    const submit = await request(app.getHttpServer())
      .post('/v1/agent/requests')
      .set('Authorization', `Bearer ${token}`)
      .send({ requestedLevel: 'NATIONAL' })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/v1/staff/agent-requests/${submit.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(409);

    // Exactly one APPROVED national agent must exist — the actual live-DB bug this fixes.
    const nationals = await db.select().from(agent).where(eq(agent.level, 'NATIONAL'));
    expect(nationals.filter((row) => row.approvalStatus === 'APPROVED')).toHaveLength(1);
  });

  it('rejects submitting a non-NATIONAL request with no requestedAreaId', async () => {
    const token = await memberToken('9100000003', 'member-agent-noarea', 'No Area Candidate');
    await request(app.getHttpServer())
      .post('/v1/agent/requests')
      .set('Authorization', `Bearer ${token}`)
      .send({ requestedLevel: 'WARD', requestedArea: 'Some Ward' })
      .expect(400);
  });

  it('rejects submitting an agent request before the member has completed their Sahakar 360 registration', async () => {
    // Deliberately not memberToken — this member never had
    // registrationCompletedAt set, the exact case being refused. And
    // deliberately directMemberToken, not a real sign-in — this test only
    // needs a valid session for this member, not to exercise
    // POST /v1/member/auth/session itself, and that route is the one this
    // whole file's throttle bucket is shared over (see directMemberToken's
    // own doc).
    const [unregistered] = await db
      .insert(users)
      .values({
        phone: '9100000010',
        name: 'Unregistered Candidate',
        firebaseUid: 'member-agent-unregistered',
      })
      .returning();
    const token = await directMemberToken(unregistered.id);

    await request(app.getHttpServer())
      .post('/v1/agent/requests')
      .set('Authorization', `Bearer ${token}`)
      .send({ requestedLevel: 'WARD', requestedArea: 'Ward 1', requestedAreaId: wardId })
      .expect(403);
  });

  it("THE other bug fix: rejects approving a non-NATIONAL request whose requestedAreaId doesn't resolve to a real slot", async () => {
    const token = await memberToken('9100000004', 'member-agent-badslot', 'Bad Slot Candidate');
    const submit = await request(app.getHttpServer())
      .post('/v1/agent/requests')
      .set('Authorization', `Bearer ${token}`)
      .send({ requestedLevel: 'WARD', requestedArea: 'Nonexistent Ward', requestedAreaId: randomUUID() })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/v1/staff/agent-requests/${submit.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(403);
  });

  it("rejects approving a request whose phone doesn't match any registered app.users row — the fix for the live database's orphan (member_id NULL) app.agent rows", async () => {
    // Simulates a member who filed a recruitment request and then deleted
    // their account (or changed number) before an admin got to approving
    // it — the request's phone no longer resolves to any app.users row.
    // Inserted directly rather than through the real submit flow: no
    // member sign-in is needed to exercise the approval-time guard this
    // test actually checks, and every spec in this file sharing one
    // in-memory auth-route throttle bucket means an extra sign-in call
    // here isn't free.
    const [submitted] = await db
      .insert(agentRequest)
      .values({
        requestedLevel: 'WARD',
        requestedArea: 'Ward 1',
        requestedAreaId: wardId,
        name: 'Orphan Candidate',
        phone: '9100000009',
      })
      .returning();

    await request(app.getHttpServer())
      .post(`/v1/staff/agent-requests/${submitted.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(403);

    // Nothing was written to app.agent for this request — never a row with
    // no real member behind it.
    const created = await db.select().from(agent).where(eq(agent.phone, '9100000009'));
    expect(created).toHaveLength(0);

    // The rejected-at-approval request stays PENDING (an admin can retry it
    // later, e.g. once the member re-registers) — clean it up so it doesn't
    // throw off later tests that count pending requests by number.
    await db.delete(agentRequest).where(eq(agentRequest.id, submitted.id));
  });

  it("rejects approving a request for a member who exists but hasn't completed registration — the second half of the same gate submitRequest enforces on the way in", async () => {
    // A real app.users row this time (unlike the orphan case above) — just
    // one that never finished registering. Inserted directly, the same
    // reason as the orphan test: this checks approveRequest's own re-check,
    // not the submit-time gate (which already has its own test and would
    // have refused this request before it ever reached the queue).
    await db.insert(users).values({
      phone: '9100000011',
      name: 'Half Registered',
      firebaseUid: 'member-agent-half-registered',
    });
    const [submitted] = await db
      .insert(agentRequest)
      .values({
        requestedLevel: 'WARD',
        requestedArea: 'Ward 1',
        requestedAreaId: wardId,
        name: 'Half Registered',
        phone: '9100000011',
      })
      .returning();

    await request(app.getHttpServer())
      .post(`/v1/staff/agent-requests/${submitted.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(403);

    const created = await db.select().from(agent).where(eq(agent.phone, '9100000011'));
    expect(created).toHaveLength(0);

    await db.delete(agentRequest).where(eq(agentRequest.id, submitted.id));
  });

  let wardAgentId: number;

  it('approves a WARD-level request with a real geo slot', async () => {
    const token = await memberToken('9100000005', 'member-agent-goodslot', 'Good Slot Candidate');
    const submit = await request(app.getHttpServer())
      .post('/v1/agent/requests')
      .set('Authorization', `Bearer ${token}`)
      .send({ requestedLevel: 'WARD', requestedArea: 'Ward 1', requestedAreaId: wardId, parentAgentId: nationalAgentId })
      .expect(201);

    const approve = await request(app.getHttpServer())
      .post(`/v1/staff/agent-requests/${submit.body.id}/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(201);

    wardAgentId = approve.body.id;
    expect(approve.body.areaId).toBe(wardId);
    expect(approve.body.parentId).toBe(nationalAgentId);
  });

  it('leaves a failed approval attempt PENDING (not silently rejected) and blocks re-deciding an already-approved one', async () => {
    // A failed approval (duplicate national, bad geo slot) does not mark the
    // request REJECTED on its own — it stays PENDING for staff to fix and
    // retry, or explicitly reject with a reason. Only the two that failed
    // approval above are still pending; the two that succeeded are not.
    const requests = await request(app.getHttpServer())
      .get('/v1/staff/agent-requests')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    expect(requests.body).toHaveLength(2);
    expect(requests.body.map((r: { name: string }) => r.name).sort()).toEqual([
      'Bad Slot Candidate',
      'Second National Candidate',
    ]);

    await request(app.getHttpServer())
      .post(`/v1/staff/agent-requests/1/approve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(403); // request #1 (national) already approved
  });

  it('builds the team tree from the national agent down to the ward agent', async () => {
    // Same Firebase identity that submitted the NATIONAL request earlier —
    // a fresh login just issues a new session, it doesn't create a new user.
    firebase.register('team-token', { uid: 'member-agent-national-1' });
    const login = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'team-token' })
      .expect(200);

    const team = await request(app.getHttpServer())
      .get('/v1/agent/team')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(200);

    expect(team.body.id).toBe(nationalAgentId);
    expect(team.body.descendants).toEqual(expect.arrayContaining([expect.objectContaining({ id: wardAgentId })]));
  });

  it('lists PENDING requests recruited directly under the caller, distinct from the requests the caller filed themself', async () => {
    // Same Firebase identity as the national agent — a fresh login, not a new user.
    firebase.register('national-agent-pending-check', { uid: 'member-agent-national-1' });
    const recruiterLogin = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'national-agent-pending-check' })
      .expect(200);
    const recruiterToken = recruiterLogin.body.accessToken as string;

    const recruitToken = await memberToken('9100000007', 'member-agent-recruit-1', 'Recruit One');

    await request(app.getHttpServer())
      .post('/v1/agent/requests')
      .set('Authorization', `Bearer ${recruitToken}`)
      .send({
        requestedLevel: 'WARD',
        requestedArea: 'Ward 1',
        requestedAreaId: wardId,
        parentAgentId: nationalAgentId,
      })
      .expect(201);

    const pending = await request(app.getHttpServer())
      .get('/v1/agent/team/pending')
      .set('Authorization', `Bearer ${recruiterToken}`)
      .expect(200);

    expect(pending.body).toHaveLength(1);
    expect(pending.body[0].name).toBe('Recruit One');

    // listOwnRequests (a different endpoint) is the recruiter's own filed
    // applications, matched by phone — just their own earlier NATIONAL
    // application, already APPROVED, not the pending recruit under them.
    const own = await request(app.getHttpServer())
      .get('/v1/agent/requests')
      .set('Authorization', `Bearer ${recruiterToken}`)
      .expect(200);
    expect(own.body).toHaveLength(1);
    expect(own.body[0].requestedLevel).toBe('NATIONAL');
    expect(own.body[0].status).toBe('APPROVED');
  });

  it('links a customer to an agent and rejects linking the same member twice', async () => {
    firebase.register('ward-agent-token', { uid: 'member-agent-goodslot' });
    const login = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'ward-agent-token' })
      .expect(200);

    const [customerMember] = await db
      .insert(users)
      .values({ phone: '9200000001', name: 'Customer One', firebaseUid: 'customer-one' })
      .returning();

    await request(app.getHttpServer())
      .post('/v1/agent/customers')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ memberId: customerMember.id, name: 'Customer One' })
      .expect(201);

    await request(app.getHttpServer())
      .post('/v1/agent/customers')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ memberId: customerMember.id, name: 'Customer One Again' })
      .expect(409);
  });

  it('rejects a withdrawal exceeding available earnings, allows one within it', async () => {
    await db.update(agent).set({ earned: '1000.00' }).where(eq(agent.id, wardAgentId));

    firebase.register('ward-agent-token-2', { uid: 'member-agent-goodslot' });
    const login = await request(app.getHttpServer())
      .post('/v1/member/auth/session')
      .send({ idToken: 'ward-agent-token-2' })
      .expect(200);

    await request(app.getHttpServer())
      .post('/v1/agent/withdrawals')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ amount: 5000 })
      .expect(403);

    const withdrawal = await request(app.getHttpServer())
      .post('/v1/agent/withdrawals')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ amount: 500 })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/v1/staff/agent-withdrawals/${withdrawal.body.id}/resolve`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ status: 'PAID' })
      .expect(201);

    const [updatedAgent] = await db.select().from(agent).where(eq(agent.id, wardAgentId));
    expect(Number(updatedAgent.redeemed)).toBe(500);
  });
});
