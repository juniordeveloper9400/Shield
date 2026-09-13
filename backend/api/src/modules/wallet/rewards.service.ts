import { ForbiddenException, Inject, Injectable } from '@nestjs/common';
import { desc, eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { rewardPointTransaction, users, wallet, walletEntry } from '../../db/schema';
import type { RedeemPointsDto } from './dto';

// From lib/module/wallet/wallet_service.dart WalletService.minRedeemPoints and
// the Rewards screen's stated rate ("100 = ₹10"). Built against the number
// already live in the app, not a guess. The "must be a multiple of 10"
// check is inferred from that rate to keep the rupee conversion exact —
// it isn't something explicitly enforced client-side today; flagging that
// this is a slightly stricter server-side rule than the current client has.
export const MIN_REDEEM_POINTS = 100;
const POINTS_PER_RUPEE = 10;

@Injectable()
export class RewardsService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  async listTransactions(memberId: number) {
    return this.db
      .select()
      .from(rewardPointTransaction)
      .where(eq(rewardPointTransaction.memberId, memberId))
      .orderBy(desc(rewardPointTransaction.createdAt));
  }

  /**
   * Points -> wallet balance, atomically: one debit ledger row, one credit
   * ledger row, both denormalized summary columns (`users.reward_points`
   * and `wallet.reward_points`) updated together. The caller wraps this in
   * IdempotencyService — see wallet.module.ts controllers — so a retried
   * request can't double-redeem.
   */
  async redeem(memberId: number, dto: RedeemPointsDto) {
    if (dto.points < MIN_REDEEM_POINTS) {
      throw new ForbiddenException({
        error: { code: 'FORBIDDEN', message: `Redeem at least ${MIN_REDEEM_POINTS} points at a time` },
      });
    }
    if (dto.points % POINTS_PER_RUPEE !== 0) {
      throw new ForbiddenException({
        error: { code: 'FORBIDDEN', message: `Points must be a multiple of ${POINTS_PER_RUPEE}` },
      });
    }

    return this.db.transaction(async (tx) => {
      const [member] = await tx.select().from(users).where(eq(users.id, memberId)).limit(1);
      const [theWallet] = await tx.select().from(wallet).where(eq(wallet.memberId, memberId)).limit(1);

      if (!theWallet || !theWallet.openedAt) {
        throw new ForbiddenException({
          error: { code: 'FORBIDDEN', message: 'Activate a plan to open your wallet before redeeming points' },
        });
      }
      if (dto.points > member.rewardPoints) {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Insufficient reward points' } });
      }

      const rupees = dto.points / POINTS_PER_RUPEE;
      const today = new Date().toISOString().slice(0, 10);

      await tx.insert(rewardPointTransaction).values({
        memberId,
        points: -dto.points,
        reason: 'REDEMPTION',
      });

      await tx.insert(walletEntry).values({
        walletId: theWallet.id,
        kind: 'POINTS_REDEEMED',
        label: `Redeemed ${dto.points} points`,
        amount: rupees.toString(),
        occurredOn: today,
      });

      await tx.update(users).set({ rewardPoints: member.rewardPoints - dto.points }).where(eq(users.id, memberId));

      const [updatedWallet] = await tx
        .update(wallet)
        .set({
          rewardPoints: theWallet.rewardPoints - dto.points,
          balance: (Number(theWallet.balance) + rupees).toString(),
        })
        .where(eq(wallet.id, theWallet.id))
        .returning();

      return { pointsRedeemed: dto.points, rupeesCredited: rupees, wallet: updatedWallet };
    });
  }
}
