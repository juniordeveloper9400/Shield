import { ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { desc, eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { membershipTier, membershipTierLoad, wallet, walletCard, walletEntry } from '../../db/schema';
import type { SubmitWalletCardDto } from './dto';

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function addMonths(d: Date, months: number): Date {
  const copy = new Date(d);
  copy.setMonth(copy.getMonth() + months);
  return copy;
}

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
        issuedOn: isoDate(today),
        rechargedOn: isoDate(today),
        expiresOn: isoDate(addMonths(today, tier.validityMonths)),
      })
      .returning();

    return created;
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
}
