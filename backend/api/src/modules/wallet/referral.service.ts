import { Inject, Injectable, Logger } from '@nestjs/common';
import { and, desc, eq, gt, inArray, isNull, lte, sql } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import {
  agent,
  agentCustomer,
  referral,
  referralLevel,
  rewardPointTransaction,
  users,
  wallet,
  walletCard,
  walletEntry,
} from '../../db/schema';
import type { ApplyReferralCodeDto, CreateReferralDto } from './dto';

/** The Member ID shown in the apps: `SAHAKAR-####`, this member's own invite code. */
const MEMBER_CODE_PREFIX = 'SAHAKAR-';
/**
 * "Nihal", "Althaf M." — enough for a referrer to recognise who joined, without
 * putting another member's full name in their response.
 */
function shortName(name: string | null): string {
  const parts = (name ?? '').trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'A friend';
  if (parts.length === 1) return parts[0];
  return `${parts[0]} ${parts[parts.length - 1][0].toUpperCase()}.`;
}

/**
 * The member-to-member referral commission: this share of every Health Pass
 * plan a referred member activates goes to whoever referred them, into that
 * member's wallet. Mirrors `lib/module/refer/referral_level.dart`'s
 * `ReferralLadder.planCommissionPercent` and the 2% in
 * `app.pay_referral_commission` (migration 0054).
 */
export const REFERRAL_COMMISSION_RATE = 0.02;

/** The prefix members were issued before the rename to Sahakar 360. */
const LEGACY_MEMBER_CODE_PREFIX = /^SHIELD-/;

