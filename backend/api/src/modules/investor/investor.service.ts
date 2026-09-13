import { ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { desc, eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { investor, investorPlanChangeRequest } from '../../db/schema';
import type { CreatePlanChangeRequestDto, ResolvePlanChangeRequestDto } from './dto';

/**
 * Investor creation stays admin-console-driven for now — see
 * backend/docs/build-playbook.md M7 scope note. This service covers the
 * self-service parts: reading your own profile and requesting a plan change.
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

  private async getByMemberIdOrThrow(memberId: number) {
    const [found] = await this.db.select().from(investor).where(eq(investor.memberId, memberId)).limit(1);
    if (!found) throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Not an investor' } });
    return found;
  }
}
