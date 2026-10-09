/**
 * A member's Health Pass "this month" figures — the same algorithm
 * shieldweb's `src/lib/walletMonth.ts` uses for the bill-collection preview
 * (`WalletBreakdown`/`BillEditorModal`), and the Flutter app's
 * `WalletCard.releasedThroughMonthOf`/`monthlyBalance` for the member's own
 * wallet screen. Ported here, not imported, the same deliberate choice those
 * two already made — each surface keeps its own copy of this pure
 * calculation rather than sharing one across three different stacks.
 *
 * This copy exists so `OrderService.collectBillWithWallet` can actually
 * enforce the cap the preview already shows staff, instead of only
 * capping the wallet draw at the member's raw balance — see that
 * function's own doc for the gap this closes.
 */

/** One approved `app.wallet_card` row, reduced to what the month figures need. */
export interface AllowanceCard {
  /** `amount + bonus + recharged_extra`. */
  loaded: number;
  /** `YYYY-MM-DD`. */
  issuedOn: string;
}

/** One `app.wallet_entry` row, reduced to what the month figures need. */
export interface LedgerEntry {
  /** `app.wallet_entry_kind`, e.g. `SPEND`, `AGENT_EARNINGS`. */
  kind: string;
  /** Credits positive, debits negative — the ledger's own sign. */
  amount: number;
  /** `YYYY-MM-DD` — the day the entry is dated (`occurred_on`). */
  occurredOn: string;
}

/**
 * `app.*`'s `date` columns come back from this driver as a JS `Date`
 * (midnight local time), not the `YYYY-MM-DD` string shieldweb's direct-SQL
 * reads get with a `::text` cast — callers pass either through here so this
 * module's own functions only ever see the string shape they're written for.
 */
export function toIsoDate(value: string | Date): string {
  if (typeof value === 'string') {
    return value;
  }
  const y = value.getFullYear();
  const m = String(value.getMonth() + 1).padStart(2, '0');
  const d = String(value.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/** Commission the member earned: spendable at any time, outside the monthly allowance. */
function isEarnings(entry: LedgerEntry): boolean {
  return entry.kind === 'REFERRAL_EARNINGS' || entry.kind === 'AGENT_EARNINGS';
}

/**
 * What the calendar month of [today] has released across every card: one
 * twelfth per calendar month since the card was issued, this month's included
 * from the 1st (not from the card's due day), capped at 12.
 */
function releasedThroughMonth(cards: AllowanceCard[], today: Date): number {
  let released = 0;
  for (const card of cards) {
    const [year, month, day] = card.issuedOn.slice(0, 10).split('-').map(Number);
    const issued = new Date(year, month - 1, day);
    if (!Number.isFinite(issued.getTime()) || today < issued) continue;
    const months = (today.getFullYear() - year) * 12 + today.getMonth() - (month - 1);
    released += Math.floor(card.loaded / 12) * Math.max(1, Math.min(12, months + 1));
  }
  return released;
}

/**
 * What is left of the month's Health Pass allowance, further capped at
 * [balance] — the real figure a wallet draw must never exceed. `entries`
 * must be oldest first; earnings are spent first, and what "was left"
 * depends on the sequence.
 */
export function availablePlanAllowance(
  cards: AllowanceCard[],
  entriesOldestFirst: LedgerEntry[],
  now: Date,
  balance: number,
): number {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const released = releasedThroughMonth(cards, today);
  let earnings = 0;
  let spent = 0;
  const isoToday = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
  for (const entry of entriesOldestFirst) {
    if (entry.occurredOn.slice(0, 10) > isoToday) continue;
    if (isEarnings(entry) && entry.amount > 0) earnings += entry.amount;
    if (entry.amount < 0) {
      const fromEarnings = Math.min(earnings, -entry.amount);
      earnings -= fromEarnings;
      spent += -entry.amount - fromEarnings;
    }
  }
  return Math.max(0, Math.min(balance, released - spent));
}
