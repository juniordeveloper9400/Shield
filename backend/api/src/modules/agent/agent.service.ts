import { ConflictException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, asc, desc, eq, inArray, ne, sql } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import {
  agent,
  agentCustomer,
  agentCustomerPlan,
  agentRequest,
  agentWithdrawal,
  assembly,
  district,
  lsgd,
  membershipTier,
  region,
  state,
  users,
  ward,
} from '../../db/schema';
import type { AgentLevel } from './session-types';
import type {
  LinkCustomerDto,
  RejectAgentRequestDto,
  RequestWithdrawalDto,
  ResolveWithdrawalDto,
  SubmitAgentRequestDto,
} from './dto';

type GeoLevel = Exclude<AgentLevel, 'NATIONAL'>;

@Injectable()
export class AgentService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  // ---- Member: submit a recruitment request --------------------------------
  // Never writes app.agent directly — see the live schema's own comment on
  // agent_request: "app.agent therefore only ever holds real, approved agents."

  async submitRequest(memberId: number, dto: SubmitAgentRequestDto) {
    const [member] = await this.db.select().from(users).where(eq(users.id, memberId)).limit(1);
    if (!member) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Member not found' } });
    // Same gate approveRequest enforces on the way out — checked again here
    // on the way in so a request never sits in the queue for staff to look
    // at before it could ever legally be approved. registrationCompletedAt
    // is set once, the first time the member's own profile is saved (see
    // identity.service.ts's updateProfile) — the one real signal for "has
    // this member actually finished registering."
    if (!member.registrationCompletedAt) {
      throw new ForbiddenException({
        error: {
          code: 'FORBIDDEN',
          message: 'Complete your Sahakar 360 registration before requesting to become an agent',
        },
      });
    }

    // Two different callers hit this same route. A plain self "become an
    // agent" request (optionally naming a *suggested* parentAgentId too) is
    // filed by the recruit's own session — `member` here already is the
    // recruit, so `member.name`/`member.phone` are exactly right. But an
    // existing agent filling in a *new* recruit's KYC form (`parentAgentId`
    // is the real parent this time) is still filed under the recruiter's own
    // session — `member` is the recruiter, not the recruit — and that form
    // sends the recruit's own, already OTP-verified `phone` explicitly for
    // exactly this reason. Its presence, not `parentAgentId` (present in
    // both cases), is what tells the two apart: unconditionally using
    // `member.name`/`member.phone` here used to attribute the recruit's
    // request to the recruiter instead — the row's `name`/`phone` read back
    // as the recruiter's own, while `firstName`/`lastName`/`aadhaar` etc.
    // (passed through untouched via `...dto`) stayed correctly the
    // recruit's, a mismatch a name-only glance at the roster wouldn't catch.
    const recruitingSomeoneElse = !!dto.phone;
    const name = recruitingSomeoneElse
      ? [dto.firstName, dto.middleName, dto.lastName].filter((part) => part.length > 0).join(' ')
      : member.name;
    const phone = recruitingSomeoneElse ? dto.phone! : member.phone;

    const [created] = await this.db
      .insert(agentRequest)
      .values({ ...dto, name, phone })
      .returning();
    return created;
  }

  async listOwnRequests(memberId: number) {
    const [member] = await this.db.select({ phone: users.phone }).from(users).where(eq(users.id, memberId)).limit(1);
    if (!member) return [];
    return this.db.select().from(agentRequest).where(eq(agentRequest.phone, member.phone)).orderBy(desc(agentRequest.createdAt));
  }

  // ---- Staff: approval queue ------------------------------------------------

  async listPendingRequests() {
    return this.db.select().from(agentRequest).where(eq(agentRequest.status, 'PENDING')).orderBy(agentRequest.createdAt);
  }

  /**
   * The single most important method in this module — see
   * backend/docs/frd.md §7. Enforces, for the first time anywhere in this
   * codebase, the two invariants that are currently violated in production:
   *   1. at most one APPROVED agent at level NATIONAL, ever.
   *   2. every non-NATIONAL agent occupies a real geo slot for its level.
   */
  async approveRequest(requestId: number) {
    return this.db.transaction(async (tx) => {
      const [req] = await tx.select().from(agentRequest).where(eq(agentRequest.id, requestId)).limit(1);
      if (!req) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Agent request not found' } });
      if (req.status !== 'PENDING') {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: `Request already ${req.status.toLowerCase()}` } });
      }

      // An agent must be a real, registered app member — never a row with
      // no app.users behind it. Older code (long since retired — see
      // docs/decision-log.md) could write app.agent directly with no
      // member link at all; this is the one remaining path that inserts
      // into app.agent and it must not reopen that gap just because the
      // recruit's phone no longer resolves (member deleted their account,
      // changed number, or the row was somehow never registered).
      //
      // submitRequest already refuses this on the way in, but a request can
      // sit PENDING for a while — the member could delete their account, or
      // (before that check existed) an old request could already be queued
      // — so approval re-checks both "does an account exist" and "did they
      // ever actually finish registering" rather than trusting the queue.
      const member = await this.resolveRegisteredMemberByPhone(tx, req.phone);
      if (member === null) {
        throw new ForbiddenException({
          error: {
            code: 'FORBIDDEN',
            message: 'No registered member matches this phone number — an agent can only be created for a real registered app user',
          },
        });
      }
      if (!member.registrationCompletedAt) {
        throw new ForbiddenException({
          error: {
            code: 'FORBIDDEN',
            message:
              "This member hasn't finished their Sahakar 360 registration yet — an agent request can only be approved once they have",
          },
        });
      }
      const memberId = member.id;

      if (req.requestedLevel === 'NATIONAL') {
        const [existingNational] = await tx
          .select({ id: agent.id })
          .from(agent)
          .where(and(eq(agent.level, 'NATIONAL'), eq(agent.approvalStatus, 'APPROVED')))
          .limit(1);
        if (existingNational) {
          throw new ConflictException({
            error: { code: 'CONFLICT', message: 'A national agent already exists — only one is allowed' },
          });
        }
      } else {
        if (!req.requestedAreaId) {
          throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'requestedAreaId is required for this level' } });
        }
        const validSlot = await this.geoSlotExists(tx, req.requestedLevel as GeoLevel, req.requestedAreaId);
        if (!validSlot) {
          throw new ForbiddenException({
            error: {
              code: 'FORBIDDEN',
              message: `requestedAreaId does not resolve to a real ${req.requestedLevel} slot`,
            },
          });
        }
      }

      const [createdAgent] = await tx
        .insert(agent)
        .values({
          memberId,
          code: `SHD-${req.requestedLevel.slice(0, 3)}-${Date.now().toString(36).toUpperCase()}`,
          name: req.name,
          phone: req.phone,
          level: req.requestedLevel,
          parentId: req.parentAgentId,
          area: req.requestedArea,
          areaId: req.requestedAreaId,
          firstName: req.firstName,
          middleName: req.middleName,
          lastName: req.lastName,
          dob: req.dob,
          aadhaar: req.aadhaar,
          pan: req.pan,
          address: req.address,
          pincode: req.pincode,
          place: req.place,
          accountNumber: req.accountNumber,
          photoPath: req.photoPath,
          approvalStatus: 'APPROVED',
          reviewedAt: new Date(),
        })
        .returning();

      await tx
        .update(agentRequest)
        .set({ status: 'APPROVED', agentId: createdAgent.id, reviewedAt: new Date() })
        .where(eq(agentRequest.id, requestId));

      if (req.requestedLevel === 'NATIONAL') {
        // The one national agent heads all six regions.
        await tx.update(region).set({ nationalAgentId: createdAgent.id });
      }

      return createdAgent;
    });
  }

  async rejectRequest(requestId: number, dto: RejectAgentRequestDto) {
    const [req] = await this.db.select().from(agentRequest).where(eq(agentRequest.id, requestId)).limit(1);
    if (!req) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Agent request not found' } });
    if (req.status !== 'PENDING') {
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: `Request already ${req.status.toLowerCase()}` } });
    }

    const [updated] = await this.db
      .update(agentRequest)
      .set({ status: 'REJECTED', reviewerNote: dto.note, reviewedAt: new Date() })
      .where(eq(agentRequest.id, requestId))
      .returning();
    return updated;
  }

  private async geoSlotExists(tx: Database, level: GeoLevel, areaId: string): Promise<boolean> {
    const tableByLevel = { REGION: region, STATE: state, DISTRICT: district, ASSEMBLY: assembly, LSGD: lsgd, WARD: ward };
    const table = tableByLevel[level];
    const [found] = await tx.select({ id: table.id }).from(table).where(eq(table.id, areaId)).limit(1);
    return !!found;
  }

  private async resolveRegisteredMemberByPhone(
    tx: Database,
    phone: string,
  ): Promise<{ id: number; registrationCompletedAt: Date | null } | null> {
    const [found] = await tx
      .select({ id: users.id, registrationCompletedAt: users.registrationCompletedAt })
      .from(users)
      .where(eq(users.phone, phone))
      .limit(1);
    return found ?? null;
  }

  // ---- Team tree -------------------------------------------------------

  async getTeamForMember(memberId: number) {
    const self = await this.getApprovedAgentByMemberIdOrThrow(memberId);
    const descendants =
      self.level === 'NATIONAL' ? await this.getEveryoneBelowNational(self.id) : await this.getDescendants(self.id);
    const counted = await this.withPlansSold([self, ...descendants]);
    return { ...counted[0], descendants: counted.slice(1) };
  }

  /**
   * [rows] (self plus every descendant `getTeamForMember` found) with
   * `plansSold` attached — how many Health Pass plans each agent has
   * personally sold, straight from `app.agent_customer_plan` rather than
   * `app.agent_customer` alone (a linked-but-not-yet-activated customer
   * carries no plan and must not count). `personalSales`/`earned` already
   * ride along on the plain agent row (real columns, kept current by
   * `approve_wallet_card_activation`); this is the one figure "My Team"'s
   * roster needs that isn't a column anywhere, and every agent in that
   * table needs their own count, not just the caller's own — unlike
   * `listCustomers`, which is deliberately scoped to the caller alone and
   * must stay that way (another agent's own customer list is not the
   * caller's to see; a bare count of it is fine to roll into their team
   * total, same as `personalSales` already is).
   */
  private async withPlansSold<T extends { id: number }>(rows: T[]): Promise<(T & { plansSold: number })[]> {
    if (rows.length === 0) return [];
    const counts = await this.db
      .select({ agentId: agentCustomer.agentId, count: sql<number>`count(*)::int` })
      .from(agentCustomerPlan)
      .innerJoin(agentCustomer, eq(agentCustomer.id, agentCustomerPlan.agentCustomerId))
      .where(
        inArray(
          agentCustomer.agentId,
          rows.map((r) => r.id),
        ),
      )
      .groupBy(agentCustomer.agentId);
    const byAgentId = new Map(counts.map((c) => [c.agentId, c.count]));
    return rows.map((r) => ({ ...r, plansSold: byAgentId.get(r.id) ?? 0 }));
  }

  /**
   * PENDING app.agent_request rows recruited directly under the caller's own
   * agent id — distinct from listOwnRequests (the caller's own filed
   * applications, matched by phone). This is what a "My Team" screen needs
   * to show a locked "waiting for approval" card for someone the caller
   * recruited but the admin hasn't approved yet.
   */
  async getPendingRequestsForMember(memberId: number) {
    const self = await this.getApprovedAgentByMemberIdOrThrow(memberId);
    return this.db
      .select()
      .from(agentRequest)
      .where(and(eq(agentRequest.parentAgentId, self.id), eq(agentRequest.status, 'PENDING')))
      .orderBy(agentRequest.createdAt);
  }

  /**
   * One round trip instead of one per tree depth level: a recursive CTE
   * walks the whole subtree in the database, then a single typed `select`
   * fetches the full rows for those ids. The old version's level-by-level
   * BFS loop (one `SELECT ... WHERE parent_id IN (...)` per depth) cost a
   * full network round trip per level — cheap on a local database, but the
   * backend and the Neon database sit in different regions, so each round
   * trip carries real cross-region latency and a deep tree made "My Team"
   * feel like it hung.
   */
  private async getDescendants(rootId: number) {
    const idRows = await this.db.execute<{ id: number }>(sql`
      WITH RECURSIVE descendants AS (
        SELECT id FROM app.agent WHERE parent_id = ${rootId}
        UNION ALL
        SELECT a.id FROM app.agent a INNER JOIN descendants d ON a.parent_id = d.id
      )
      SELECT id FROM descendants
    `);
    const ids = idRows.rows.map((row) => Number(row.id));
    if (ids.length === 0) return [];
    return this.db.select().from(agent).where(inArray(agent.id, ids));
  }

  /**
   * The national agent is meant to be the one root everyone eventually
   * reports up to, but real data can leave someone unreachable by a plain
   * parent-chain walk (an agent converted with no parent chosen, an
   * inconsistent parent_id) — so a national agent's own downline is every
   * other non-national agent, not just whoever a correct chain of
   * parent_id happens to connect back to them. Mirrors AgentService's own
   * client-side `descendantsOf` in shield agent_invester (the same rule
   * kept in sync on both sides — see that method's doc).
   */
  private async getEveryoneBelowNational(nationalId: number) {
    return this.db.select().from(agent).where(and(ne(agent.id, nationalId), ne(agent.level, 'NATIONAL')));
  }

  // ---- Customers & withdrawals -------------------------------------------

  async linkCustomer(memberId: number, dto: LinkCustomerDto) {
    const self = await this.getApprovedAgentByMemberIdOrThrow(memberId);
    try {
      const [created] = await this.db.insert(agentCustomer).values({ ...dto, agentId: self.id }).returning();
      return created;
    } catch {
      throw new ConflictException({
        error: { code: 'CONFLICT', message: 'This member is already linked to an agent' },
      });
    }
  }

  /**
   * The calling agent's own "Direct sale" customers, each with every plan
   * they've activated — what shield agent_invester's Agent Portal actually
   * shows and pays commission on. A customer with no plan yet (linked at
   * registration, not activated) still appears, with an empty plans list —
   * matching `AgentCustomerRepository.fetchAll`'s own doc on the root app's
   * direct-Neon equivalent, which this mirrors.
   */
  async listCustomers(memberId: number) {
    const self = await this.getApprovedAgentByMemberIdOrThrow(memberId);
    const customers = await this.db
      .select()
      .from(agentCustomer)
      .where(eq(agentCustomer.agentId, self.id))
      .orderBy(desc(agentCustomer.createdAt));
    if (customers.length === 0) return [];

    const plans = await this.db
      .select({
        id: agentCustomerPlan.id,
        agentCustomerId: agentCustomerPlan.agentCustomerId,
        tierKind: membershipTier.kind,
        amount: agentCustomerPlan.amount,
        activatedOn: agentCustomerPlan.activatedOn,
      })
      .from(agentCustomerPlan)
      .innerJoin(membershipTier, eq(membershipTier.id, agentCustomerPlan.tierId))
      .where(
        inArray(
          agentCustomerPlan.agentCustomerId,
          customers.map((c) => c.id),
        ),
      )
      .orderBy(asc(agentCustomerPlan.activatedOn));

    const plansByCustomer = new Map<number, typeof plans>();
    for (const plan of plans) {
      const list = plansByCustomer.get(plan.agentCustomerId) ?? [];
      list.push(plan);
      plansByCustomer.set(plan.agentCustomerId, list);
    }

    return customers.map((c) => ({ ...c, plans: plansByCustomer.get(c.id) ?? [] }));
  }

  async requestWithdrawal(memberId: number, dto: RequestWithdrawalDto) {
    const self = await this.getApprovedAgentByMemberIdOrThrow(memberId);
    if (dto.amount < 3000) throw new ForbiddenException('Minimum withdrawal is Rs 3000');
    return this.withdrawalCommand(async () => {
      const result = await this.db.execute(sql`select app.request_agent_withdrawal(${self.id}, ${dto.amount}) as id`);
      return result.rows[0];
    });
  }

  async listOwnWithdrawals(memberId: number) {
    const self = await this.getApprovedAgentByMemberIdOrThrow(memberId);
    const result = await this.db.execute(sql`select id, amount, status, requested_on as "requestedOn", approved_at as "approvedAt",
      verification_note as "note" from app.agent_withdrawal where agent_id = ${self.id} order by id`);
    return result.rows;
  }

  async listWithdrawalsForStaff() {
    const result = await this.db.execute(sql`select w.*, a.code, a.name, a.phone,
      a.account_number, a.earned, a.redeemed, a.approval_status,
      (select coalesce(sum(p.amount),0) from app.agent_withdrawal p
        where p.agent_id = a.id and p.status = 'PENDING') as pending_total
      from app.agent_withdrawal w join app.agent a on a.id = w.agent_id
      order by (w.status = 'PENDING') desc, w.created_at desc`);
    return result.rows;
  }

  async resolveWithdrawal(withdrawalId: number, dto: ResolveWithdrawalDto, reviewer: string) {
    return this.withdrawalCommand(async () => {
      const action = dto.status === 'APPROVED' ? 'APPROVE' : dto.status === 'PAID' ? 'PAY' : 'REJECT';
      await this.db.execute(sql`select app.review_agent_withdrawal(${withdrawalId}, ${action}, ${reviewer},
        ${dto.accountNumber}, ${dto.identityVerified}, ${dto.earningsVerified}, ${dto.note}, ${dto.paymentReference})`);
      return { ok: true };
    });
  }

  private async withdrawalCommand<T>(run: () => Promise<T>): Promise<T> {
    try { return await run(); }
    catch (error) {
      // Only expose our PL/pgSQL validation errors, never a query or connection details.
      const pg = (error as { cause?: { code?: string; message?: string }; code?: string; message?: string });
      const detail = pg.cause ?? pg;
      if (detail.code === 'P0001') throw new ForbiddenException(detail.message);
      throw error;
    }
  }

  private async getApprovedAgentByMemberIdOrThrow(memberId: number) {
    const [found] = await this.db
      .select()
      .from(agent)
      .where(and(eq(agent.memberId, memberId), eq(agent.approvalStatus, 'APPROVED')))
      .limit(1);
    if (!found) throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Not an approved agent' } });
    return found;
  }
}
