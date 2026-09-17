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
 * amount as the whole commission pool. From that pool, once the direct
 * seller (`wallet_card.sold_by_agent_id`) resolves to a real APPROVED agent:
 *
 *  - [DIRECT_SALE_SHARE_RATE] (60%) always goes to the seller — their own
 *    direct-sale earnings, whatever level they are.
 *  - Then, walking the seller's own real `agent.parentId` chain (their
 *    actual upline, not just "whoever happens to be one level up"),
 *    [HOP_OVERRIDE_RATES] pays a decaying share to each ancestor in turn:
 *    10% to whoever is 1 hop up, 6% to whoever is 2 hops up, 5% to whoever
 *    is 3 hops up, 4% to whoever is 4 hops up, 3% to whoever is 5 hops up,
 *    2% to whoever is 6 hops up — each only when that specific ancestor
 *    resolves to a real APPROVED agent (an unapproved ancestor is skipped
 *    for payment but the walk still continues past them to find the next
 *    hop).
 *  - Whatever is left over once the walk ends (the chain runs out, or the
 *    rate table does) is not owed to any agent. It is logged to
 *    [commissionReserveEntry] as the company's own share — see that table's
 *    own doc — and is never credited to anyone or surfaced to a member or
 *    an agent anywhere in the app.
 *
 * Worked examples this reproduces, on a 10,000 rupee plan: national sells
 * directly -> 600/0/0/0/0/0/0/400 reserved; region sells directly (hop 1 IS
 * national) -> 600/100/0/0/0/0/0/300 reserved; state sells directly (hop 1 a
 * real region agent, hop 2 national) -> 600/100/60/0/0/0/0/240 reserved;
 * district sells directly (hop 1 state, hop 2 region, hop 3 national) ->
 * 600/100/60/50/0/0/0/190 reserved; assembly sells directly (hop 1 district,
 * hop 2 state, hop 3 region, hop 4 national) -> 600/100/60/50/40/0/0/150
 * reserved; lsgd sells directly (hop 1 assembly, hop 2 district, hop 3
 * state, hop 4 region, hop 5 national) -> 600/100/60/50/40/30/0/120
 * reserved; ward sells directly (hop 1 lsgd, hop 2 assembly, hop 3
 * district, hop 4 state, hop 5 region, hop 6 national) ->
 * 600/100/60/50/40/30/20/100 reserved.
 *
 * Mirrors the Postgres function `app.approve_wallet_card_activation`
 * (migration 0039) that shieldweb's real approval action actually calls —
 * see that migration's own doc for why this logic exists in both places.
 * This covers every level down to WARD, the deepest in app.agent_level —
 * nothing left to extend unless a new level is ever added below it.
 */
const COMMISSION_POOL_RATE = 0.1;
const DIRECT_SALE_SHARE_RATE = 0.6;
const HOP_OVERRIDE_RATES = [0.1, 0.06, 0.05, 0.04, 0.03, 0.02];

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
        const [seller] = await tx
          .select()
          .from(agent)
          .where(and(eq(agent.id, card.soldByAgentId), eq(agent.approvalStatus, 'APPROVED')))
          .limit(1);
        // The agent could in principle have been deleted, or not yet
        // approved, between submission and approval; best-effort like every
        // other cross-reference here — this member's own approval must
        // still go through either way.
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

          // Walk the seller's own real upline, one hop at a time, paying
          // the decaying rate for however many hops HOP_OVERRIDE_RATES
          // covers. An ancestor who isn't a real APPROVED agent is skipped
          // for payment but the walk still continues past them (via their
          // own parentId) to look for the next hop.
          let ancestorId: number | null = seller.parentId;
          for (let hop = 0; hop < HOP_OVERRIDE_RATES.length && ancestorId != null; hop++) {
            const [ancestor] = await tx.select().from(agent).where(eq(agent.id, ancestorId)).limit(1);
            if (!ancestor) break;

            if (ancestor.approvalStatus === 'APPROVED') {
              const hopShare = round2(pool * HOP_OVERRIDE_RATES[hop]);
              await tx
                .update(agent)
                .set({ earned: (Number(ancestor.earned) + hopShare).toString() })
                .where(eq(agent.id, ancestor.id));
              distributed += hopShare;
            }

            ancestorId = ancestor.parentId;
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
