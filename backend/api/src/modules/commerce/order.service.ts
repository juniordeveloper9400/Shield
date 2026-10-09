import { ConflictException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, desc, eq, getTableColumns, inArray, isNull, sql } from 'drizzle-orm';
import { randomBytes, randomUUID } from 'node:crypto';
import { DRIZZLE, type Database } from '../../db/client';
import {
  bill,
  billLine,
  cartLine,
  chartOfAccount,
  journalEntry,
  journalLine,
  memberAddress,
  order,
  orderLine,
  orderReceipt,
  orderTrackStep,
  paymentMethod,
  postingRule,
  prescription,
  prescriptionImage,
  prescriptionOrder,
  referral,
  rewardPointTransaction,
  shieldStore,
  users,
  wallet,
  walletCard,
  walletEntry,
} from '../../db/schema';
import type { AdminRole } from '../auth/session.types';
import { availablePlanAllowance, toIsoDate } from '../wallet/wallet-month';
import { CartService } from './cart.service';
import { assertLegalTransition, type OrderStatus } from './order-status';
import { cancelOrderForMember } from './member-withdrawal';
import type {
  CheckoutDto,
  ReceiveBillPaymentDto,
  ReviewOrderDto,
  SendBillDto,
  SendInvoiceDto,
  SendPictureDto,
  SubmitOrderReceiptDto,
  UpdateOrderStatusDto,
} from './dto';
import { ReferralService } from '../wallet/referral.service';
import { postRewardPointsIssued } from '../ledger/reward-points-ledger';

/** ₹100 → 10 points (ten rupees to the point) — mirrors the client's own `RewardsService.pointsForSpend`. */
const RUPEES_PER_POINT = 10;

@Injectable()
export class OrderService {
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    private readonly cartService: CartService,
    private readonly referrals: ReferralService,
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

    // migration 0031: resolve the chosen payment method's own `code` —
    // 'wallet' settles instantly off the balance, 'cash' (or anything else,
    // including none chosen) leaves the order PENDING until it is collected
    // in person. Read before the transaction opens; nothing here writes.
    let paymentMethodCode: string | null = null;
    if (dto.paymentMethodId !== undefined) {
      const [method] = await this.db
        .select({ code: paymentMethod.code })
        .from(paymentMethod)
        .where(eq(paymentMethod.id, dto.paymentMethodId))
        .limit(1);
      paymentMethodCode = method?.code ?? null;
    }

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
          fulfillmentType: dto.fulfillmentType,
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

      // A priced order earns reward points, as `RewardsService.awardForOrder`
      // used to do as a separate client call — now automatic, in the same
      // transaction as the order itself.
      //
      // Advancing the buyer's own inbound referral is a different matter and
      // is NOT done here: a referral counts when the order is *paid*, not
      // when it is merely placed. A cash or pickup order is still owed, and
      // is settled later at the counter (the console flips it PAID; migration
      // 0052's trigger advances the referral then). A wallet payment that
      // covers the order settles it below, so that is where it advances.
      if (paidTotal > 0) {
        const points = Math.floor(paidTotal / RUPEES_PER_POINT);
        if (points > 0) {
          const [rewardTxn] = await tx
            .insert(rewardPointTransaction)
            .values({
              memberId,
              points,
              reason: 'ORDER',
              note: `Order ${created.code}`,
              refType: 'order',
              refId: created.id,
            })
            .returning();
          await postRewardPointsIssued(tx, {
            rewardPointTransactionId: rewardTxn.id,
            points,
            reason: `order ${created.code}`,
          });
          const currentPoints = await this.currentRewardPoints(tx, memberId);
          await tx
            .update(users)
            .set({ rewardPoints: currentPoints + points })
            .where(eq(users.id, memberId));
        }

      }

      // migration 0031: a wallet checkout settles instantly — debit the
      // balance and post the ledger line in the same transaction as the
      // order itself, then flip the order to PAID. If the balance cannot
      // cover it (a stale client-side balance, or two checkouts racing),
      // the whole transaction rolls back — no half-placed order.
      //
      // dto.walletAmount lets the client cap this at less than the order's
      // full price — the member's monthly wallet allowance, worked out
      // client-side by WalletService.walletShareOf. Clamped to [0, paidTotal]
      // so a bad or stale client figure can never debit more than the order
      // is actually worth. When it covers the whole total the order still
      // flips PAID exactly as before; when it doesn't, only the wallet's
      // share is debited and the order is left PENDING — same as a cash
      // order — for the member to settle the rest another way.
      if (paymentMethodCode === 'wallet' && paidTotal > 0) {
        const walletAmount = dto.walletAmount != null
          ? Math.min(Math.max(dto.walletAmount, 0), paidTotal)
          : paidTotal;

        if (walletAmount > 0) {
          await this.debitWalletForOrder(tx, {
            memberId,
            orderId: created.id,
            amount: walletAmount,
            label: walletAmount < paidTotal
              ? `Order ${created.code} (wallet share)`
              : `Order ${created.code}`,
          });
        }

        if (walletAmount >= paidTotal) {
          const [paid] = await tx
            .update(order)
            .set({ paymentStatus: 'PAID', paidAt: new Date() })
            .where(eq(order.id, created.id))
            .returning();
          // This buyer's first paid order is the event (besides a plan
          // activation — WalletService.approveCard) that moves their inviter's
          // direct-referral count, and so can carry them across a
          // referral_level rung.
          await this.advanceInviterReferral(tx, memberId);
          return paid;
        }
      }

