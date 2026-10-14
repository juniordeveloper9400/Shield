import { ConflictException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { desc, eq, getTableColumns } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { agent, investor, investorPlanChangeRequest, shieldStore, users } from '../../db/schema';
import type { AdminConvertToInvestorDto, CreatePlanChangeRequestDto, ResolvePlanChangeRequestDto } from './dto';

/**
 * Investor creation is admin-console-driven (adminConvertToInvestor below)
 * rather than self-service — there is no member-filed "request to invest"
 * queue the way app.agent_request exists for agents; the console grants
 * the persona directly. This service also covers the self-service parts:
 * reading your own profile and requesting a plan change.
 */
@Injectable()
export class InvestorService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  async getOwnProfile(memberId: number) {
    return this.getByMemberIdOrThrow(memberId);
  }

  async requestPlanChange(memberId: number, dto: CreatePlanChangeRequestDto) {
    const self = await this.getByMemberIdOrThrow(memberId);
    const [created] = await this.db
      .insert(investorPlanChangeRequest)
      .values({ investorId: self.id, requestedPlanType: dto.requestedPlanType, note: dto.note })
      .returning();
    return created;
  }

  async listOwnPlanChangeRequests(memberId: number) {
    const self = await this.getByMemberIdOrThrow(memberId);
    return this.db
      .select()
      .from(investorPlanChangeRequest)
      .where(eq(investorPlanChangeRequest.investorId, self.id))
      .orderBy(desc(investorPlanChangeRequest.createdAt));
  }

  async listPendingPlanChangeRequests() {
    return this.db
      .select()
      .from(investorPlanChangeRequest)
      .where(eq(investorPlanChangeRequest.status, 'REQUESTED'))
      .orderBy(investorPlanChangeRequest.createdAt);
  }

  async resolvePlanChangeRequest(requestId: number, dto: ResolvePlanChangeRequestDto) {
    return this.db.transaction(async (tx) => {
      const [found] = await tx
        .select()
        .from(investorPlanChangeRequest)
        .where(eq(investorPlanChangeRequest.id, requestId))
        .limit(1);
      if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Plan change request not found' } });
      if (found.status !== 'REQUESTED') {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: `Already ${found.status.toLowerCase()}` } });
      }

      const [updated] = await tx
        .update(investorPlanChangeRequest)
        .set({ status: dto.status, resolvedAt: new Date() })
        .where(eq(investorPlanChangeRequest.id, requestId))
        .returning();

      if (dto.status === 'APPROVED') {
        await tx.update(investor).set({ planType: found.requestedPlanType }).where(eq(investor.id, found.investorId));
      }

      return updated;
    });
  }

  // ---- Admin: direct persona grant ---------------------------------------
  // The Users page's own "Make investor" action, mirroring
  // AgentService.adminConvertToAgent's own shape: a registered member with
  // no existing persona gets one, atomically.

  async adminConvertToInvestor(memberId: number, dto: AdminConvertToInvestorDto) {
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

      let investedStoreId: number | null = null;
      if (dto.storeCode) {
        const [store] = await tx.select({ id: shieldStore.id }).from(shieldStore).where(eq(shieldStore.code, dto.storeCode)).limit(1);
        investedStoreId = store?.id ?? null;
      }

      const [created] = await tx
        .insert(investor)
        .values({
          memberId,
          code: `SHD-INV-${Date.now().toString(36).toUpperCase()}`,
          name: member.name,
          phone: member.phone,
          investedStoreId,
          totalUnits: dto.totalUnits,
          unitPrice: dto.unitPrice.toString(),
          investedSince: new Date().toISOString().slice(0, 10),
          roiPercent: dto.roiPercent.toString(),
          planType: dto.planType,
        })
        .returning();
      return created;
    });
  }

  /** Drops the member back to a plain member — removes their app.investor row. */
  async adminRevokeInvestor(memberId: number): Promise<void> {
    await this.db.delete(investor).where(eq(investor.memberId, memberId));
  }

  /**
   * Joined to the invested branch's stable code — the client
   * (`lib/data/neon/persona_repository.dart`'s `RemoteInvestor.storeCode`,
   * now gone) reads the branch by code, not the backend's own numeric id.
   */
  private async getByMemberIdOrThrow(memberId: number) {
    const [found] = await this.db
      .select({ ...getTableColumns(investor), storeCode: shieldStore.code })
      .from(investor)
      .leftJoin(shieldStore, eq(shieldStore.id, investor.investedStoreId))
      .where(eq(investor.memberId, memberId))
      .limit(1);
    if (!found) throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Not an investor' } });
    return found;
  }
}
