import { ConflictException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, asc, desc, eq, getTableColumns, inArray, ne, sql } from 'drizzle-orm';
import { alias } from 'drizzle-orm/pg-core';
import { DRIZZLE, type Database } from '../../db/client';
import {
  agent,
  agentCustomer,
  agentCustomerPlan,
  agentRequest,
  agentWithdrawal,
  assembly,
  district,
  investor,
  lsgd,
  membershipTier,
  region,
  state,
  users,
  ward,
} from '../../db/schema';
import { OtpService } from '../otp/otp.service';
import type { AgentLevel } from './session-types';
import type {
  AdminConvertToAgentDto,
  ApproveAgentRequestDto,
  LinkCustomerDto,
  MoveEarningsToWalletDto,
  RejectAgentRequestDto,
  RequestWithdrawalDto,
  ResolveWithdrawalDto,
  SetAgentActiveDto,
  SubmitAgentRequestDto,
  UpdateAgentPositionDto,
} from './dto';

type GeoLevel = Exclude<AgentLevel, 'NATIONAL'>;

@Injectable()
export class AgentService {
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    private readonly otp: OtpService,
  ) {}

  /**
   * The signed-in member's own agent row, if the Super Admin has made them
   * one — the "is this member also an agent" check a client used to run
   * directly against `app.agent` with the compiled-in Neon credential (see
   * `lib/data/neon/persona_repository.dart`'s own doc, now gone). Throws
   * (treated by the caller as "not an agent") when there is none, same as
   * `InvestorService.getByMemberIdOrThrow`.
   */
  async getOwnProfile(memberId: number) {
    const parent = alias(agent, 'parent_agent');
    const [found] = await this.db
      .select({ ...getTableColumns(agent), parentCode: parent.code })
      .from(agent)
      .leftJoin(parent, eq(parent.id, agent.parentId))
      .where(eq(agent.memberId, memberId))
      .limit(1);
    if (!found) throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Not an agent' } });
    return found;
  }

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

  /** Every row, joined with whichever parent agent the recruit/recruiter
   *  suggested — shieldweb's own `PendingAgent.parentCode`/`parentName`,
   *  shown on both the queue list and the detail/approve screen. */
  private pendingRequestsQuery() {
    const parent = alias(agent, 'parent_agent');
    return this.db
      .select({ ...getTableColumns(agentRequest), parentCode: parent.code, parentName: parent.name })
      .from(agentRequest)
      .leftJoin(parent, eq(parent.id, agentRequest.parentAgentId));
  }

  async listPendingRequests() {
    return this.pendingRequestsQuery().where(eq(agentRequest.status, 'PENDING')).orderBy(agentRequest.createdAt);
  }

  async getPendingRequest(requestId: number) {
    const [found] = await this.pendingRequestsQuery()
      .where(and(eq(agentRequest.id, requestId), eq(agentRequest.status, 'PENDING')))
      .limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Agent request not found' } });
    return found;
  }

  /**
   * The single most important method in this module — see
   * backend/docs/frd.md §7. Enforces, for the first time anywhere in this
   * codebase, the two invariants that are currently violated in production:
   *   1. at most one APPROVED agent at level NATIONAL, ever.
   *   2. every non-NATIONAL agent occupies a real geo slot for its level.
   *
   * [overrides], when given, let the reviewer confirm a *different*
   * level/parent/position than what the recruit originally requested — the
   * console's own approval screen offers exactly this, most often to place
   * someone correctly when the recruiter picked the wrong tier. Each field
   * left undefined falls back to the request's own stored value; every
   * invariant above is checked against the final, possibly-overridden
   * values, never the request's original ones.
   */
  async approveRequest(requestId: number, overrides?: ApproveAgentRequestDto) {
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

      const level = overrides?.level ?? req.requestedLevel;
      const area = overrides?.area ?? req.requestedArea;
      // areaId is the one field the console only sends when the level
      // actually changed from what was requested — omitted (undefined)
      // falls back to the request's own requestedAreaId.
      const areaId = overrides?.areaId ?? req.requestedAreaId;

      if (level === 'NATIONAL') {
        await this.assertNationalSlotAvailable(tx);
      } else {
        if (level === 'REGION') {
          await this.assertRegionSlotAvailable(tx);
        }
        if (!areaId) {
          throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'areaId is required for this level' } });
        }
        const validSlot = await this.geoSlotExists(tx, level as GeoLevel, areaId);
        if (!validSlot) {
          throw new ForbiddenException({
            error: { code: 'FORBIDDEN', message: `areaId does not resolve to a real ${level} slot` },
          });
        }
        // A named slot holds exactly one approved agent — the same rule the
        // admin console's own direct-conversion action (adminConvertToAgent
        // below) enforces; this path used to skip it entirely.
        await this.assertAreaSlotFree(tx, areaId);
      }

      // An admin who leaves "Parent agent" at "(top of tree)" — sent as
      // null, same convention adminConvertToAgent uses — almost always
      // means "I haven't thought about it", not "this agent truly reports
      // to nobody": derive the geographically correct one instead of
      // taking that as a deliberate choice. An explicit pick always wins.
      const parentId = overrides?.parentId ?? (await this.deriveParentAgentId(tx, level, areaId));

      const code =
        (await this.agentCodeForSlot(tx, level, areaId, memberId)) ?? `SHD-${level.slice(0, 3)}-${Date.now().toString(36).toUpperCase()}`;

      const [createdAgent] = await tx
        .insert(agent)
        .values({
          memberId,
          code,
          name: req.name,
          phone: req.phone,
          level,
          parentId,
          area,
          areaId,
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

      if (level === 'NATIONAL') {
        // The one national agent heads all six regions.
        await tx.update(region).set({ nationalAgentId: createdAgent.id });
      } else {
        // Denormalized mirror of area_id onto the geo row itself — see
        // resyncGeoSlotAgent's own doc. This used to only run from the
        // admin console's direct-conversion path; an approved request
        // needs it just as much.
        await this.resyncGeoSlotAgent(tx, level as GeoLevel, areaId);
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

  // ---- Staff: the live roster ("All agents") -------------------------------
  // Distinct from the approval queue above: these are agents actually
  // working today, not requests waiting to be decided. Editing one
  // re-assigns their level/parent/position with the same rules approving a
  // request enforces; "removing" one switches them off (active: false)
  // rather than deleting the row outright — which would either orphan
  // their downline (parent_id is ON DELETE SET NULL) or fail against
  // whatever customer/withdrawal history references them.

  private approvedAgentsQuery() {
    const parent = alias(agent, 'parent_agent');
    return this.db
      .select({ ...getTableColumns(agent), parentCode: parent.code, parentName: parent.name })
      .from(agent)
      .leftJoin(parent, eq(parent.id, agent.parentId));
  }

  /** The whole live roster, each row carrying `plansSold` — see
   *  `withPlansSold`'s own doc — for the Agent Portal's tree view, which
   *  shows every agent's own selling figure inline rather than only the
   *  caller's own team the member-facing `getTeamForMember` is scoped to. */
  async listApprovedAgents() {
    const rows = await this.approvedAgentsQuery().where(eq(agent.approvalStatus, 'APPROVED')).orderBy(agent.level, agent.code);
    return this.withPlansSold(rows);
  }

  async getApprovedAgent(id: number) {
    const [found] = await this.approvedAgentsQuery().where(and(eq(agent.id, id), eq(agent.approvalStatus, 'APPROVED'))).limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Agent not found' } });
    return found;
  }

  /**
   * Re-assigns an already-approved agent's level, parent, and named slot —
   * the same rules as approving a request (one national, six regions, one
   * agent per slot), with this agent's own current row excluded from every
   * check so confirming their existing position again never refuses
   * itself. Resyncs both the slot they're leaving and the one they're
   * joining, so neither geo table's own `agent_id` mirror is left stale.
   */
  async updateAgentPosition(id: number, dto: UpdateAgentPositionDto) {
    return this.db.transaction(async (tx) => {
      const [before] = await tx.select().from(agent).where(eq(agent.id, id)).limit(1);
      if (!before) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Agent not found' } });

      const areaId = dto.areaId ?? null;
      if (dto.level === 'NATIONAL') {
        await this.assertNationalSlotAvailable(tx, id);
      } else {
        if (dto.level === 'REGION') {
          await this.assertRegionSlotAvailable(tx, id);
        }
        if (areaId) {
          await this.assertAreaSlotFree(tx, areaId, id);
        }
      }

      // Same reasoning as approveRequest / adminConvertToAgent: an unset
      // parent defaults to the geographically correct one, not "top of tree".
      const parentId = dto.parentId ?? (await this.deriveParentAgentId(tx, dto.level, areaId));

      const [updated] = await tx
        .update(agent)
        .set({ level: dto.level, parentId, area: dto.area, areaId, updatedAt: new Date() })
        .where(eq(agent.id, id))
        .returning();

      if (before.areaId && before.areaId !== areaId) {
        await this.resyncGeoSlotAgent(tx, before.level as GeoLevel, before.areaId);
      }
      if (dto.level === 'NATIONAL') {
        // Rare but real: an agent moved up to NATIONAL now heads every region.
        await tx.update(region).set({ nationalAgentId: updated.id });
      } else {
        await this.resyncGeoSlotAgent(tx, dto.level as GeoLevel, areaId);
      }

      return updated;
    });
  }

  /** Switches an agent on or off. See this section's own doc for why this,
   *  not a delete, is what "remove" means here. */
  async setAgentActive(id: number, dto: SetAgentActiveDto) {
    const [updated] = await this.db.update(agent).set({ active: dto.active, updatedAt: new Date() }).where(eq(agent.id, id)).returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Agent not found' } });
    return updated;
  }

  /** `AgentLevel` (minus NATIONAL) -> the geo table a slot at that level is
   *  a row in — shared by geoSlotExists, resyncGeoSlotAgent and
   *  agentCodeForSlot, so the five never drift apart on which table means
   *  which level. */
  private readonly geoTableByLevel = {
    REGION: region,
    STATE: state,
    DISTRICT: district,
    ASSEMBLY: assembly,
    LSGD: lsgd,
    WARD: ward,
  } as const;

  private async geoSlotExists(tx: Database, level: GeoLevel, areaId: string): Promise<boolean> {
    const table = this.geoTableByLevel[level];
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

  // ---- Shared invariants (approveRequest + adminConvertToAgent) -----------
  // Both paths can insert an APPROVED row into app.agent — the one via the
  // self-service request queue, the other direct from the Users page — and
  // both must respect the exact same three rules, so they call the same
  // three checks rather than keeping two copies to drift apart.

  /** [excludeAgentId], when given, lets an existing agent's own row re-save
   *  its current position (or get moved elsewhere) without the invariant
   *  check refusing them for already occupying the very slot they hold —
   *  only updateAgentPosition needs this; a fresh approval/conversion never
   *  has a row of its own yet to exclude. */
  private async assertNationalSlotAvailable(tx: Database, excludeAgentId?: number): Promise<void> {
    // Two approvals racing each other both read 'no national agent yet' and
    // both insert one. A transaction-scoped advisory lock serialises the
    // check-and-insert. The unique index is deliberately not used here: two
    // NATIONAL rows already exist in production, so it could not be created.
    await tx.execute(sql`select pg_advisory_xact_lock(hashtext('national-agent-approval'))`);
    const conditions = [eq(agent.level, 'NATIONAL'), eq(agent.approvalStatus, 'APPROVED')];
    if (excludeAgentId !== undefined) conditions.push(ne(agent.id, excludeAgentId));
    const [existingNational] = await tx.select({ id: agent.id }).from(agent).where(and(...conditions)).limit(1);
    if (existingNational) {
      throw new ConflictException({
        error: { code: 'CONFLICT', message: 'A national agent already exists — only one is allowed' },
      });
    }
  }

  private async assertRegionSlotAvailable(tx: Database, excludeAgentId?: number): Promise<void> {
    const conditions = [eq(agent.level, 'REGION'), eq(agent.approvalStatus, 'APPROVED')];
    if (excludeAgentId !== undefined) conditions.push(ne(agent.id, excludeAgentId));
    const [row] = await tx.select({ count: sql<number>`count(*)::int` }).from(agent).where(and(...conditions));
    if ((row?.count ?? 0) >= 6) {
      throw new ConflictException({
        error: { code: 'CONFLICT', message: 'All six regions already have an agent — no more region agents can be added' },
      });
    }
  }

  /** A named slot holds exactly one approved agent — refuse a second one
   *  into a slot an approved agent already occupies. */
  private async assertAreaSlotFree(tx: Database, areaId: string, excludeAgentId?: number): Promise<void> {
    const conditions = [eq(agent.areaId, areaId), eq(agent.approvalStatus, 'APPROVED')];
    if (excludeAgentId !== undefined) conditions.push(ne(agent.id, excludeAgentId));
    const [dup] = await tx.select({ id: agent.id }).from(agent).where(and(...conditions)).limit(1);
    if (dup) {
      throw new ConflictException({
        error: { code: 'CONFLICT', message: 'That position is already held by another agent' },
      });
    }
  }

  /**
   * Recomputes `app.<table for level>.agent_id` for [areaId] from whichever
   * approved agent (if any) now has that `area_id` — a denormalized mirror
   * of `app.agent.area_id` living on the geo row itself, so "who heads this
   * slot" is answerable straight from `app.region`/`state`/… without a join.
   * `app.agent.area_id` stays the one source of truth; this only ever
   * copies it outward. No-op for a null [areaId].
   */
  private async resyncGeoSlotAgent(tx: Database, level: GeoLevel, areaId: string | null): Promise<void> {
    if (!areaId) return;
    const table = this.geoTableByLevel[level];
    const [holder] = await tx
      .select({ id: agent.id })
      .from(agent)
      .where(and(eq(agent.areaId, areaId), eq(agent.approvalStatus, 'APPROVED')))
      .limit(1);
    await tx.update(table).set({ agentId: holder?.id ?? null }).where(eq(table.id, areaId));
  }

  /**
   * The one code a newly-approved agent gets: their own geo slot's
   * level-tagged prefix combined with their own member id's numeric
   * referral-code suffix — `'STA-KER-01-1042'`. Returns null when either
   * half is missing (no prefix_code yet for this slot, or no referral code
   * on the member), so callers fall back to a plain generated code instead
   * of ever storing a partial one.
   */
  private async agentCodeForSlot(tx: Database, level: AgentLevel, areaId: string | null, memberId: number): Promise<string | null> {
    let prefix: string | null;
    if (level === 'NATIONAL') {
      prefix = 'NAT-INDIA-01';
    } else {
      if (!areaId) return null;
      const table = this.geoTableByLevel[level as GeoLevel];
      const [row] = await tx.select({ prefixCode: table.prefixCode }).from(table).where(eq(table.id, areaId)).limit(1);
      prefix = row?.prefixCode?.trim() || null;
    }
    if (!prefix) return null;

    const [member] = await tx.select({ referralCode: users.referralCode }).from(users).where(eq(users.id, memberId)).limit(1);
    const suffix = member?.referralCode?.match(/(\d+)$/)?.[1];
    return suffix ? `${prefix}-${suffix}` : null;
  }

  /**
   * Who an agent at [level] + [areaId] *should* report to, purely from
   * where their slot sits in the geo hierarchy — the region agent for a
   * state, the state agent for a district, and so on, walking up past any
   * tier with nobody in it yet, down to the national agent as the last
   * resort. Null when there's nobody to derive a parent from. This is a
   * default, not an override — callers only fall back to it when the admin
   * left "Parent agent" unset.
   */
  private async deriveParentAgentId(tx: Database, level: AgentLevel, areaId: string | null): Promise<number | null> {
    if (level === 'NATIONAL') return null;
    if (level !== 'REGION' && areaId) {
      const found = await this.walkGeoAncestors(tx, level as GeoLevel, areaId);
      if (found != null) return found;
    }
    return this.soleNationalAgentId(tx);
  }

  /** One query per tier, nearest ancestor first, LEFT JOINs throughout
   *  (lsgd.assembly_id is nullable) so the walk from a ward or lsgd can run
   *  out partway up rather than fail outright. Mirrors geo.ts's own
   *  ANCESTOR_AGENT_QUERY, ported here since this is now the one place that
   *  ever needs it. */
  private async walkGeoAncestors(tx: Database, level: GeoLevel, areaId: string): Promise<number | null> {
    switch (level) {
      case 'REGION':
        return null;
      case 'STATE': {
        const [row] = await tx
          .select({ a0: region.agentId })
          .from(state)
          .innerJoin(region, eq(region.id, state.regionId))
          .where(eq(state.id, areaId))
          .limit(1);
        return row?.a0 ?? null;
      }
      case 'DISTRICT': {
        const [row] = await tx
          .select({ a0: state.agentId, a1: region.agentId })
          .from(district)
          .innerJoin(state, eq(state.id, district.stateId))
          .innerJoin(region, eq(region.id, state.regionId))
          .where(eq(district.id, areaId))
          .limit(1);
        return row ? row.a0 ?? row.a1 ?? null : null;
      }
      case 'ASSEMBLY': {
        const [row] = await tx
          .select({ a0: district.agentId, a1: state.agentId, a2: region.agentId })
          .from(assembly)
          .innerJoin(district, eq(district.id, assembly.districtId))
          .innerJoin(state, eq(state.id, district.stateId))
          .innerJoin(region, eq(region.id, state.regionId))
          .where(eq(assembly.id, areaId))
          .limit(1);
        return row ? row.a0 ?? row.a1 ?? row.a2 ?? null : null;
      }
      case 'LSGD': {
        const [row] = await tx
          .select({ a0: assembly.agentId, a1: district.agentId, a2: state.agentId, a3: region.agentId })
          .from(lsgd)
          .leftJoin(assembly, eq(assembly.id, lsgd.assemblyId))
          .leftJoin(district, eq(district.id, assembly.districtId))
          .leftJoin(state, eq(state.id, district.stateId))
          .leftJoin(region, eq(region.id, state.regionId))
          .where(eq(lsgd.id, areaId))
          .limit(1);
        return row ? row.a0 ?? row.a1 ?? row.a2 ?? row.a3 ?? null : null;
      }
      case 'WARD': {
        const [row] = await tx
          .select({ a0: lsgd.agentId, a1: assembly.agentId, a2: district.agentId, a3: state.agentId, a4: region.agentId })
          .from(ward)
          .innerJoin(lsgd, eq(lsgd.id, ward.lsgdId))
          .leftJoin(assembly, eq(assembly.id, lsgd.assemblyId))
          .leftJoin(district, eq(district.id, assembly.districtId))
          .leftJoin(state, eq(state.id, district.stateId))
          .leftJoin(region, eq(region.id, state.regionId))
          .where(eq(ward.id, areaId))
          .limit(1);
        return row ? row.a0 ?? row.a1 ?? row.a2 ?? row.a3 ?? row.a4 ?? null : null;
      }
    }
  }

  /** The one live national agent, or null (none yet, or more than one —
   *  ambiguous, so this stays out of the way rather than guessing). */
  private async soleNationalAgentId(tx: Database): Promise<number | null> {
    const rows = await tx
      .select({ id: agent.id })
      .from(agent)
      .where(and(eq(agent.level, 'NATIONAL'), eq(agent.approvalStatus, 'APPROVED')));
    return rows.length === 1 ? rows[0].id : null;
  }

  // ---- Admin: direct persona grant -----------------------------------------
  // The Users page's own "Make agent" action — an admin assigning the
  // persona directly to an existing member rather than approving something
  // they applied for. Enforces exactly the same invariants approveRequest
  // does, via the shared helpers above, since this is the other path that
  // can insert into app.agent.

  async adminConvertToAgent(memberId: number, dto: AdminConvertToAgentDto) {
    return this.db.transaction(async (tx) => {
      const [member] = await tx.select().from(users).where(eq(users.id, memberId)).limit(1);
      if (!member) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Member not found' } });
      if (!member.registrationCompletedAt) {
        throw new ForbiddenException({
          error: {
            code: 'FORBIDDEN',
            message: 'This member has not completed registration yet — they cannot be converted to an agent or investor.',
          },
        });
      }

      const [existingAgent] = await tx.select({ id: agent.id }).from(agent).where(eq(agent.memberId, memberId)).limit(1);
      const [existingInvestor] = await tx.select({ id: investor.id }).from(investor).where(eq(investor.memberId, memberId)).limit(1);
      if (existingAgent || existingInvestor) {
        throw new ConflictException({ error: { code: 'CONFLICT', message: 'This member already has a persona.' } });
      }

      const level = dto.level;
      let areaId: string | null = null;
      if (level === 'NATIONAL') {
        await this.assertNationalSlotAvailable(tx);
      } else {
        if (level === 'REGION') {
          await this.assertRegionSlotAvailable(tx);
        }
        if (!dto.areaId) {
          throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'areaId is required for this level' } });
        }
        const validSlot = await this.geoSlotExists(tx, level as GeoLevel, dto.areaId);
        if (!validSlot) {
          throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: `areaId does not resolve to a real ${level} slot` } });
        }
        await this.assertAreaSlotFree(tx, dto.areaId);
        areaId = dto.areaId;
      }

      const parentId = dto.parentId !== undefined && dto.parentId !== null ? dto.parentId : await this.deriveParentAgentId(tx, level, areaId);
      const code =
        (await this.agentCodeForSlot(tx, level, areaId, memberId)) ?? `SHD-${level.slice(0, 3)}-${Date.now().toString(36).toUpperCase()}`;

      const [created] = await tx
        .insert(agent)
        .values({
          memberId,
          code,
          name: member.name,
          phone: member.phone,
          level,
          parentId,
          area: dto.area,
          areaId,
          approvalStatus: 'APPROVED',
          reviewedAt: new Date(),
        })
        .returning();

      if (level === 'NATIONAL') {
        await tx.update(region).set({ nationalAgentId: created.id });
      } else {
        await this.resyncGeoSlotAgent(tx, level as GeoLevel, areaId);
      }

      return created;
    });
  }

  /** The approved agents eligible as a "parent" pick, for the Users page's
   *  convert-to-agent form and the agent_request KYC form's own picker — a
   *  pending or rejected registration is neither a valid parent nor a slot
   *  that counts as taken. */
  async listApprovedAgentOptions() {
    return this.db
      .select({ id: agent.id, code: agent.code, name: agent.name, level: agent.level })
      .from(agent)
      .where(eq(agent.approvalStatus, 'APPROVED'))
      .orderBy(agent.level, agent.code);
  }

  /** Drops the member back to a plain member — removes their app.agent row
   *  and frees whatever geo slot they held. */
  async adminRevokeAgent(memberId: number): Promise<void> {
    await this.db.transaction(async (tx) => {
      const [removed] = await tx
        .delete(agent)
        .where(eq(agent.memberId, memberId))
        .returning({ level: agent.level, areaId: agent.areaId });
      if (removed?.areaId) {
        await this.resyncGeoSlotAgent(tx, removed.level as GeoLevel, removed.areaId);
      }
    });
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

  /** Staff-facing counterpart to `listCustomers`: any agent's own direct
   *  customers and the plans they've activated, by `app.agent.id` directly
   *  rather than scoped to the calling member — what the Agent Portal's
   *  money-flow view shows for whichever agent is open, not just "my own". */
  async listCustomersForAgent(agentId: number) {
    const customers = await this.db
      .select()
      .from(agentCustomer)
      .where(eq(agentCustomer.agentId, agentId))
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

  /** Staff-facing counterpart to `listOwnWithdrawals`: any agent's own
   *  withdrawal history by `app.agent.id` directly. */
  async listWithdrawalsForAgent(agentId: number) {
    const result = await this.db.execute(sql`select id, amount, status, requested_on as "requestedOn", approved_at as "approvedAt",
      payment_reference as "paymentReference", verification_note as "note" from app.agent_withdrawal where agent_id = ${agentId} order by id desc`);
    return result.rows;
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
    // Approval alone is gated on the agent's phone OTP; recording payment and
    // rejecting act on a request that was already approved (or is being turned
    // down), so they need no code.
    const otp = dto.status === 'APPROVED' ? await this.verifyApprovalOtp(withdrawalId, dto.otpCode) : null;
    return this.withdrawalCommand(async () => {
      const action = dto.status === 'APPROVED' ? 'APPROVE' : dto.status === 'PAID' ? 'PAY' : 'REJECT';
      // One transaction: if the review function refuses the approval, the OTP
      // audit columns roll back with it.
      await this.db.transaction(async (tx) => {
        if (otp) {
          await tx.execute(sql`update app.agent_withdrawal set otp_verified_at = now(),
            otp_verified_phone = ${otp.phone} where id = ${withdrawalId}`);
        }
        await tx.execute(sql`select app.review_agent_withdrawal(${withdrawalId}, ${action}, ${reviewer},
          ${dto.accountNumber}, ${dto.identityVerified}, ${dto.earningsVerified}, ${dto.note}, ${dto.paymentReference})`);
      });
      return { ok: true };
    });
  }

  /**
   * Texts an MSG91 code to the agent's registered phone for approving
   * [withdrawalId]. The number is always read from app.agent here, never
   * taken from the request, so staff cannot redirect the code elsewhere.
   */
  async sendApprovalOtp(withdrawalId: number) {
    const phone = await this.withdrawalAgentPhone(withdrawalId);
    const result = await this.otp.sendMsg91Otp(phone);
    if (!result.ok) throw new ForbiddenException(result.reason ?? 'Could not send the code. Try again in a moment.');
    return { ok: true };
  }

  /** The agent read back the code [sendApprovalOtp] texted to their phone. */
  private async verifyApprovalOtp(withdrawalId: number, code: string | undefined) {
    const phone = await this.withdrawalAgentPhone(withdrawalId);
    if (!code) {
      throw new ForbiddenException(
        'OTP verification is required: send a code to the agent’s registered phone and enter it before approving.',
      );
    }
    const result = await this.otp.verifyMsg91Otp(phone, code);
    // Not a 401: the admin's own session is fine, only the code proof is not.
    if (!result.ok) throw new ForbiddenException(result.reason ?? 'That code is not right or has expired — send a new code to the agent.');
    return { phone };
  }

  private async withdrawalAgentPhone(withdrawalId: number): Promise<string> {
    const result = await this.db.execute(sql`select a.phone from app.agent_withdrawal w
      join app.agent a on a.id = w.agent_id where w.id = ${withdrawalId}`);
    const phone = (result.rows[0] as { phone?: string } | undefined)?.phone;
    if (!phone) throw new NotFoundException('Withdrawal request not found');
    return phone;
  }

  async moveEarningsToWallet(memberId: number, dto: MoveEarningsToWalletDto) {
    const self = await this.getApprovedAgentByMemberIdOrThrow(memberId);
    return this.withdrawalCommand(async () => {
      const result = await this.db.execute(
        sql`select app.move_agent_earnings_to_wallet(${self.id}, ${dto.amount}) as balance`,
      );
      return { ok: true, amount: dto.amount, walletBalance: (result.rows[0] as { balance: string }).balance };
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