      return created;
    });
  }

  /**
   * The buyer's own inbound referral, REGISTERED -> TRANSACTED, and the
   * inviter's level points if that carries them across a rung. Only ever moves
   * a referral forward, so calling it for a member nobody referred, or for one
   * whose referral has already advanced, does nothing. The same thing
   * migration 0052's trigger does when any order becomes PAID (including
   * ones the console settles), so the two are safe together.
   */
  private async advanceInviterReferral(tx: Database, buyerMemberId: number): Promise<void> {
    const [advanced] = await tx
      .update(referral)
      .set({ status: 'TRANSACTED', transactedAt: new Date() })
      .where(and(eq(referral.inviteeMemberId, buyerMemberId), eq(referral.status, 'REGISTERED')))
      .returning({ inviterMemberId: referral.inviterMemberId });
    if (advanced) {
      await this.referrals.awardLevelPointsIfCrossed(tx, advanced.inviterMemberId);
    }
  }

  /**
   * Debits [amount] off the member's wallet and posts the matching `SPEND`
   * ledger line against [orderId] — the one debit path a wallet checkout
   * ([checkout]) goes through, so the guard against overdraw only lives in
   * one place. A priced bill's own wallet settlement ("Pay now") is a
   * *different* path deliberately — see shieldweb's `src/api/billPayments.ts`
   * doc for why it isn't this method behind a member-facing route anymore.
   *
   * Runs inside the caller's own transaction ([tx]) so the debit and
   * whatever it is settling commit or roll back together. Throws (never
   * returns false) — the caller's transaction is already open, so there is
   * nothing sensible to do but abort it.
   */
  private async debitWalletForOrder(
    tx: Database,
    params: { memberId: number; orderId: number; amount: number; label: string },
  ) {
    const [theWallet] = await tx.select().from(wallet).where(eq(wallet.memberId, params.memberId)).limit(1);
    const balance = theWallet ? Number(theWallet.balance) : 0;
    if (!theWallet || balance < params.amount) {
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Insufficient wallet balance' } });
    }

    await tx
      .update(wallet)
      .set({ balance: (balance - params.amount).toString(), updatedAt: new Date() })
      .where(eq(wallet.id, theWallet.id));

    await tx.insert(walletEntry).values({
      walletId: theWallet.id,
      kind: 'SPEND',
      label: params.label,
      amount: (-params.amount).toString(),
      occurredOn: new Date().toISOString().slice(0, 10),
      orderId: params.orderId,
    });
  }

  private async currentRewardPoints(tx: Database, memberId: number): Promise<number> {
    const [row] = await tx.select({ rewardPoints: users.rewardPoints }).from(users).where(eq(users.id, memberId)).limit(1);
    return row?.rewardPoints ?? 0;
  }

  /**
   * Every order the member has placed, newest first. Left-joined against
   * `bill` (0-or-1 per order) so a prescription order's priced amount, its
   * paid/pending status, and how much of it was actually discounted —
   * `billAmount`/`billStatus`/`billDiscount` on the client's `Purchase`
   * (`billDiscount` is what "Your earnings" counts as saved, not the
   * checkout-time mrpTotal/paidTotal gap — see `MemberEarnings`'s own doc)
   * — come back alongside the order's own columns without a second round
   * trip per row.
   */
  async listForMember(memberId: number) {
    return this.db
      .select({
        ...getTableColumns(order),
        billAmount: bill.amount,
        billStatus: bill.status,
        billDiscount: bill.discountAmount,
      })
      .from(order)
      .leftJoin(bill, eq(bill.orderId, order.id))
      .where(eq(order.memberId, memberId))
      .orderBy(desc(order.placedAt));
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

  /**
   * The member cancels their own order — allowed only while the store has not
   * touched it (see member-withdrawal.ts); otherwise 409 ORDER_LOCKED and the
   * store cancels it from the admin console. Idempotent for a retry.
   */
  async cancelForMember(memberId: number, orderId: number) {
    await this.getOwnedByMemberOrThrow(orderId, memberId);
    await this.db.transaction((tx) => cancelOrderForMember(tx, orderId));
    return { ok: true as const, status: 'CANCELLED' as const };
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

  /**
   * The bill the store sent for this order, plus the itemised `invoice` the
   * member's app prints under it: the items with their prices, who sold it
   * (the store), who it is billed to and where it goes. The bill's own columns
   * are unchanged, so existing clients keep working.
   */
  async getBillForMember(memberId: number, orderId: number) {
    const theOrder = await this.getOwnedByMemberOrThrow(orderId, memberId);
    const [theBill] = await this.db.select().from(bill).where(eq(bill.orderId, orderId)).limit(1);
    if (!theBill) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'No bill sent for this order yet' } });
    return { ...theBill, invoice: await this.buildInvoice(theOrder, theBill.id) };
  }

  private async buildInvoice(theOrder: typeof order.$inferSelect, billId: number) {
    const [customer] = await this.db
      .select({ name: users.name, phone: users.phone })
      .from(users)
      .where(eq(users.id, theOrder.memberId))
      .limit(1);

    const [store] =
      theOrder.storeId === null
        ? []
        : await this.db
            .select({
              name: shieldStore.name,
              area: shieldStore.area,
              city: shieldStore.city,
              state: shieldStore.state,
              pincode: shieldStore.pincode,
              phone: shieldStore.phone,
            })
            .from(shieldStore)
            .where(eq(shieldStore.id, theOrder.storeId))
            .limit(1);

    // Not filtered on `deletedAt`: an address the member has since removed is
    // still where this order went, and the invoice is a record of that.
    const [address] =
      theOrder.deliveryAddressId === null
        ? []
        : await this.db
            .select({
              house: memberAddress.house,
              area: memberAddress.area,
              landmark: memberAddress.landmark,
              city: memberAddress.city,
              state: memberAddress.state,
              pincode: memberAddress.pincode,
            })
            .from(memberAddress)
            .where(eq(memberAddress.id, theOrder.deliveryAddressId))
            .limit(1);

    // The bill's own lines — what the counter typed in when it priced the bill.
    let lines: { name: string; pack: string; unitPrice: string; qty: number }[] = await this.db
      .select({ name: billLine.name, pack: billLine.pack, unitPrice: billLine.unitPrice, qty: billLine.qty })
      .from(billLine)
      .where(eq(billLine.billId, billId))
      .orderBy(billLine.id);

    // A bill that was only a picture has none, so fall back to the order's own
    // lines the counter could supply. `stock_status` (migration 0044) is
    // counter-only and deliberately not on the drizzle model — `getForMember`
    // selects every column of it — so it is filtered here in SQL and never
    // returned.
    if (lines.length === 0) {
      const result = await this.db.execute(sql`
        SELECT name, pack, unit_price AS "unitPrice", qty
        FROM app.order_line
        WHERE order_id = ${theOrder.id} AND stock_status = 'AVAILABLE'
        ORDER BY id
      `);
      lines = result.rows as typeof lines;
    }

    return {
      number: theOrder.code,
      placedAt: theOrder.placedAt,
      status: theOrder.status,
      fulfillmentType: theOrder.fulfillmentType,
      paymentStatus: theOrder.paymentStatus,
      paidAt: theOrder.paidAt,
      paidTotal: theOrder.paidTotal,
      deliveryFee: theOrder.deliveryFee,
      customer: customer ?? null,
      store: store ?? null,
      deliveryAddress: address ?? null,
      lines,
    };
  }

  /**
   * The prescription(s) submitted into this order, via `prescription_order`
   * (one row per prescription — `submitForOrder` writes one for every id it
   * was given). Empty for a standard order, which never has one. `image`
   * carries the member's own uploaded scan's first page (a `data:` URI —
   * see `PrescriptionService.upload`'s own validation and
   * `prescriptionImage`, migration 0040) — a representative thumbnail for
   * the "Prescription uploaded" card on order tracking, as opposed to a
   * generic icon standing in for it. The full page-by-page set is only
   * needed by the pharmacy review flow, not this tracking card.
   */
  async getPrescriptionsForOrder(memberId: number, orderId: number) {
    await this.getOwnedByMemberOrThrow(orderId, memberId);
    const rows = await this.db
      .select({
        id: prescription.id,
        code: prescription.code,
        doctor: prescription.doctor,
        status: prescription.status,
      })
      .from(prescriptionOrder)
      .innerJoin(prescription, eq(prescription.id, prescriptionOrder.prescriptionId))
      .where(eq(prescriptionOrder.orderId, orderId));
    if (rows.length === 0) return rows.map((r) => ({ ...r, image: null }));

    const firstImages = await this.db
      .select({ prescriptionId: prescriptionImage.prescriptionId, image: prescriptionImage.image })
      .from(prescriptionImage)
      .where(
        and(
          inArray(prescriptionImage.prescriptionId, rows.map((r) => r.id)),
          eq(prescriptionImage.sort, 0),
        ),
      );
    const imageByRx = new Map(firstImages.map((i) => [i.prescriptionId, i.image]));
    return rows.map((r) => ({ ...r, image: imageByRx.get(r.id) ?? null }));
  }

  /**
   * This order's own line items with a picture to show against each one —
   * `app.order_line` left-joined to `app.product` on the `productId` pinned
   * at checkout for `image`, which the line itself does not carry. Raw SQL,
   * the same way `buildInvoice`'s own order-line read is: `stock_status`
   * (migration 0044) is counter-only and deliberately left off the Drizzle
   * model, so it can only be filtered here, the same "never shown to the
   * member" rule the invoice's own lines already follow.
   *
   * Empty for a prescription order, which never gets `order_line` rows (see
   * `PrescriptionService.submitForOrder` — it only ever inserts
   * `prescription` / `prescription_medicine`). `image` is null when the line
   * carries no `productId` (a stale cart add that never resolved one — see
   * `checkout`'s own line-mapping) or the product has since been deleted; the
   * line itself (name, pack, qty) still prints either way.
   */
  async getItemsForOrder(memberId: number, orderId: number) {
    await this.getOwnedByMemberOrThrow(orderId, memberId);
    const result = await this.db.execute(sql`
      SELECT ol.name, ol.pack, ol.qty,
             ol.unit_price AS "unitPrice", ol.mrp,
             p.image
      FROM app.order_line ol
      LEFT JOIN app.product p ON p.id = ol.product_id
      WHERE ol.order_id = ${orderId} AND ol.stock_status = 'AVAILABLE'
      ORDER BY ol.id
    `);
    return result.rows as { name: string; pack: string; qty: number; unitPrice: string; mrp: string; image: string | null }[];
  }

  // ---- Staff (store-scoped; SUPERADMIN and ADMIN see every store) --------

  async listForStaff(role: AdminRole, storeId: number | null) {
    if (role === 'SUPERADMIN' || role === 'ADMIN') {
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

    return this.db.transaction(async (tx) => {
      const [existing] = await tx.select().from(bill).where(eq(bill.orderId, orderId)).limit(1);
      // A blank image keeps whatever the bill already had — same rule
      // shieldweb's own direct-SQL sendOrderInvoice applies — so a
      // line-items-only re-price (no new photo taken) never blanks out an
      // image a caller sent earlier.
      const image = dto.image ? dto.image : existing?.image ?? '';
      const amount = dto.amount ?? existing?.amount ?? '0';

      let billId: number;
      if (existing) {
        await tx
          .update(bill)
          .set({
            image,
            amount: amount.toString(),
            discountAmount: dto.discountAmount.toString(),
            sentAt: new Date(),
            updatedAt: new Date(),
          })
          .where(eq(bill.id, existing.id));
        billId = existing.id;
      } else {
        const [created] = await tx
          .insert(bill)
          .values({ orderId, image, amount: amount.toString(), discountAmount: dto.discountAmount.toString() })
          .returning({ id: bill.id });
        billId = created.id;
      }

      if (dto.lines) {
        await tx.delete(billLine).where(eq(billLine.billId, billId));
        if (dto.lines.length > 0) {
          await tx.insert(billLine).values(
            dto.lines.map((line) => ({
              billId,
              name: line.name,
              pack: line.pack ?? '',
              unitPrice: line.unitPrice.toString(),
              qty: line.qty,
            })),
          );
        }
      }

      const [result] = await tx.select().from(bill).where(eq(bill.id, billId)).limit(1);
      return result;
    });
  }

  /**
   * Collects what the member's wallet can cover on a priced, unpaid bill —
   * draws up to the amount still owed (`walletAmount = min(balance, owed)`)
   * and records it on the bill (`wallet_collected`) with a SPEND ledger line.
   *
   * Whatever the wallet could not cover is NOT assumed collected. It comes
   * back as `cashAmount` (still owed) with `settled: false`, and the bill and
   * order stay unpaid: the counter then takes it as GPay and/or cash through
   * `receiveBillPayment`, or leaves it on the Manual cash list for later. Only
   * when the wallet covers everything is the bill marked PAID here
   * (`settled: true`, `cashAmount: 0`). The amount owed is worked out from
   * what is already on the bill, under a row lock, so a repeated call can
   * never draw the same rupee twice.
   *
   * Triggered from the admin console only, after staff has read an OTP back
   * to the member over Firebase Phone Auth (shieldweb's own
   * `src/lib/deliveryOtp.ts`) — that check is client-side today; this
   * endpoint's own trust boundary is "a valid staff session with the right
   * role", not an independent server-side OTP check.
   */
  /**
   * Posts a store's cash/GPay/wallet receipt against a shop order's bill to
   * the ledger (migrations 0074–0076). The account mapping is the same
   * `app.posting_rule` migration 0075's database functions read —
   * reproduced here in TypeScript because order/bill collection lives in
   * this service, not a database function. One entry per call, not per
   * order: a cash payment and a later GPay payment on the same bill are two
   * separate postings, each for what that call actually collected.
   *
   * Never blocks the real collection: any problem here (no store, no
   * entity, an unconfigured posting rule) is swallowed, not thrown — the
   * same tolerance migration 0075's own posting blocks use, since this is
   * new, still-unreviewed infrastructure riding alongside working code
   * that moves real money.
   */
  private async postOrderCollection(
    tx: Database,
    params: { orderId: number; orderCode: string; storeId: number | null; cash: number; gpay: number; wallet: number },
  ) {
    try {
      if (!params.storeId) return;
      const [store] = await tx.select({ entityId: shieldStore.entityId }).from(shieldStore).where(eq(shieldStore.id, params.storeId));
      if (!store?.entityId) return;

      const mapped = await tx
        .select({ lineRole: postingRule.lineRole, accountId: chartOfAccount.id })
        .from(postingRule)
        .innerJoin(chartOfAccount, eq(chartOfAccount.code, postingRule.accountCode))
        .where(and(eq(postingRule.event, 'order_collected'), inArray(postingRule.lineRole, ['cash_in', 'wallet_in', 'revenue'])));
      const byRole: Record<string, number> = Object.fromEntries(mapped.map((a) => [a.lineRole, a.accountId]));
      if (!byRole.cash_in || !byRole.wallet_in || !byRole.revenue) return;

      // GPay has no line role of its own yet (see migration 0074's header on
      // the activation's cash_in account) — folded into the same "received
      // at store" account as cash until the accountant wants that split.
      const received = params.cash + params.gpay;
      const lines: { accountId: number; debit: string; credit: string }[] = [];
      if (received > 0) lines.push({ accountId: byRole.cash_in, debit: received.toFixed(2), credit: '0' });
      if (params.wallet > 0) lines.push({ accountId: byRole.wallet_in, debit: params.wallet.toFixed(2), credit: '0' });
      const total = received + params.wallet;
      if (total <= 0 || lines.length === 0) return;
      lines.push({ accountId: byRole.revenue, debit: '0', credit: total.toFixed(2) });

      const [entry] = await tx
        .insert(journalEntry)
        .values({
          // Generated explicitly, not left to the column default: pg-mem's
          // gen_random_uuid() mock reuses the same value across repeat
          // inserts in one statement plan (the same limitation
          // agent.e2e-spec.ts documents for the withdrawal functions), and
          // a cash-then-GPay split on one order calls this twice.
          id: randomUUID(),
          entityId: store.entityId,
          postedOn: new Date().toISOString().slice(0, 10),
          sourceTable: 'bill',
          sourceId: `${params.orderId}-${randomBytes(4).toString('hex')}`,
          event: 'order_collected',
          description: `Order ${params.orderCode} collected`,
        })
        .returning();
      if (!entry) return;

      await tx.insert(journalLine).values(lines.map((l) => ({ entryId: entry.id, accountId: l.accountId, debit: l.debit, credit: l.credit })));
    } catch {
      // Ledger posting must never block a real payment being recorded.
    }
  }

  /**
   * What a member's wallet is actually good for right now: their balance,
   * further capped by what's left of this month's Health Pass allowance —
   * same rule as `availablePlanAllowance` (ported from shieldweb's
   * `walletMonth.ts`, which this mirrors so a bill collection never
   * disagrees with the preview staff were already shown). A member with no
   * approved wallet card at all isn't on Health Pass, so nothing caps them
   * beyond their own balance.
   */
  private async availableWalletCapForMember(tx: Database, walletId: number, balance: number): Promise<number> {
    const cards = await tx
      .select({ amount: walletCard.amount, bonus: walletCard.bonus, rechargedExtra: walletCard.rechargedExtra, issuedOn: walletCard.issuedOn })
      .from(walletCard)
      .where(and(eq(walletCard.walletId, walletId), eq(walletCard.status, 'APPROVED')));
    if (cards.length === 0) {
      return balance;
    }
    const entries = await tx
      .select({ kind: walletEntry.kind, amount: walletEntry.amount, occurredOn: walletEntry.occurredOn, createdAt: walletEntry.createdAt })
      .from(walletEntry)
      .where(eq(walletEntry.walletId, walletId))
      .orderBy(walletEntry.createdAt, walletEntry.id);
    return availablePlanAllowance(
      cards.map((c) => ({ loaded: Number(c.amount) + Number(c.bonus) + Number(c.rechargedExtra), issuedOn: toIsoDate(c.issuedOn) })),
      entries.map((e) => ({ kind: e.kind, amount: Number(e.amount), occurredOn: toIsoDate(e.occurredOn) })),
      new Date(),
      balance,
    );
  }

  async collectBillWithWallet(role: AdminRole, storeId: number | null, orderId: number) {
    const found = await this.getOwnedByStaffOrThrow(orderId, role, storeId);

    const [theBill] = await this.db.select().from(bill).where(eq(bill.orderId, orderId)).limit(1);
    if (!theBill) {
      return { ok: false as const, reason: 'No bill has been sent for this order yet.' };
    }
    if (theBill.status === 'PAID') {
      return { ok: false as const, reason: 'This bill is already paid.' };
    }
    if (Number(theBill.amount) <= 0) {
      return { ok: false as const, reason: 'This bill has not been priced yet.' };
    }

    const toPaise = (rupees: number) => Math.round(rupees * 100);
    const fromPaise = (paise: number) => (paise / 100).toFixed(2);

    return this.db.transaction(async (tx) => {
      const [current] = await tx.select().from(bill).where(eq(bill.id, theBill.id)).limit(1).for('update');
      const owedPaise =
        toPaise(Number(current.amount)) -
        toPaise(Number(current.walletCollected)) -
        toPaise(Number(current.cashCollected)) -
        toPaise(Number(current.gpayCollected));
      if (current.status === 'PAID' || owedPaise <= 0) {
        return { ok: false as const, reason: 'Nothing is left to collect on this bill.' };
      }

      const [theWallet] = await tx.select().from(wallet).where(eq(wallet.memberId, found.memberId)).limit(1).for('update');
      const balancePaise = theWallet ? toPaise(Number(theWallet.balance)) : 0;
      // Capped at this month's Health Pass allowance, not just the raw
      // balance — the same figure BillEditorModal's "From wallet" preview
      // already shows staff before they ever send the OTP. Without this, a
      // member who has already used up this month's allowance could still
      // have their whole wallet balance drawn here, disagreeing with what
      // the preview told the counter would happen.
      const walletCapPaise = theWallet
        ? toPaise(await this.availableWalletCapForMember(tx, theWallet.id, Number(theWallet.balance)))
        : 0;
      const walletPaise = Math.min(Math.max(walletCapPaise, 0), owedPaise);
      const cashPaise = owedPaise - walletPaise;
      const settled = cashPaise === 0;

      if (theWallet && walletPaise > 0) {
        await tx
          .update(wallet)
          .set({ balance: fromPaise(balancePaise - walletPaise), updatedAt: new Date() })
          .where(eq(wallet.id, theWallet.id));
        await tx.insert(walletEntry).values({
          walletId: theWallet.id,
          kind: 'SPEND',
          label: `Order ${found.code}`,
          amount: fromPaise(-walletPaise),
          occurredOn: new Date().toISOString().slice(0, 10),
          orderId: found.id,
        });
      }

      await tx
        .update(bill)
        .set({
          walletCollected: fromPaise(toPaise(Number(current.walletCollected)) + walletPaise),
          ...(settled ? { status: 'PAID' as const, paidAt: new Date() } : {}),
          updatedAt: new Date(),
        })
        .where(eq(bill.id, current.id));
      if (settled) {
        await tx.update(order).set({ paymentStatus: 'PAID', paidAt: new Date() }).where(eq(order.id, orderId));
      }

      if (walletPaise > 0) {
        await this.postOrderCollection(tx, {
          orderId,
          orderCode: found.code,
          storeId: found.storeId,
          cash: 0,
          gpay: 0,
          wallet: walletPaise / 100,
        });
      }

      return {
        ok: true as const,
        walletAmount: walletPaise / 100,
        cashAmount: cashPaise / 100,
        settled,
      };
    });
  }

  /**
   * Records money the counter takes against a priced bill — GPay, cash, or
   * both — as it arrives. Each amount adds to the bill's own running total
   * (`cash_collected` / `gpay_collected`); the bill is marked PAID, and its
   * order too, the moment what has been received covers everything still owed
   * after the member's wallet share. Refused, with nothing written, if the
   * amounts would take the bill past what is owed. Money is handled in whole
   * paise so a split never drifts by a rounding cent.
   *
   * Same staff scope as `collectBillWithWallet` (the order's own branch, or
   * any branch for an ADMIN/SUPERADMIN). Locks the bill row so two counters
   * receiving at once cannot both count the same rupee.
   */
  async receiveBillPayment(
    role: AdminRole,
    storeId: number | null,
    orderId: number,
    dto: ReceiveBillPaymentDto,
  ) {
    const found = await this.getOwnedByStaffOrThrow(orderId, role, storeId);

    const [theBill] = await this.db.select().from(bill).where(eq(bill.orderId, orderId)).limit(1);
    if (!theBill) {
      return { ok: false as const, reason: 'No bill has been sent for this order yet.' };
    }
    if (theBill.status === 'PAID') {
      return { ok: false as const, reason: 'This bill is already paid.' };
    }
    if (Number(theBill.amount) <= 0) {
      return { ok: false as const, reason: 'This bill has not been priced yet.' };
    }

    const toPaise = (rupees: number) => Math.round(rupees * 100);
    const fromPaise = (paise: number) => (paise / 100).toFixed(2);

    return this.db.transaction(async (tx) => {
      const [current] = await tx.select().from(bill).where(eq(bill.id, theBill.id)).limit(1).for('update');
      const owedPaise =
        toPaise(Number(current.amount)) -
        toPaise(Number(current.walletCollected)) -
        toPaise(Number(current.cashCollected)) -
        toPaise(Number(current.gpayCollected));
      const cashPaise = toPaise(dto.cash);
      const gpayPaise = toPaise(dto.gpay);
      const receivingPaise = cashPaise + gpayPaise;

      if (current.status === 'PAID' || owedPaise <= 0) {
        return { ok: false as const, reason: 'Nothing is left to receive on this bill.' };
      }
      if (receivingPaise > owedPaise) {
        return {
          ok: false as const,
          reason: `Only ₹${(owedPaise / 100).toFixed(2)} is still owed on this bill.`,
        };
      }

      const settled = receivingPaise === owedPaise;
      await tx
        .update(bill)
        .set({
          cashCollected: fromPaise(toPaise(Number(current.cashCollected)) + cashPaise),
          gpayCollected: fromPaise(toPaise(Number(current.gpayCollected)) + gpayPaise),
          ...(settled ? { status: 'PAID' as const, paidAt: new Date() } : {}),
          updatedAt: new Date(),
        })
        .where(eq(bill.id, current.id));

      if (settled) {
        await tx.update(order).set({ paymentStatus: 'PAID', paidAt: new Date() }).where(eq(order.id, orderId));
      }

      if (receivingPaise > 0) {
        await this.postOrderCollection(tx, {
          orderId,
          orderCode: found.code,
          storeId: found.storeId,
          cash: cashPaise / 100,
          gpay: gpayPaise / 100,
          wallet: 0,
        });
      }

      return {
        ok: true as const,
        receivedCash: fromPaise(cashPaise),
        receivedGpay: fromPaise(gpayPaise),
        remaining: fromPaise(owedPaise - receivingPaise),
        settled,
      };
    });
  }

  // ---- Staff order writes (store-scoped; migrated from shieldweb's direct SQL) ----
  // Each one resolves the order through getOwnedByStaffOrThrow first, so a
  // store-bound account can only ever touch its own branch's orders, and the
  // controller restricts these to the roles that hold the 'orders' module.

  /**
   * "Save" / "Convert to bill" on the review page: stock calls on the existing
   * lines, any counter-added lines, and the branch. Only an admin may move an
   * order to a different branch — a store-bound account keeps its own.
   */
  async reviewOrder(role: AdminRole, storeId: number | null, orderId: number, dto: ReviewOrderDto) {
    const found = await this.getOwnedByStaffOrThrow(orderId, role, storeId);
    const isAdmin = role === 'SUPERADMIN' || role === 'ADMIN';
    if (!isAdmin && (dto.storeId ?? null) !== (found.storeId ?? null)) {
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Only an admin can move an order to another branch' } });
    }

    return this.db.transaction(async (tx) => {
      for (const line of dto.lines) {
        await tx
          .update(orderLine)
          .set({ stockStatus: line.status })
          .where(and(eq(orderLine.id, line.id), eq(orderLine.orderId, orderId)));
      }
      if (dto.newLines.length > 0) {
        await tx.insert(orderLine).values(
          dto.newLines.map((line) => ({
            orderId,
            name: line.name,
            pack: line.pack,
            unitPrice: line.unitPrice.toString(),
            qty: line.qty,
            stockStatus: line.status,
          })),
        );
      }
      const [{ total }] = await tx
        .select({ total: sql<number>`count(*)::int` })
        .from(orderLine)
        .where(eq(orderLine.orderId, orderId));
      // mrpTotal and paidTotal are what the member checked out with — never
      // touched here, whatever is added.
      await tx
        .update(order)
        .set({ storeId: dto.storeId, itemCount: total, reviewedAt: new Date(), updatedAt: new Date() })
        .where(eq(order.id, orderId));
      return { ok: true as const };
    });
  }

  /** "Convert to bill →": stamps the order onto the Bills page. Cancelled orders cannot be billed. */
  async markConvertedToBill(role: AdminRole, storeId: number | null, orderId: number) {
    const found = await this.getOwnedByStaffOrThrow(orderId, role, storeId);
    if (found.status === 'CANCELLED') {
      throw new ConflictException({ error: { code: 'CONFLICT', message: 'A cancelled order cannot be converted to a bill.' } });
    }
    const now = new Date();
    await this.db
      .update(order)
      .set({
        convertedToBillAt: found.convertedToBillAt ?? now,
        reviewedAt: found.reviewedAt ?? now,
        updatedAt: now,
      })
      .where(eq(order.id, orderId));
    return { ok: true as const };
  }

  /**
   * Call / WhatsApp for this member: the first stamp wins. A cancelled order
   * returns null — nothing left to contact them about.
   */
  async markStoreContacted(role: AdminRole, storeId: number | null, orderId: number) {
    const found = await this.getOwnedByStaffOrThrow(orderId, role, storeId);
    if (found.status === 'CANCELLED') {
      return { storeContactedAt: null };
    }
    if (found.storeContactedAt == null) {
      const now = new Date();
      await this.db.update(order).set({ storeContactedAt: now, updatedAt: now }).where(eq(order.id, orderId));
      return { storeContactedAt: now.toISOString() };
    }
    return { storeContactedAt: found.storeContactedAt.toISOString() };
  }

  /**
   * "Complete" on a priced bill. Changes fulfilment only — it never collects
   * money (that is the separate collect/receive calls). Needs a priced bill
   * and an order that has not been cancelled, same as before this move.
   */
  async completeBilledOrder(role: AdminRole, storeId: number | null, orderId: number) {
    const found = await this.getOwnedByStaffOrThrow(orderId, role, storeId);
    if (found.status === 'CANCELLED') {
      throw new ConflictException({ error: { code: 'CONFLICT', message: 'Cancelled orders cannot be completed.' } });
    }
    const [priced] = await this.db
      .select({ id: bill.id })
      .from(bill)
      .where(and(eq(bill.orderId, orderId), sql`${bill.amount} > 0`))
      .limit(1);
    if (!priced) {
      throw new ConflictException({
        error: { code: 'CONFLICT', message: 'Save a priced bill first. Cancelled orders cannot be completed.' },
      });
    }
    await this.db.update(order).set({ status: 'DELIVERED', updatedAt: new Date() }).where(eq(order.id, orderId));
    return { ok: true as const };
  }

  /**
   * The itemised, priced invoice. Upserts the one bill row, replaces its lines
   * when given, and reflects the priced total onto the order.
   */
  async sendInvoice(role: AdminRole, storeId: number | null, orderId: number, dto: SendInvoiceDto) {
    await this.getOwnedByStaffOrThrow(orderId, role, storeId);
    return this.db.transaction(async (tx) => {
      const now = new Date();
      const [existing] = await tx.select().from(bill).where(eq(bill.orderId, orderId)).limit(1);
      // A blank image keeps whatever picture the bill already had.
      const image = dto.image ? dto.image : existing?.image ?? '';
      let billId: number;
      let sentAt: Date;
      if (existing) {
        await tx
          .update(bill)
          .set({ image, amount: dto.amount.toString(), discountAmount: dto.discountAmount.toString(), sentAt: now, updatedAt: now })
          .where(eq(bill.id, existing.id));
        billId = existing.id;
        sentAt = now;
      } else {
        const [created] = await tx
          .insert(bill)
          .values({ orderId, image, amount: dto.amount.toString(), discountAmount: dto.discountAmount.toString(), sentAt: now, updatedAt: now })
          .returning({ id: bill.id, sentAt: bill.sentAt });
        billId = created.id;
        sentAt = created.sentAt;
      }

      if (dto.lines) {
        await tx.delete(billLine).where(eq(billLine.billId, billId));
        if (dto.lines.length > 0) {
          await tx.insert(billLine).values(
            dto.lines.map((line) => ({
              billId,
              name: line.name,
              pack: line.pack ?? '',
              unitPrice: line.unitPrice.toString(),
              qty: line.qty,
            })),
          );
        }
      }

      await tx
        .update(order)
        .set({
          mrpTotal: dto.amount.toString(),
          convertedToBillAt: sql`COALESCE(${order.convertedToBillAt}, now())`,
          updatedAt: now,
        })
        .where(eq(order.id, orderId));
      return { sentAt: sentAt.toISOString() };
    });
  }

  /** A picture-only bill: sets the picture and bumps sent_at; amount and discount are left as they are. */
  async sendPicture(role: AdminRole, storeId: number | null, orderId: number, dto: SendPictureDto) {
    await this.getOwnedByStaffOrThrow(orderId, role, storeId);
    return this.db.transaction(async (tx) => {
      const now = new Date();
      const [existing] = await tx.select().from(bill).where(eq(bill.orderId, orderId)).limit(1);
      if (existing) {
        await tx.update(bill).set({ image: dto.image, sentAt: now, updatedAt: now }).where(eq(bill.id, existing.id));
      } else {
        await tx.insert(bill).values({ orderId, image: dto.image, sentAt: now, updatedAt: now });
      }
      return { ok: true as const };
    });
  }

  /** Withdraws a bill sent in error. Its lines go with it (ON DELETE CASCADE). */
  async clearBill(role: AdminRole, storeId: number | null, orderId: number) {
    await this.getOwnedByStaffOrThrow(orderId, role, storeId);
    await this.db.delete(bill).where(eq(bill.orderId, orderId));
    return { ok: true as const };
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

  /**
   * An order belongs to the branch it was booked at, or — when none was set —
   * to the member's home branch. That is the same rule the admin console uses
   * to show a branch its orders (see StaffOrderBoardService), so what a branch
   * can see is exactly what it can act on.
   */
  private async getOwnedByStaffOrThrow(orderId: number, role: AdminRole, storeId: number | null) {
    const [row] = await this.db
      .select({ o: order, homeStoreId: users.homeStoreId })
      .from(order)
      .leftJoin(users, eq(users.id, order.memberId))
      .where(eq(order.id, orderId))
      .limit(1);
    if (!row) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Order not found' } });

    if (role !== 'SUPERADMIN' && role !== 'ADMIN') {
      if (storeId == null) {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Staff account has no store assigned' } });
      }
      const effectiveStoreId = row.o.storeId ?? row.homeStoreId ?? null;
      if (effectiveStoreId !== storeId) {
        throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Order not found' } });
      }
    }
    return row.o;
  }

  /**
   * Sets an order's fulfilment status — cancel, out for delivery, delivered —
   * for the branch that owns it. Kept without the legal-transition check the
   * member-facing status route applies: the prescription "delivered" step and
   * the delivery handoff have always moved statuses this way, and changing
   * that is a product decision, not part of the access fix.
   */
  async setFulfilmentStatus(role: AdminRole, storeId: number | null, orderId: number, status: UpdateOrderStatusDto['status']) {
    await this.getOwnedByStaffOrThrow(orderId, role, storeId);
    await this.db.update(order).set({ status, updatedAt: new Date() }).where(eq(order.id, orderId));
    return { ok: true as const };
  }
}
