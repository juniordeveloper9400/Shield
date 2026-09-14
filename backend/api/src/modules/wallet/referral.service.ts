import { Inject, Injectable } from '@nestjs/common';
import { and, desc, eq, inArray, isNull } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { referral, users, wallet, walletCard } from '../../db/schema';
import type { CreateReferralDto } from './dto';

@Injectable()
export class ReferralService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  async create(memberId: number, dto: CreateReferralDto) {
    const [created] = await this.db
      .insert(referral)
      .values({ inviterMemberId: memberId, inviteePhone: dto.inviteePhone })
      .returning();
    return created;
  }

  async listForMember(memberId: number) {
    return this.db.select().from(referral).where(eq(referral.inviterMemberId, memberId)).orderBy(desc(referral.createdAt));
  }

  /**
   * The caller's own invite code, generating and saving one the first time
   * it's asked for — `SHIELD-####`, retried against the column's `UNIQUE`
   * constraint on a collision (a collision only costs another random draw).
   */
  async getOrCreateCode(memberId: number): Promise<string> {
    const [existing] = await this.db.select({ referralCode: users.referralCode }).from(users).where(eq(users.id, memberId)).limit(1);
    if (existing?.referralCode) {
      return existing.referralCode;
    }

    for (let attempt = 0; attempt < 8; attempt++) {
      const candidate = `SHIELD-${1000 + Math.floor(Math.random() * 9000)}`;
      try {
        const [updated] = await this.db
          .update(users)
          .set({ referralCode: candidate })
          .where(and(eq(users.id, memberId), isNull(users.referralCode)))
          .returning({ referralCode: users.referralCode });
        if (updated?.referralCode) {
          return updated.referralCode;
        }
        // No row moved: another call already won the race and set one — read it back.
        const [settled] = await this.db.select({ referralCode: users.referralCode }).from(users).where(eq(users.id, memberId)).limit(1);
        if (settled?.referralCode) {
          return settled.referralCode;
        }
      } catch {
        // Almost certainly the UNIQUE constraint — another member already holds this candidate. Draw again.
      }
    }
    throw new Error('Could not generate a unique referral code after 8 attempts');
  }

  /**
   * The caller's standing as an inviter: how many of their invites have
   * transacted, and the load amount of every `APPROVED` wallet card
   * belonging to a member they referred. The client computes Sahakar money
   * from `activatedWalletCards` itself (`ReferralLadder.planCommissionOn`)
   * — same formula, same place it's always lived, just fed from here now
   * instead of a direct Neon read.
   */
  async getProgress(memberId: number) {
    const transacted = await this.db
      .select({ id: referral.id })
      .from(referral)
      .where(and(eq(referral.inviterMemberId, memberId), inArray(referral.status, ['TRANSACTED', 'PLAN_ACTIVATED'])));
    const directReferrals = transacted.length;

    const referredInvitees = await this.db
      .select({ inviteeMemberId: referral.inviteeMemberId })
      .from(referral)
      .where(eq(referral.inviterMemberId, memberId));
    const inviteeIds = referredInvitees.map((r) => r.inviteeMemberId).filter((id): id is number => id !== null);

    const activatedWalletCards =
      inviteeIds.length === 0
        ? []
        : await this.db
            .select({ amount: walletCard.amount })
            .from(walletCard)
            .innerJoin(wallet, eq(wallet.id, walletCard.walletId))
            .where(and(inArray(wallet.memberId, inviteeIds), eq(walletCard.status, 'APPROVED')));

    return { directReferrals, activatedWalletCards };
  }
}
