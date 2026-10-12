import {
  availablePlanAllowance,
  monthlyBalanceOf,
  redeemableAllowance,
  redeemedThisMonth,
} from './wallet-month';

// Mirrors shieldweb's tests/walletMonth.test.mjs — same algorithm, ported
// here (see this file's own doc), so the same cases must agree.

describe('availablePlanAllowance', () => {
  it("counts this month's whole allowance from the 1st, carry-forward included, and earlier spending cannot be reused", () => {
    const cards = [{ loaded: 11000, issuedOn: '2026-08-15' }];
    const entries = [{ kind: 'SPEND', amount: -400, occurredOn: '2026-08-20' }];
    // 14 Sep is before the card's day (15th), but September's twelfth already counts.
    expect(availablePlanAllowance(cards, entries, new Date(2026, 8, 14), 10600)).toBe(1432);
    expect(availablePlanAllowance(cards, entries, new Date(2026, 8, 15), 10600)).toBe(1432);
    expect(availablePlanAllowance(cards, entries, new Date(2026, 8, 15), 100)).toBe(100);
  });

  it('does not let commission spends reduce carried plan allowance', () => {
    expect(
      availablePlanAllowance(
        [{ loaded: 11000, issuedOn: '2026-08-15' }],
        [
          { kind: 'REFERRAL_EARNINGS', amount: 200, occurredOn: '2026-08-20' },
          { kind: 'SPEND', amount: -300, occurredOn: '2026-08-21' },
        ],
        new Date(2026, 8, 15),
        10900,
      ),
    ).toBe(1732);
  });

  it('handles month-end, future activation and final release boundaries', () => {
    const cards = [{ loaded: 11000, issuedOn: '2026-01-31' }];
    expect(availablePlanAllowance(cards, [], new Date(2026, 0, 30), 11000)).toBe(0);
    expect(availablePlanAllowance(cards, [], new Date(2026, 1, 28), 11000)).toBe(1832);
    expect(availablePlanAllowance(cards, [], new Date(2026, 2, 1), 11000)).toBe(2748); // March's twelfth from the 1st
    expect(availablePlanAllowance(cards, [], new Date(2027, 0, 31), 11000)).toBe(10992);
  });
});

const NOW = new Date(2026, 8, 20, 16, 0); // 20 Sep 2026, local
const spend = (amount: number, occurredOn: string) => ({ kind: 'SPEND', amount: -amount, occurredOn });
const credit = (kind: string, amount: number, occurredOn: string) => ({ kind, amount, occurredOn });

describe('redeemedThisMonth', () => {
  it('is zero when nothing has been drawn yet', () => {
    expect(redeemedThisMonth([], NOW)).toBe(0);
    expect(redeemedThisMonth([credit('ACTIVATION', 11000, '2026-09-01')], NOW)).toBe(0);
  });

  it('counts every debit dated in the current month, and only those', () => {
    const entries = [
      spend(500, '2026-08-31'), // last month
      spend(140, '2026-09-02'),
      spend(60, '2026-09-19'),
      spend(999, '2026-10-01'), // next month, dated ahead
    ];
    expect(redeemedThisMonth(entries, NOW)).toBe(200);
  });

  it('never counts credits or points as redeemed', () => {
    const entries = [
      credit('ACTIVATION', 11000, '2026-09-01'),
      credit('BONUS', 1100, '2026-09-01'),
      credit('POINTS_REDEEMED', 50, '2026-09-10'),
      spend(100, '2026-09-11'),
    ];
    expect(redeemedThisMonth(entries, NOW)).toBe(100);
  });
});

describe('redeemableAllowance', () => {
  it('is the released total, minus spend from before this month, carry-forward included', () => {
    const cards = [{ loaded: 11000, issuedOn: '2026-08-15' }];
    expect(redeemableAllowance(cards, [], NOW)).toBe(1832);
    expect(
      redeemableAllowance(cards, [spend(500, '2026-08-31')], NOW),
    ).toBe(1332);
    // Spending dated in the current month does not reduce it — that is
    // redeemedThisMonth's own job, subtracted separately.
    expect(
      redeemableAllowance(cards, [spend(140, '2026-09-02')], NOW),
    ).toBe(1832);
  });

  it('is never capped at the wallet balance, unlike availablePlanAllowance', () => {
    const cards = [{ loaded: 11000, issuedOn: '2026-08-15' }];
    expect(redeemableAllowance(cards, [], NOW)).toBe(1832);
  });
});

describe('monthlyBalanceOf', () => {
  it('floors at zero rather than reading as a debt', () => {
    expect(monthlyBalanceOf(1832, 2000)).toBe(0);
    expect(monthlyBalanceOf(1832, 200)).toBe(1632);
  });
});
