import { createTestDb, type TestDb } from './create-test-db';
import { AccountsService } from '../../src/modules/accounts/accounts.service';
import {
  agent,
  agentWithdrawal,
  appointment,
  labBooking,
  labPackage,
  membershipTier,
  order,
  users,
  wallet,
  walletCard,
} from '../../src/db/schema';

/**
 * Ported from shieldweb's Accounts page, which used to run these five
 * queries directly against Neon from the browser (`src/api/accounts.ts`).
 * This only checks that the move to backend/api preserved the same totals
 * and exclusions (CANCELLED orders/bookings/appointments, PENDING
 * activations) — not every edge case of five different money sources.
 */
describe('AccountsService (e2e)', () => {
  let db: TestDb;
  let accounts: AccountsService;
  let memberId: number;

  beforeEach(async () => {
    db = createTestDb();
    accounts = new AccountsService(db);

    const [member] = await db
      .insert(users)
      .values({ phone: '9000000001', name: 'Accounts Test Member' })
      .returning();
    memberId = member.id;

    const today = new Date().toISOString().slice(0, 10);

    // Money in: one counted order, one cancelled (excluded).
    await db.insert(order).values({
      memberId,
      code: 'ORD-ACC-1',
      status: 'PROCESSING',
      paidTotal: '500',
      placedOn: today,
    });
    await db.insert(order).values({
      memberId,
      code: 'ORD-ACC-2',
      status: 'CANCELLED',
      paidTotal: '999',
      placedOn: today,
    });

    // Money in: one counted lab booking.
    const [pkg] = await db.insert(labPackage).values({ slug: 'acc-test-pkg', name: 'Accounts Test Package' }).returning();
    await db.insert(labBooking).values({
      memberId,
      labPackageId: pkg.id,
      totalPrice: '300',
      status: 'REPORT_READY',
    });

    // Money in: one counted appointment.
    await db.insert(appointment).values({
      memberId,
      fee: '200',
      status: 'COMPLETED',
      doctorName: 'Dr. Accounts',
    });

    // Money in: one approved activation; a pending one must not count.
    const [memberWallet] = await db.insert(wallet).values({ memberId, balance: '1234' }).returning();
    const [tier] = await db
      .insert(membershipTier)
      .values({ kind: 'GOLD', name: 'Gold', bin: '5678' })
      .returning();
    await db.insert(walletCard).values({
      walletId: memberWallet.id,
      tierId: tier.id,
      amount: '1000',
      bonus: '0',
      status: 'APPROVED',
      issuedOn: today,
      rechargedOn: today,
      expiresOn: '2099-01-01',
    });
    await db.insert(walletCard).values({
      walletId: memberWallet.id,
      tierId: tier.id,
      amount: '777',
      bonus: '0',
      status: 'PENDING',
      issuedOn: today,
      rechargedOn: today,
      expiresOn: '2099-01-01',
    });

    // Money out: one paid agent withdrawal; a pending one must not count as paid.
    const [agentRow] = await db
      .insert(agent)
      .values({ memberId, code: 'AGT-ACC-1', name: 'Accounts Test Agent', phone: '9000000001', level: 'WARD' })
      .returning();
    await db.insert(agentWithdrawal).values({
      agentId: agentRow.id,
      amount: '150',
      status: 'PAID',
      requestedOn: today,
      processedOn: today,
    });
    await db.insert(agentWithdrawal).values({
      agentId: agentRow.id,
      amount: '400',
      status: 'PENDING',
      requestedOn: today,
    });
  });

  it('sums revenue in from every source, excluding cancelled/pending rows', async () => {
    const summary = await accounts.getMoneyFlowSummary();

    expect(summary.revenue.ordersTotal).toBe(500);
    expect(summary.revenue.ordersCount).toBe(1);
    expect(summary.revenue.labBookingsTotal).toBe(300);
    expect(summary.revenue.appointmentsTotal).toBe(200);
    expect(summary.revenue.privilegeLoadsTotal).toBe(1000);
    expect(summary.revenue.total).toBe(500 + 300 + 200 + 1000);

    expect(summary.payouts.agentWithdrawalsTotal).toBe(150);
    expect(summary.payouts.agentWithdrawalsCount).toBe(1);

    expect(summary.net).toBe(summary.revenue.total - 150);
    expect(summary.walletLiability).toBe(1234);
    expect(summary.pendingAgentWithdrawalsTotal).toBe(400);
    expect(summary.pendingAgentWithdrawalsCount).toBe(1);
  });

  it('lists every settled money movement in one timeline, newest first', async () => {
    const entries = await accounts.listMoneyFlowEntries();

    expect(entries).toHaveLength(5); // the cancelled order and pending activation are excluded
    const kinds = entries.map((e) => e.kind).sort();
    expect(kinds).toEqual(['agent_payout', 'appointment', 'lab_booking', 'order', 'privilege_load']);

    const orderEntry = entries.find((e) => e.kind === 'order')!;
    expect(orderEntry.amount).toBe(500);
    expect(orderEntry.direction).toBe('in');
    expect(orderEntry.label).toBe('ORD-ACC-1');

    const payout = entries.find((e) => e.kind === 'agent_payout')!;
    expect(payout.direction).toBe('out');
    expect(payout.amount).toBe(150);
  });

  it("scopes one member's own transactions to just their rows", async () => {
    const [otherMember] = await db.insert(users).values({ phone: '9000000002', name: 'Someone Else' }).returning();
    await db.insert(order).values({
      memberId: otherMember.id,
      code: 'ORD-OTHER',
      status: 'PROCESSING',
      paidTotal: '9999',
      placedOn: new Date().toISOString().slice(0, 10),
    });

    const mine = await accounts.listMemberTransactions(memberId);
    expect(mine).toHaveLength(5);
    expect(mine.some((e) => e.label === 'ORD-OTHER')).toBe(false);

    const theirs = await accounts.listMemberTransactions(otherMember.id);
    expect(theirs).toHaveLength(1);
    expect(theirs[0].amount).toBe(9999);
  });

  it('summarises every member with at least one non-zero total', async () => {
    const summaries = await accounts.listMemberMoneyFlowSummaries();
    const mine = summaries.find((s) => s.id === String(memberId))!;

    expect(mine.moneyIn).toBe(500 + 300 + 200 + 1000);
    expect(mine.moneyInCount).toBe(4);
    expect(mine.moneyOut).toBe(150);
    expect(mine.moneyOutCount).toBe(1);
    expect(mine.walletBalance).toBe(1234);
  });

  it('never lists a member with nothing to show', async () => {
    const [untouched] = await db.insert(users).values({ phone: '9000000003', name: 'Never Transacted' }).returning();
    const summaries = await accounts.listMemberMoneyFlowSummaries();
    expect(summaries.some((s) => s.id === String(untouched.id))).toBe(false);
  });

  it('buckets revenue and payouts by calendar month for the trailing window', async () => {
    const monthly = await accounts.getMonthlyMoneyFlow(6);

    expect(monthly).toHaveLength(6);
    const thisMonth = monthly[monthly.length - 1];
    expect(thisMonth.in).toBe(500 + 300 + 200 + 1000);
    expect(thisMonth.out).toBe(150);
  });
});
