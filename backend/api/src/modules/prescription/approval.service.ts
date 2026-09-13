import { BadRequestException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, eq, inArray } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { approval, approvalItem, prescription } from '../../db/schema';
import type { AdminRole } from '../auth/session.types';
import type { RaiseApprovalDto, RespondApprovalDto } from './dto';

@Injectable()
export class ApprovalService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  async raise(role: AdminRole, storeId: number | null, dto: RaiseApprovalDto) {
    const [rx] = await this.db.select().from(prescription).where(eq(prescription.id, dto.prescriptionId)).limit(1);
    if (!rx) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Prescription not found' } });
    if (role !== 'SUPERADMIN' && rx.storeId !== storeId) {
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Prescription does not belong to this store' } });
    }

    return this.db.transaction(async (tx) => {
      const [created] = await tx
        .insert(approval)
        .values({
          memberId: rx.memberId,
          prescriptionId: rx.id,
          code: `APR-${Date.now().toString(36).toUpperCase()}`,
          pharmacistNote: dto.pharmacistNote,
          raisedOn: new Date().toISOString().slice(0, 10),
        })
        .returning();

      const items = await tx
        .insert(approvalItem)
        .values(dto.items.map((item) => ({ ...item, price: item.price.toString(), approvalId: created.id })))
        .returning();

      return { ...created, items };
    });
  }

  async listForMember(memberId: number) {
    return this.db.select().from(approval).where(eq(approval.memberId, memberId)).orderBy(approval.createdAt);
  }

  async getForMember(memberId: number, id: number) {
    const found = await this.getOwnedByMemberOrThrow(id, memberId);
    const items = await this.db.select().from(approvalItem).where(eq(approvalItem.approvalId, id));
    return { ...found, items };
  }

  /** Requires the response to cover every item on the approval, exactly once. */
  async respond(memberId: number, id: number, dto: RespondApprovalDto) {
    const found = await this.getOwnedByMemberOrThrow(id, memberId);
    if (found.status !== 'PENDING' && found.status !== 'ON_HOLD') {
      throw new ForbiddenException({
        error: { code: 'FORBIDDEN', message: `Approval already ${found.status.toLowerCase()}` },
      });
    }

    const existingItems = await this.db.select().from(approvalItem).where(eq(approvalItem.approvalId, id));
    const existingIds = new Set(existingItems.map((i) => i.id));
    const respondedIds = new Set(dto.items.map((i) => i.approvalItemId));
    const allCovered =
      existingItems.every((i) => respondedIds.has(i.id)) && dto.items.every((i) => existingIds.has(i.approvalItemId));
    if (!allCovered) {
      throw new BadRequestException({
        error: { code: 'VALIDATION_ERROR', message: 'Response must cover every item on this approval, exactly' },
      });
    }

    return this.db.transaction(async (tx) => {
      for (const item of dto.items) {
        await tx.update(approvalItem).set({ isAccepted: item.isAccepted }).where(eq(approvalItem.id, item.approvalItemId));
      }

      const allAccepted = dto.items.every((i) => i.isAccepted);
      const noneAccepted = dto.items.every((i) => !i.isAccepted);
      const finalStatus = allAccepted ? 'APPROVED' : noneAccepted ? 'REJECTED' : 'PARTIALLY_APPROVED';

      const [updated] = await tx
        .update(approval)
        .set({ status: finalStatus, respondedAt: new Date() })
        .where(eq(approval.id, id))
        .returning();

      const items = await tx.select().from(approvalItem).where(eq(approvalItem.approvalId, id));
      return { ...updated, items };
    });
  }

  async listForStaff(role: AdminRole, storeId: number | null) {
    if (role === 'SUPERADMIN') {
      return this.db.select().from(approval).orderBy(approval.createdAt);
    }
    if (storeId == null) return [];

    // approval has no store_id of its own — scoped through its prescription's store.
    const storePrescriptions = await this.db
      .select({ id: prescription.id })
      .from(prescription)
      .where(eq(prescription.storeId, storeId));
    const ids = storePrescriptions.map((p) => p.id);
    if (ids.length === 0) return [];
    return this.db.select().from(approval).where(inArray(approval.prescriptionId, ids)).orderBy(approval.createdAt);
  }

  private async getOwnedByMemberOrThrow(id: number, memberId: number) {
    const [found] = await this.db
      .select()
      .from(approval)
      .where(and(eq(approval.id, id), eq(approval.memberId, memberId)))
      .limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Approval not found' } });
    return found;
  }
}
