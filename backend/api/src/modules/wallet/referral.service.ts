import { Inject, Injectable } from '@nestjs/common';
import { and, desc, eq, inArray, isNull } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { agent, agentCustomer, referral, users, wallet, walletCard } from '../../db/schema';
import type { ApplyReferralCodeDto, CreateReferralDto } from './dto';

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

  /**
   * Resolves whatever a new member typed into the "Referral ID" field at
   * registration. The one field carries two different kinds of code, and
   * they never collide:
   *
   *  - An **agent's own code** (`SHD-WRD-004`, …) links this member as that
   *    agent's direct-sale customer (`app.agent_customer`) — every Health
   *    Pass plan this member later activates then credits that agent's
   *    commission chain (`app.approve_wallet_card_activation`, migrations
   *    0033-0040) automatically, with no further wiring needed here: that
   *    function already resolves the seller as
   *    `COALESCE(sold_by_agent_id, agent_customer-linked agent)`.
   *  - A **fellow member's own referral code** (`SHIELD-1234`, from
   *    [getOrCreateCode]) records the referral edge (`app.referral`,
   *    `REGISTERED`) — the reward crediting for this half is a separate,
   *    not-yet-built piece; today [getProgress] only lets the client
   *    project a Sahakar-money figure, nothing is actually credited yet.
   *
   * Best-effort and idempotent: a code matching neither, a member who
   * already has an agent or a referrer on file, or referring yourself all
   * quietly do nothing rather than error — a wrong or repeated code must
   * never block registration. "Already has one on file" is enforced here
   * server-side (not just trusted from the client's own
   * "first registration" gate) — a member links to at most one agent and
   * is referred by at most one other member, ever.
   */
  async applySignupCode(memberId: number, dto: ApplyReferralCodeDto): Promise<{ linked: 'agent' | 'member' | 'none' }> {
    const code = dto.code.trim();
    if (!code) {
      return { linked: 'none' };
    }

    const [asAgent] = await this.db
      .select({ id: agent.id, memberId: agent.memberId })
      .from(agent)
      .where(and(eq(agent.code, code), eq(agent.approvalStatus, 'APPROVED')))
      .limit(1);

    // An agent typing their own code (their own account, not a prospect's)
    // would otherwise link them as their own customer.
    if (asAgent && asAgent.memberId !== memberId) {
      const [existingLink] = await this.db
        .select({ id: agentCustomer.id })
        .from(agentCustomer)
        .where(eq(agentCustomer.memberId, memberId))
        .limit(1);
      if (existingLink) {
        return { linked: 'none' };
      }
      const [member] = await this.db.select({ name: users.name, phone: users.phone }).from(users).where(eq(users.id, memberId)).limit(1);
      if (!member) {
        return { linked: 'none' };
      }
      await this.db
        .insert(agentCustomer)
        .values({ agentId: asAgent.id, memberId, name: member.name, phone: member.phone })
        .onConflictDoNothing();
      return { linked: 'agent' };
    }

    const [asMember] = await this.db.select({ id: users.id }).from(users).where(eq(users.referralCode, code)).limit(1);

    if (asMember && asMember.id !== memberId) {
      const [claimed] = await this.db
        .update(users)
        .set({ referredByMemberId: asMember.id })
        .where(and(eq(users.id, memberId), isNull(users.referredByMemberId)))
        .returning({ id: users.id });
      if (claimed) {
        await this.db.insert(referral).values({
          inviterMemberId: asMember.id,
          inviteeMemberId: memberId,
          codeUsed: code,
          status: 'REGISTERED',
          registeredAt: new Date(),
        });
        return { linked: 'member' };
      }
    }

    return { linked: 'none' };
  }
}
