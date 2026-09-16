import { ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, desc, eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import {
  agent,
  commissionReserveEntry,
  membershipTier,
  membershipTierLoad,
  wallet,
  walletCard,
  walletEntry,
} from '../../db/schema';
import type { SubmitWalletCardDto } from './dto';

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function addMonths(d: Date, months: number): Date {
  const copy = new Date(d);
  copy.setMonth(copy.getMonth() + months);
  return copy;
}

/** Rounds to the nearest paisa — every commission figure here is real money. */
function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/**
 * The Health Pass direct-sale commission split, worked out on [approveCard].
 * A Health Pass activation sets aside [COMMISSION_POOL_RATE] of the loaded
 * amount as the whole commission pool. From that pool:
 *
 *  - [DIRECT_SALE_SHARE_RATE] (60%) always goes to the agent whose code the
 *    member typed in at checkout (`wallet_card.sold_by_agent_id`) — their
 *    own direct-sale earnings, whatever level they are.
 *  - [NATIONAL_OVERRIDE_RATE] (10%) additionally goes to the one national
 *    agent, but only when the direct seller is someone else — the national
 *    agent's own direct sale already gets the 60% above and nothing on top
 *    of it, there being nobody further up to pay an override to.
 *  - Whatever is left (30% when a non-national agent sold directly, 40%
 *    when the national agent did) is not owed to any agent. It is logged to
 *    [commissionReserveEntry] as the company's own share — see that table's
 *    own doc — and is never credited to anyone or surfaced to a member or
 *    an agent anywhere in the app. A later change paying intermediate
 *    levels (state, district, …) an override of their own on a downline
 *    sale would come out of this same reserve share, once that split is
 *    specified; nothing here assumes it is permanently un-owed, only that
 *    this method does not yet hand any more of it out than described above.
 */
const COMMISSION_POOL_RATE = 0.1;
const DIRECT_SALE_SHARE_RATE = 0.6;
const NATIONAL_OVERRIDE_RATE = 0.1;

/**
 * Wallet balance is a stored column (matching the live schema), but it is
 * NEVER written directly by an endpoint — every change happens alongside
 * an appended wallet_entry row, in the same transaction, and only through
 * the two paths below (card approval, point redemption in rewards.service.ts).
 * See backend/docs/erd.md §4 "wallet money and ledger records must not be
 * silently overwritten".
 */
@Injectable()
export class WalletService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  async getOrCreateWallet(memberId: number) {
    const [existing] = await this.db.select().from(wallet).where(eq(wallet.memberId, memberId)).limit(1);
    if (existing) return existing;
    const [created] = await this.db.insert(wallet).values({ memberId }).returning();
    return created;
  }

  async listEntries(memberId: number) {
    const theWallet = await this.getOrCreateWallet(memberId);
    return this.db.select().from(walletEntry).where(eq(walletEntry.walletId, theWallet.id)).orderBy(desc(walletEntry.createdAt));
  }

  /** Sums the ledger independently of the stored `wallet.balance` column — a reconciliation check, not the read path. */
  async reconcileBalance(memberId: number): Promise<number> {
    const entries = await this.listEntries(memberId);
    return entries.reduce((sum, e) => sum + Number(e.amount), 0);
  }

  /** Submission alone credits nothing — see the class doc comment and the live schema's own comment on wallet_card. */
  async submitCard(memberId: number, dto: SubmitWalletCardDto) {
    const theWallet = await this.getOrCreateWallet(memberId);

    const [tier] = await this.db.select().from(membershipTier).where(eq(membershipTier.id, dto.tierId)).limit(1);
    if (!tier) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Membership tier not found' } });

    const validLoads = await this.db.select().from(membershipTierLoad).where(eq(membershipTierLoad.tierId, tier.id));
    const isValidAmount = validLoads.some((l) => Number(l.amount) === dto.amount);
    if (!isValidAmount) {
      throw new ForbiddenException({
        error: { code: 'FORBIDDEN', message: 'amount is not one of this tier\'s fixed loadable amounts' },
      });
    }

    const bonus = Math.round(dto.amount * Number(tier.bonusRate) * 100) / 100;
    const today = new Date();

    // Resolved now rather than left as a bare string for approveCard to
    // parse later — a typo or a made-up code must never be a reason to
    // refuse this member's own submission, so any code that doesn't match a
    // real, approved agent is silently dropped rather than surfaced as an
    // error. Only an APPROVED agent can be credited — a pending or rejected
    // row is not a real agent as far as the rest of the app is concerned
    // (see agent.service.ts's own comment on that same rule).
    let soldByAgentId: number | undefined;
    if (dto.agentCode) {
      const [found] = await this.db
        .select({ id: agent.id })
        .from(agent)
        .where(and(eq(agent.code, dto.agentCode.toUpperCase()), eq(agent.approvalStatus, 'APPROVED')))
        .limit(1);
      soldByAgentId = found?.id;
    }

    const [created] = await this.db
      .insert(walletCard)
      .values({
        walletId: theWallet.id,
        tierId: tier.id,
        amount: dto.amount.toString(),
        bonus: bonus.toString(),
        cardNumber: dto.cardNumber,
        receiptReference: dto.receiptReference,
        receiptFileName: dto.receiptFileName,
        receiptImage: dto.receiptImage,
        issuedOn: isoDate(today),
        rechargedOn: isoDate(today),
        expiresOn: isoDate(addMonths(today, tier.validityMonths)),
        soldByAgentId,
      })
      .returning();

    return created;
  }

  /**
   * The caller's own submitted cards, newest first — how a member's app
   * learns a pending card was approved or rejected after the fact, since
   * submission itself credits nothing (see submitCard's doc).
   */
  async listCardsForMember(memberId: number) {
    const theWallet = await this.getOrCreateWallet(memberId);
    return this.db.select().from(walletCard).where(eq(walletCard.walletId, theWallet.id)).orderBy(walletCard.submittedAt);
  }

  async listPendingCards() {
    return this.db.select().from(walletCard).where(eq(walletCard.status, 'PENDING')).orderBy(walletCard.submittedAt);
  }

  /** SUPERADMIN only — see the live schema's comment on wallet_card. */
  async approveCard(cardId: number) {
    const [card] = await this.db.select().from(walletCard).where(eq(walletCard.id, cardId)).limit(1);
    if (!card) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Wallet card not found' } });
    if (card.status !== 'PENDING') {
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: `Card already ${card.status.toLowerCase()}` } });
    }

    return this.db.transaction(async (tx) => {
      const [updatedCard] = await tx
        .update(walletCard)
        .set({ status: 'APPROVED', reviewedAt: new Date() })
        .where(eq(walletCard.id, cardId))
        .returning();

      const amount = Number(card.amount);
      const bonus = Number(card.bonus);
      const today = isoDate(new Date());

      await tx.insert(walletEntry).values({
        walletId: card.walletId,
        kind: 'TOPUP',
        label: 'Wallet card top-up',
        amount: amount.toString(),
        occurredOn: today,
        walletCardId: card.id,
      });
      if (bonus > 0) {
        await tx.insert(walletEntry).values({
          walletId: card.walletId,
          kind: 'BONUS',
          label: 'Wallet card bonus',
          amount: bonus.toString(),
          occurredOn: today,
          walletCardId: card.id,
        });
      }

      const [currentWallet] = await tx.select().from(wallet).where(eq(wallet.id, card.walletId)).limit(1);
      await tx
        .update(wallet)
        .set({
          balance: (Number(currentWallet.balance) + amount + bonus).toString(),
          openedAt: currentWallet.openedAt ?? new Date(),
        })
        .where(eq(wallet.id, card.walletId));

      // Direct-sale commission — only now, not at submission, matching this
      // whole method's own reason for being the one place "the ledger lines
      // and the balance move" (see submitCard's doc): a card can still be
      // rejected right up to this point, and a rejected sale must never have
      // paid anyone. [amount] is the same figure the member is being
      // credited above, not a separate agent-side figure to keep in sync.
      if (card.soldByAgentId != null) {
        const [seller] = await tx.select().from(agent).where(eq(agent.id, card.soldByAgentId)).limit(1);
        // The agent could in principle have been deleted between submission
        // and approval; best-effort like every other cross-reference here —
        // this member's own approval must still go through either way.
        if (seller) {
          const pool = amount * COMMISSION_POOL_RATE;
          const directShare = round2(pool * DIRECT_SALE_SHARE_RATE);
          await tx
            .update(agent)
            .set({
              earned: (Number(seller.earned) + directShare).toString(),
              personalSales: (Number(seller.personalSales) + amount).toString(),
            })
            .where(eq(agent.id, seller.id));

          let distributed = directShare;

          // The seller's own direct sale already covers them when they are
          // the national agent — nobody sits above the national agent to
          // pay an override to.
          if (seller.level !== 'NATIONAL') {
            const [national] = await tx
              .select()
              .from(agent)
              .where(and(eq(agent.level, 'NATIONAL'), eq(agent.approvalStatus, 'APPROVED')))
              .limit(1);
            // No national agent appointed yet is a real, if unusual, state
            // (the very first agent onboarded) — that share simply falls
            // through to the reserve below rather than crediting nobody
            // silently and losing track of the money.
            if (national) {
              const overrideShare = round2(pool * NATIONAL_OVERRIDE_RATE);
              await tx
                .update(agent)
                .set({ earned: (Number(national.earned) + overrideShare).toString() })
                .where(eq(agent.id, national.id));
              distributed += overrideShare;
            }
          }

          const reserve = round2(pool - distributed);
          if (reserve > 0) {
            await tx.insert(commissionReserveEntry).values({ walletCardId: card.id, amount: reserve.toString() });
          }
        }
      }

      return updatedCard;
    });
  }

  async rejectCard(cardId: number, note: string) {
    const [card] = await this.db.select().from(walletCard).where(eq(walletCard.id, cardId)).limit(1);
    if (!card) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Wallet card not found' } });
    if (card.status !== 'PENDING') {
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: `Card already ${card.status.toLowerCase()}` } });
    }

    const [updated] = await this.db
      .update(walletCard)
      .set({ status: 'REJECTED', reviewerNote: note, reviewedAt: new Date() })
      .where(eq(walletCard.id, cardId))
      .returning();
    return updated;
  }

  /**
   * The company's own share of every approved Health Pass activation's
   * commission pool — see [commissionReserveEntry]'s own doc. SUPERADMIN
   * only; this is company money, never meant to be visible to a member or
   * an agent. `total` sums the ledger the same "ledger is the real figure"
   * way every other running total in this codebase is read, rather than
   * trusting a separately maintained counter that could drift from it.
   */
  async getCommissionReserve() {
    const entries = await this.db.select().from(commissionReserveEntry).orderBy(desc(commissionReserveEntry.createdAt));
    const total = entries.reduce((sum, e) => sum + Number(e.amount), 0);
    return { total: round2(total), entries };
  }
}
