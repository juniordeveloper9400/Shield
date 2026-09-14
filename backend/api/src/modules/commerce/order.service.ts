import { ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, desc, eq, isNull } from 'drizzle-orm';
import { randomBytes } from 'node:crypto';
import { DRIZZLE, type Database } from '../../db/client';
import {
  bill,
  cartLine,
  memberAddress,
  order,
  orderLine,
  orderReceipt,
  orderTrackStep,
  referral,
  rewardPointTransaction,
  users,
} from '../../db/schema';
import type { AdminRole } from '../auth/session.types';
import { CartService } from './cart.service';
import { assertLegalTransition, type OrderStatus } from './order-status';
import type { CheckoutDto, SendBillDto, SubmitOrderReceiptDto, UpdateOrderStatusDto } from './dto';

/** ₹100 → 10 points (ten rupees to the point) — mirrors the client's own `RewardsService.pointsForSpend`. */
const RUPEES_PER_POINT = 10;

@Injectable()
export class OrderService {
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    private readonly cartService: CartService,
  ) {}

  async checkout(memberId: number, dto: CheckoutDto) {
    const theCart = await this.cartService.getOrCreateCart(memberId);
    const lines = await this.db.select().from(cartLine).where(eq(cartLine.cartId, theCart.id));

    if (lines.length === 0) {
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Cart is empty' } });
    }

    if (dto.deliveryAddressId !== undefined) {
      const [owned] = await this.db
        .select({ id: memberAddress.id })
        .from(memberAddress)
        .where(and(eq(memberAddress.id, dto.deliveryAddressId), eq(memberAddress.memberId, memberId), isNull(memberAddress.deletedAt)))
        .limit(1);
      if (!owned) {
        throw new ForbiddenException({
          error: { code: 'FORBIDDEN', message: 'deliveryAddressId does not belong to the authenticated member' },
        });
      }
    }

    // Every total is computed here, server-side, from the cart lines that
    // were themselves priced from live product rows at add-to-cart time —
    // a client-submitted amount is never trusted. See cart.service.ts.
    const mrpTotal = lines.reduce((sum, l) => sum + Number(l.mrp) * l.qty, 0);
    const paidTotal = lines.reduce((sum, l) => sum + Number(l.price) * l.qty, 0);
    const itemCount = lines.reduce((sum, l) => sum + l.qty, 0);

    // Orders are store-scoped for staff (see FRD §3 / ERD §4 "pharmacy
    // operations require a store scope"). Assign the member's home store
    // at checkout — an order for a member with no home store set will not
    // appear in any staff store-scoped list, a known limitation until a
    // store-assignment flow is designed.
    const [member] = await this.db.select({ homeStoreId: users.homeStoreId }).from(users).where(eq(users.id, memberId)).limit(1);

    return this.db.transaction(async (tx) => {
      const [created] = await tx
        .insert(order)
        .values({
          memberId,
          code: `SH-${Date.now().toString(36).toUpperCase()}${randomBytes(2).toString('hex').toUpperCase()}`,
          itemCount,
          mrpTotal: mrpTotal.toFixed(2),
          paidTotal: paidTotal.toFixed(2),
          storeId: member?.homeStoreId ?? null,
          deliveryAddressId: dto.deliveryAddressId,
          paymentMethodId: dto.paymentMethodId,
          reference: dto.reference,
          placedOn: new Date().toISOString().slice(0, 10),
        })
        .returning();

      await tx.insert(orderLine).values(
        lines.map((l) => ({
          orderId: created.id,
          productId: l.productId,
          name: l.name,
          pack: l.pack,
          unitPrice: l.price,
          mrp: l.mrp,
          qty: l.qty,
        })),
      );

      await tx.insert(orderTrackStep).values({
        orderId: created.id,
        sort: 0,
        title: 'Order placed',
        state: 'CURRENT',
        occurredAt: new Date(),
      });

      await tx.delete(cartLine).where(eq(cartLine.cartId, theCart.id));

      // A paid order (always true here — every cart line is priced) earns
      // reward points and advances the buyer's own inbound referral, the
      // same two things `RewardsService.awardForOrder` and
      // `ReferralService.markTransacted` used to do as separate client
      // calls after the fact — now automatic, in the same transaction as
      // the order itself.
      if (paidTotal > 0) {
        const points = Math.floor(paidTotal / RUPEES_PER_POINT);
        if (points > 0) {
          await tx.insert(rewardPointTransaction).values({
            memberId,
            points,
            reason: 'ORDER',
            note: `Order ${created.code}`,
            refType: 'order',
            refId: created.id,
          });
          const currentPoints = await this.currentRewardPoints(tx, memberId);
          await tx
            .update(users)
            .set({ rewardPoints: currentPoints + points })
            .where(eq(users.id, memberId));
        }

        await tx
          .update(referral)
          .set({ status: 'TRANSACTED', transactedAt: new Date() })
          .where(and(eq(referral.inviteeMemberId, memberId), eq(referral.status, 'REGISTERED')));
      }

      return created;
    });
  }

  private async currentRewardPoints(tx: Database, memberId: number): Promise<number> {
    const [row] = await tx.select({ rewardPoints: users.rewardPoints }).from(users).where(eq(users.id, memberId)).limit(1);
    return row?.rewardPoints ?? 0;
  }

  async listForMember(memberId: number) {
    return this.db.select().from(order).where(eq(order.memberId, memberId)).orderBy(desc(order.placedAt));
  }

  async getForMember(memberId: number, orderId: number) {
    const found = await this.getOwnedByMemberOrThrow(orderId, memberId);
    const lines = await this.db.select().from(orderLine).where(eq(orderLine.orderId, orderId));
    const steps = await this.db
      .select()
      .from(orderTrackStep)
      .where(eq(orderTrackStep.orderId, orderId))
      .orderBy(orderTrackStep.sort);
    return { ...found, lines, steps };
  }

  /** A manual-transfer claim against an order the caller owns — see `SubmitOrderReceiptDto`'s doc. */
  async submitReceipt(memberId: number, orderId: number, dto: SubmitOrderReceiptDto) {
    await this.getOwnedByMemberOrThrow(orderId, memberId);
    const [created] = await this.db
      .insert(orderReceipt)
      .values({
        orderId,
        payerName: dto.payerName,
        reference: dto.reference,
        amount: dto.amount?.toFixed(2),
        fileName: dto.fileName,
      })
      .returning();
    return created;
  }

  async getBillForMember(memberId: number, orderId: number) {
    await this.getOwnedByMemberOrThrow(orderId, memberId);
    const [theBill] = await this.db.select().from(bill).where(eq(bill.orderId, orderId)).limit(1);
    if (!theBill) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'No bill sent for this order yet' } });
    return theBill;
  }

  // ---- Staff (store-scoped, SUPERADMIN sees every store) -----------------

  async listForStaff(role: AdminRole, storeId: number | null) {
    if (role === 'SUPERADMIN') {
      return this.db.select().from(order).orderBy(desc(order.placedAt));
    }
    if (storeId == null) return [];
    return this.db.select().from(order).where(eq(order.storeId, storeId)).orderBy(desc(order.placedAt));
  }

  async updateStatus(role: AdminRole, storeId: number | null, orderId: number, dto: UpdateOrderStatusDto) {
    const found = await this.getOwnedByStaffOrThrow(orderId, role, storeId);
    assertLegalTransition(found.status as OrderStatus, dto.status);

    const [updated] = await this.db.update(order).set({ status: dto.status }).where(eq(order.id, orderId)).returning();

    await this.db.insert(orderTrackStep).values({
      orderId,
      sort: 999,
      title: dto.status.replace(/_/g, ' '),
      detail: dto.detail,
      state: dto.status === 'DELIVERED' || dto.status === 'CANCELLED' ? 'DONE' : 'CURRENT',
      occurredAt: new Date(),
    });

    return updated;
  }

  async sendBill(role: AdminRole, storeId: number | null, orderId: number, dto: SendBillDto) {
    await this.getOwnedByStaffOrThrow(orderId, role, storeId);

    const [existing] = await this.db.select({ id: bill.id }).from(bill).where(eq(bill.orderId, orderId)).limit(1);
    if (existing) {
      const [updated] = await this.db
        .update(bill)
        .set({ image: dto.image, updatedAt: new Date() })
        .where(eq(bill.orderId, orderId))
        .returning();
      return updated;
    }
    const [created] = await this.db.insert(bill).values({ orderId, image: dto.image }).returning();
    return created;
  }

  private async getOwnedByMemberOrThrow(orderId: number, memberId: number) {
    const [found] = await this.db
      .select()
      .from(order)
      .where(and(eq(order.id, orderId), eq(order.memberId, memberId)))
      .limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Order not found' } });
    return found;
  }

  private async getOwnedByStaffOrThrow(orderId: number, role: AdminRole, storeId: number | null) {
    const conditions = [eq(order.id, orderId)];
    if (role !== 'SUPERADMIN') {
      if (storeId == null) {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Staff account has no store assigned' } });
      }
      conditions.push(eq(order.storeId, storeId));
    }

    const [found] = await this.db
      .select()
      .from(order)
      .where(and(...conditions))
      .limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Order not found' } });
    return found;
  }
}