@Injectable()
export class ReferralService {
  private readonly logger = new Logger(ReferralService.name);

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
   * it's asked for — `SAHAKAR-####`, retried against the column's `UNIQUE`
   * constraint on a collision (a collision only costs another random draw).
   */
  async getOrCreateCode(memberId: number): Promise<string> {
    const [existing] = await this.db.select({ referralCode: users.referralCode }).from(users).where(eq(users.id, memberId)).limit(1);
    if (existing?.referralCode) {
      return existing.referralCode;
    }

    for (let attempt = 0; attempt < 8; attempt++) {
      const candidate = `${MEMBER_CODE_PREFIX}${1000 + Math.floor(Math.random() * 9000)}`;
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
   * transacted, the load amount of every `APPROVED` wallet card belonging
   * to a member they referred (kept for the client's own display, which
   * still lists individual activations), and `sahakarMoneyEarned` — the
   * real, already-credited sum of `referral.commission_amount` across every
   * one of their invitees, rather than a client-side 2% projection. The two
   * numbers agree by construction: `commission_amount` is written as
   * exactly 2% of the load, the same moment (and the same load) each row in
   * `activatedWalletCards` reflects — see `approve_wallet_card_activation`
   * (migration 0043) and `WalletService.approveCard`'s own doc.
   */
  async getProgress(memberId: number) {
    const transacted = await this.db
      .selectDistinct({ id: referral.inviteeMemberId })
      .from(referral)
      .where(and(eq(referral.inviterMemberId, memberId), inArray(referral.status, ['TRANSACTED', 'PLAN_ACTIVATED'])));
    const directReferrals = transacted.filter((r) => r.id !== null).length;

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

    const [{ sahakarMoneyEarned }] = await this.db
      .select({ sahakarMoneyEarned: sql<string>`coalesce(sum(${walletEntry.amount}), 0)` })
      .from(walletEntry)
      .innerJoin(wallet, eq(wallet.id, walletEntry.walletId))
      .where(and(eq(wallet.memberId, memberId), eq(walletEntry.kind, 'REFERRAL_EARNINGS')));

    // Everyone who has actually joined on this member's code, newest first, so
    // the Refer & Earn screen can show a registration the moment it happens —
    // not only once that person has paid for something. `REGISTERED` is joined
    // and waiting on a first paid order; the rest have already counted.
    const joined = await this.db
      .select({
        inviteeMemberId: referral.inviteeMemberId,
        name: users.name,
        status: referral.status,
        registeredAt: referral.registeredAt,
        transactedAt: referral.transactedAt,
        planActivatedAt: referral.planActivatedAt,
        createdAt: referral.createdAt,
      })
      .from(referral)
      .leftJoin(users, eq(users.id, referral.inviteeMemberId))
      .where(and(eq(referral.inviterMemberId, memberId), inArray(referral.status, ['REGISTERED', 'TRANSACTED', 'PLAN_ACTIVATED'])))
      .orderBy(desc(referral.createdAt));
    const invitees = joined.map((row) => ({
      name: shortName(row.name),
      status: row.status,
      registeredAt: row.registeredAt ?? row.createdAt,
      transactedAt: row.transactedAt,
      planActivatedAt: row.planActivatedAt,
    }));
    const pendingReferrals = joined.filter((row) => row.status === 'REGISTERED' && row.inviteeMemberId !== null).length;

    return {
      directReferrals,
      pendingReferrals,
      invitees,
      activatedWalletCards,
      sahakarMoneyEarned: Number(sahakarMoneyEarned),
    };
  }

  /**
   * Pays [referrerId] their commission on one approved plan — a
   * `REFERRAL_EARNINGS` ledger line in their wallet plus the balance — and
   * moves the referral to `PLAN_ACTIVATED`, recording the plan and the running
   * commission. Returns what was paid, 0 when nothing was.
   *
   * **Idempotent per card**: a plan pays once however many paths reach it. In
   * production the database's own trigger (`app.pay_referral_commission`,
   * migration 0054) has usually paid it already by the time this runs, so this
   * sees the ledger line and stands down; the test database has no triggers, so
   * here it does the paying. Either way the referrer is credited exactly once.
   */
  async payPlanCommission(
    tx: Database,
    input: { cardId: number; planAmount: number; referrerId: number; inviteeId: number },
  ): Promise<number> {
    const { cardId, planAmount, referrerId, inviteeId } = input;
    if (referrerId === inviteeId) return 0;
    const commission = Math.round(planAmount * REFERRAL_COMMISSION_RATE * 100) / 100;
    if (commission <= 0) return 0;

    // The referrer's wallet row is the lock: two approvals landing together
    // queue here, and the second sees the first's ledger line.
    let [referrerWallet] = await tx.select().from(wallet).where(eq(wallet.memberId, referrerId)).limit(1).for('update');
    if (!referrerWallet) {
      [referrerWallet] = await tx.insert(wallet).values({ memberId: referrerId }).returning();
    }

    const [alreadyPaid] = await tx
      .select({ id: walletEntry.id })
      .from(walletEntry)
      .where(and(eq(walletEntry.walletId, referrerWallet.id), eq(walletEntry.kind, 'REFERRAL_EARNINGS'), eq(walletEntry.walletCardId, cardId)))
      .limit(1);
    if (alreadyPaid) return 0;

    await tx.insert(walletEntry).values({
      walletId: referrerWallet.id,
      kind: 'REFERRAL_EARNINGS',
      label: 'Referral commission',
      amount: commission.toString(),
      occurredOn: new Date().toISOString().slice(0, 10),
      walletCardId: cardId,
    });
    await tx
      .update(wallet)
      .set({ balance: (Number(referrerWallet.balance) + commission).toString() })
      .where(eq(wallet.id, referrerWallet.id));

    // The most recent edge for this exact pair, if one already exists (from
    // apply-code REGISTERED, or an earlier order's TRANSACTED) — a plan is also
    // proof the friend transacted, so it moves all the way to PLAN_ACTIVATED.
    const [existingReferral] = await tx
      .select()
      .from(referral)
      .where(and(eq(referral.inviterMemberId, referrerId), eq(referral.inviteeMemberId, inviteeId)))
      .orderBy(desc(referral.id))
      .limit(1);
    const now = new Date();
    if (existingReferral) {
      await tx
        .update(referral)
        .set({
          status: 'PLAN_ACTIVATED',
          planAmount: planAmount.toString(),
          commissionAmount: (Number(existingReferral.commissionAmount) + commission).toString(),
          transactedAt: existingReferral.transactedAt ?? now,
          planActivatedAt: now,
        })
        .where(eq(referral.id, existingReferral.id));
    } else {
      await tx.insert(referral).values({
        inviterMemberId: referrerId,
        inviteeMemberId: inviteeId,
        status: 'PLAN_ACTIVATED',
        planAmount: planAmount.toString(),
        commissionAmount: commission.toString(),
        transactedAt: now,
        planActivatedAt: now,
      });
    }

    await this.awardLevelPointsIfCrossed(tx, referrerId);
    return commission;
  }

  /**
   * A member who already holds approved plans has just been linked to
   * [referrerId] (they bought first and entered a referral ID afterwards).
   * Nothing was owed when those plans were approved, so nothing was paid —
   * pay them now. Idempotent (see [payPlanCommission]).
   */
  async payEarlierPlans(inviteeId: number, referrerId: number): Promise<void> {
    try {
      await this.db.transaction(async (tx) => {
        const cards = await tx
          .select({ id: walletCard.id, amount: walletCard.amount })
          .from(walletCard)
          .innerJoin(wallet, eq(wallet.id, walletCard.walletId))
          .where(and(eq(wallet.memberId, inviteeId), eq(walletCard.status, 'APPROVED')))
          .orderBy(walletCard.id);
        for (const card of cards) {
          await this.payPlanCommission(tx, { cardId: card.id, planAmount: Number(card.amount), referrerId, inviteeId });
        }
      });
    } catch (error) {
      // Linking a referral must never fail because paying for an earlier plan did.
      this.logger.warn(`Could not pay referral commission on earlier plans for member ${inviteeId}: ${String(error)}`);
    }
  }

  /**
   * Credits real reward points the moment [inviterMemberId]'s own
   * direct-referral count actually crosses one or more rungs of
   * `referral_level` (Starter/Riser/Achiever/Champion/Legend —
   * `ReferralLadder.levels` mirrored server-side) — called from wherever a
   * referral's status can advance to `TRANSACTED` or `PLAN_ACTIVATED`
   * (`OrderService.checkout`, `WalletService.approveCard`), inside that
   * same transaction so a crossing is never counted without the referral
   * that caused it actually having landed.
   *
   * `users.referral_level_awarded` is the guard against crediting the same
   * rung twice: only levels strictly above it, and at or below the
   * inviter's current count, are ever paid — and every one of those found
   * in a single call (a member could clear two rungs between checks) is
   * summed and paid together, in one ledger line.
   */
  async awardLevelPointsIfCrossed(tx: Database, inviterMemberId: number): Promise<void> {
    // Serialize crossings before counting: another transaction may have just
    // qualified a different invitee for this same inviter.
    const [member] = await tx.select({ referralLevelAwarded: users.referralLevelAwarded }).from(users).where(eq(users.id, inviterMemberId)).limit(1).for('update');
    if (!member) return;
    const qualified = await tx
      .selectDistinct({ id: referral.inviteeMemberId })
      .from(referral)
      .where(and(eq(referral.inviterMemberId, inviterMemberId), inArray(referral.status, ['TRANSACTED', 'PLAN_ACTIVATED'])));
    const directReferrals = qualified.filter((r) => r.id !== null).length;

    const crossedLevels = await tx
      .select({ level: referralLevel.level, points: referralLevel.points })
      .from(referralLevel)
      .where(and(gt(referralLevel.level, member.referralLevelAwarded), lte(referralLevel.referralsRequired, Number(directReferrals))));
    if (crossedLevels.length === 0) return;

    const newPoints = crossedLevels.reduce((sum, l) => sum + l.points, 0);
    const newLevel = Math.max(...crossedLevels.map((l) => l.level));

    await tx.insert(rewardPointTransaction).values({
      memberId: inviterMemberId,
      points: newPoints,
      reason: 'REFERRAL_LEVEL',
      note: `Referral ladder — level ${newLevel}`,
    });
    await tx
      .update(users)
      .set({ rewardPoints: sql`${users.rewardPoints} + ${newPoints}`, referralLevelAwarded: newLevel })
      .where(eq(users.id, inviterMemberId));
  }

  /**
   * The code this member themselves signed up with, if any — whichever of
   * the two paths [applySignupCode] can resolve to actually applied, since a
   * member links to at most one of them, ever. Lets the registration form
   * show a member's own referral/agent code back to them on a later visit,
   * rather than only while they are still typing it in.
   *
   * Checked in the same order `applySignupCode` tries them: an agent link
   * (`app.agent_customer` → the linked agent's own printed code) first, then
   * a member referral (`app.referral.code_used`). Null when neither applies.
   */
  async getUsedCode(memberId: number): Promise<string | null> {
    const [asAgentCustomer] = await this.db
      .select({ code: agent.code })
      .from(agentCustomer)
      .innerJoin(agent, eq(agent.id, agentCustomer.agentId))
      .where(eq(agentCustomer.memberId, memberId))
      .limit(1);
    if (asAgentCustomer?.code) {
      return asAgentCustomer.code;
    }

    const [asReferral] = await this.db
      .select({ codeUsed: referral.codeUsed })
      .from(referral)
      .where(eq(referral.inviteeMemberId, memberId))
      .limit(1);
    return asReferral?.codeUsed ?? null;
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
   *  - A **fellow member's own referral code** (`SAHAKAR-1234`, from
   *    [getOrCreateCode]) records the referral edge (`app.referral`,
   *    `REGISTERED`) — real 2% commission and `referral_level` reward
   *    points both actually credit later, off this same edge, once the
   *    invitee transacts or activates a plan (`awardLevelPointsIfCrossed`,
   *    `app.approve_wallet_card_activation`, migrations 0042-0043).
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
    // Both code formats are always issued upper-case (`SHD-WRD-004`,
    // `SAHAKAR-1234`) and this lookup is a plain `=`, which Postgres treats
    // case-sensitively — the same reason `WalletService.submitCard`
    // upper-cases `dto.agentCode` before its own agent lookup. Without this,
    // a member who types (or autocorrect/predictive text lower-cases) their
    // code in anything but the exact stored casing gets the same silent
    // "no match" this method already gives a genuinely wrong code — an
    // invisible failure, since nothing here is allowed to error and block
    // registration over a bad code.
    const code = dto.code.trim().toUpperCase();
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

    // Codes shared before the rename read `SHIELD-1234`; migration 0051 moved
    // every stored one to `SAHAKAR-1234`, so an old message still resolves.
    const memberCode = code.replace(LEGACY_MEMBER_CODE_PREFIX, MEMBER_CODE_PREFIX);
    const [asMember] = await this.db.select({ id: users.id }).from(users).where(eq(users.referralCode, memberCode)).limit(1);

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
        // They may already hold approved plans (bought before entering the
        // code): those pay their referrer now.
        await this.payEarlierPlans(memberId, asMember.id);
        return { linked: 'member' };
      }
    }

    return { linked: 'none' };
  }
}
