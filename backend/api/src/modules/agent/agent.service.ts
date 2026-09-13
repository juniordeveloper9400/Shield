import { ConflictException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, desc, eq, inArray } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import {
  agent,
  agentCustomer,
  agentRequest,
  agentWithdrawal,
  assembly,
  district,
  lsgd,
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

    const [created] = await this.db
      .insert(agentRequest)
      .values({ ...dto, name: member.name, phone: member.phone })
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
          memberId: (await this.resolveMemberIdByPhone(tx, req.phone)) ?? undefined,
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

  private async resolveMemberIdByPhone(tx: Database, phone: string): Promise<number | null> {
    const [found] = await tx.select({ id: users.id }).from(users).where(eq(users.phone, phone)).limit(1);
    return found?.id ?? null;
  }

  // ---- Team tree -------------------------------------------------------

  async getTeamForMember(memberId: number) {
    const self = await this.getApprovedAgentByMemberIdOrThrow(memberId);
    const descendants = await this.getDescendants(self.id);
    return { ...self, descendants };
  }

  private async getDescendants(rootId: number) {
    const result: (typeof agent.$inferSelect)[] = [];
    let frontier = [rootId];
    while (frontier.length > 0) {
      const children = await this.db.select().from(agent).where(inArray(agent.parentId, frontier));
      if (children.length === 0) break;
      result.push(...children);
      frontier = children.map((c) => c.id);
    }
    return result;
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

  async listCustomers(memberId: number) {
    const self = await this.getApprovedAgentByMemberIdOrThrow(memberId);
    return this.db.select().from(agentCustomer).where(eq(agentCustomer.agentId, self.id)).orderBy(desc(agentCustomer.createdAt));
  }

  async requestWithdrawal(memberId: number, dto: RequestWithdrawalDto) {
    const self = await this.getApprovedAgentByMemberIdOrThrow(memberId);
    const available = Number(self.earned) - Number(self.redeemed);
    if (dto.amount > available) {
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Amount exceeds available earnings' } });
    }

    const [created] = await this.db
      .insert(agentWithdrawal)
      .values({ agentId: self.id, amount: dto.amount.toString(), requestedOn: new Date().toISOString().slice(0, 10) })
      .returning();
    return created;
  }

  async listWithdrawalsForStaff() {
    return this.db.select().from(agentWithdrawal).where(eq(agentWithdrawal.status, 'PENDING')).orderBy(agentWithdrawal.requestedOn);
  }

  async resolveWithdrawal(withdrawalId: number, dto: ResolveWithdrawalDto) {
    return this.db.transaction(async (tx) => {
      const [found] = await tx.select().from(agentWithdrawal).where(eq(agentWithdrawal.id, withdrawalId)).limit(1);
      if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Withdrawal not found' } });
      if (found.status !== 'PENDING') {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: `Already ${found.status.toLowerCase()}` } });
      }

      const [updated] = await tx
        .update(agentWithdrawal)
        .set({ status: dto.status, processedOn: new Date().toISOString().slice(0, 10) })
        .where(eq(agentWithdrawal.id, withdrawalId))
        .returning();

      if (dto.status === 'PAID') {
        const [theAgent] = await tx.select().from(agent).where(eq(agent.id, found.agentId)).limit(1);
        await tx
          .update(agent)
          .set({ redeemed: (Number(theAgent.redeemed) + Number(found.amount)).toString() })
          .where(eq(agent.id, found.agentId));
      }

      return updated;
    });
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
