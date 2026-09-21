import { eq } from 'drizzle-orm';
import { createTestDb, type TestDb } from './create-test-db';
import { ReferralService } from '../../src/modules/wallet/referral.service';
import { WalletService } from '../../src/modules/wallet/wallet.service';
import { agent, agentCustomer, commissionReserveEntry, membershipTier, referral, users, wallet, walletCard, walletEntry } from '../../src/db/schema';

describe('Referral attribution and activation accounting', () => {
  let db: TestDb;
  let referrals: ReferralService;
  let wallets: WalletService;
  beforeEach(() => {
    db = createTestDb();
    referrals = new ReferralService(db);
    wallets = new WalletService(db, referrals);
  });

  async function members() {
    const [inviter] = await db.insert(users).values({ name: 'Inviter', phone: '9000010001', referralCode: 'SAHAKAR-7891' }).returning();
    const [invitee] = await db.insert(users).values({ name: 'Invitee', phone: '9000010002' }).returning();
    const [seller] = await db.insert(agent).values({ code: 'SHD-WRD-REF', name: 'Seller', phone: '9000010003', level: 'WARD', approvalStatus: 'APPROVED' }).returning();
    return { inviter, invitee, seller };
  }

  it('accepts the displayed Member ID, retries idempotently, and prevents either direction of cross attribution', async () => {
    const { inviter, invitee, seller } = await members();
    expect(await referrals.applySignupCode(invitee.id, { code: ' sahakar-7891 ' })).toEqual({ linked: 'member' });
    expect(await referrals.applySignupCode(invitee.id, { code: 'SAHAKAR-7891' })).toEqual({ linked: 'member' });
    expect(await referrals.applySignupCode(invitee.id, { code: seller.code })).toEqual({ linked: 'none' });
    expect(await db.select().from(agentCustomer)).toHaveLength(0);
    expect(await db.select().from(referral)).toHaveLength(1);
    expect(await referrals.applySignupCode(inviter.id, { code: 'SAHAKAR-7891' })).toEqual({ linked: 'none' });
    const [other] = await db.insert(users).values({ name: 'Other', phone: '9000010004' }).returning();
    expect(await referrals.applySignupCode(other.id, { code: seller.code })).toEqual({ linked: 'agent' });
    expect(await referrals.applySignupCode(other.id, { code: seller.code })).toEqual({ linked: 'agent' });
    expect(await referrals.applySignupCode(other.id, { code: 'SAHAKAR-7891' })).toEqual({ linked: 'none' });
  });

  it('still accepts a Member ID shared before the rename (SHIELD-####) as the same code', async () => {
    const { inviter, invitee } = await members();
    expect(await referrals.applySignupCode(invitee.id, { code: 'SHIELD-7891' })).toEqual({ linked: 'member' });
    const [edge] = await db.select().from(referral);
    expect(edge.inviterMemberId).toBe(inviter.id);
  });

  it('pays one 10% pool: 2% member and 8% reserve on every activation, never double approval or duplicate levels', async () => {
    const { inviter, invitee, seller } = await members();
    await referrals.applySignupCode(invitee.id, { code: inviter.referralCode! });
    const [tier] = await db.insert(membershipTier).values({ kind: 'SILVER', name: 'Silver', bin: '1234', bonusRate: '0.1', validityMonths: 12 }).returning();
    const [account] = await db.insert(wallet).values({ memberId: invitee.id }).returning();
    for (const status of ['PENDING', 'ON_HOLD'] as const) {
      const [card] = await db.insert(walletCard).values({ walletId: account.id, tierId: tier.id, amount: '10000', bonus: '1000', soldByAgentId: seller.id, status, issuedOn: '2026-09-20', rechargedOn: '2026-09-20', expiresOn: '2027-09-20' }).returning();
      await wallets.approveCard(card.id);
      await expect(wallets.approveCard(card.id)).rejects.toThrow();
    }
    const [earned] = await db.select().from(wallet).where(eq(wallet.memberId, inviter.id));
    expect(Number(earned.balance)).toBe(400);
    const reserves = await db.select().from(commissionReserveEntry);
    expect(reserves.map((r) => Number(r.amount))).toEqual([800, 800]);
    const [agentAfter] = await db.select().from(agent).where(eq(agent.id, seller.id));
    expect(Number(agentAfter.earned)).toBe(0);
    expect((await referrals.getProgress(inviter.id)).directReferrals).toBe(1);
    expect((await referrals.getProgress(inviter.id)).sahakarMoneyEarned).toBe(400);
    const [member] = await db.select().from(users).where(eq(users.id, inviter.id));
    expect(member.rewardPoints).toBe(0);
    expect(await db.select().from(walletEntry).where(eq(walletEntry.kind, 'REFERRAL_EARNINGS'))).toHaveLength(2);
  });

  it('shows a member who has joined as pending straight away, and moves them across when they transact', async () => {
    const { inviter, invitee } = await members();
    await db.update(users).set({ name: 'Nihal Kumar' }).where(eq(users.id, invitee.id));
    expect(await referrals.applySignupCode(invitee.id, { code: inviter.referralCode! })).toEqual({ linked: 'member' });

    let progress = await referrals.getProgress(inviter.id);
    // Registered, not yet transacted: it does not count towards a level...
    expect(progress.directReferrals).toBe(0);
    // ...but the referrer can see it, by first name and last initial only.
    expect(progress.pendingReferrals).toBe(1);
    expect(progress.invitees).toHaveLength(1);
    expect(progress.invitees[0]).toEqual(
      expect.objectContaining({ name: 'Nihal K.', status: 'REGISTERED', transactedAt: null }),
    );
    expect(progress.invitees[0].registeredAt).not.toBeNull();

    await db.update(referral).set({ status: 'TRANSACTED', transactedAt: new Date() }).where(eq(referral.inviteeMemberId, invitee.id));
    progress = await referrals.getProgress(inviter.id);
    expect(progress.directReferrals).toBe(1);
    expect(progress.pendingReferrals).toBe(0);
    expect(progress.invitees[0].status).toBe('TRANSACTED');
    expect(progress.invitees[0].transactedAt).not.toBeNull();
  });

  it('lists nobody for a member who has referred no one, and skips invites that were only shared', async () => {
    const { inviter } = await members();
    await db.insert(referral).values({ inviterMemberId: inviter.id, inviteePhone: '9000019999', status: 'SHARED' });
    const progress = await referrals.getProgress(inviter.id);
    expect(progress.directReferrals).toBe(0);
    expect(progress.pendingReferrals).toBe(0);
    expect(progress.invitees).toEqual([]);
  });

  it('counts unique qualifying members and only posted referral earnings, not projected commissions', async () => {
    const { inviter, invitee } = await members();
    await db.insert(referral).values([
      { inviterMemberId: inviter.id, inviteeMemberId: invitee.id, status: 'TRANSACTED', commissionAmount: '200' },
      { inviterMemberId: inviter.id, inviteeMemberId: invitee.id, status: 'PLAN_ACTIVATED', commissionAmount: '200' },
    ]);
    const progress = await referrals.getProgress(inviter.id);
    expect(progress.directReferrals).toBe(1);
    expect(progress.sahakarMoneyEarned).toBe(0);
    await db.transaction(async (tx) => referrals.awardLevelPointsIfCrossed(tx, inviter.id));
    const [member] = await db.select().from(users).where(eq(users.id, inviter.id));
    expect(member.rewardPoints).toBe(0);
  });
});
