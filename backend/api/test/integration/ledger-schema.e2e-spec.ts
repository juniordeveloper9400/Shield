import { randomUUID } from 'node:crypto';
import { createTestDb, type TestDb } from './create-test-db';
import { chartOfAccount, journalEntry, journalLine, ledgerPeriod, legalEntity, postingRule, shieldStore } from '../../src/db/schema';

/**
 * Migration 0074 — ledger core. Covers the schema and its constraints only:
 * the two balance/period guard functions
 * (`app.assert_journal_entry_balanced`, `app.assert_ledger_period_open`) are
 * PL/pgSQL, and pg-mem has no PL/pgSQL support at all (see
 * agent.e2e-spec.ts's own note by the withdrawal functions for the same
 * limitation) — they're verified live against the dev database instead, the
 * same way migration 0059's withdrawal functions are.
 */
describe('Ledger core (e2e)', () => {
  let db: TestDb;

  beforeAll(() => {
    db = createTestDb();
  });

  it('gives a shop a legal entity it can be reached from', async () => {
    const [entity] = await db
      .insert(legalEntity)
      .values({ code: 'STORE-1', name: 'Store 1 (provisional entity)' })
      .returning();
    const [store] = await db
      .insert(shieldStore)
      .values({
        code: 'STORE-1',
        name: 'Store 1',
        area: 'Town',
        city: 'City',
        state: 'State',
        pincode: '000000',
        entityId: entity.id,
      })
      .returning();

    expect(store.entityId).toBe(entity.id);
  });

  it("rejects a chart of account row whose type isn't one of the five kinds", async () => {
    await expect(
      db.insert(chartOfAccount).values({ code: 'BAD-1', name: 'Bad account', type: 'NOT_A_TYPE' }),
    ).rejects.toThrow();
  });

  it('accepts every real account type', async () => {
    const rows = await db
      .insert(chartOfAccount)
      .values([
        { code: 'CASH-1', name: 'Cash — store', type: 'ASSET' },
        { code: 'WALLET-1', name: 'Member wallet liability', type: 'LIABILITY' },
        { code: 'REV-1', name: 'Sales revenue', type: 'REVENUE' },
        { code: 'EXP-1', name: 'Agent commission expense', type: 'EXPENSE' },
        { code: 'EQ-1', name: 'Opening balance', type: 'EQUITY' },
      ])
      .returning();
    expect(rows).toHaveLength(5);
  });

  it('maps a posting event\'s line role to a real account code', async () => {
    const rule = await db
      .insert(postingRule)
      .values({ event: 'activation_received', lineRole: 'cash_in', accountCode: 'CASH-1' })
      .returning();
    expect(rule[0].accountCode).toBe('CASH-1');

    // A line role pointing at an account code that doesn't exist is refused.
    await expect(
      db.insert(postingRule).values({ event: 'activation_received', lineRole: 'nowhere', accountCode: 'NO-SUCH-CODE' }),
    ).rejects.toThrow();
  });

  it('refuses the same event posted twice for the same source row', async () => {
    const [entity] = await db.insert(legalEntity).values({ code: 'STORE-2', name: 'Store 2' }).returning();

    // pg-mem's gen_random_uuid() default is reused across repeat inserts in
    // one statement plan (see agent.e2e-spec.ts's note by the withdrawal
    // functions for the same limitation) — every row here supplies its own id.
    await db.insert(journalEntry).values({
      id: randomUUID(),
      entityId: entity.id,
      postedOn: '2026-10-01',
      sourceTable: 'wallet_card',
      sourceId: '1',
      event: 'activation_received',
    });

    await expect(
      db.insert(journalEntry).values({
        id: randomUUID(),
        entityId: entity.id,
        postedOn: '2026-10-01',
        sourceTable: 'wallet_card',
        sourceId: '1',
        event: 'activation_received',
      }),
    ).rejects.toThrow();

    // A different event for the same source row is a different posting.
    const second = await db
      .insert(journalEntry)
      .values({
        id: randomUUID(),
        entityId: entity.id,
        postedOn: '2026-10-01',
        sourceTable: 'wallet_card',
        sourceId: '1',
        event: 'agent_commission_accrued',
      })
      .returning();
    expect(second).toHaveLength(1);
  });

  it('refuses a journal line that is both a debit and a credit, or neither', async () => {
    const [entity] = await db.insert(legalEntity).values({ code: 'STORE-3', name: 'Store 3' }).returning();
    const [entry] = await db
      .insert(journalEntry)
      .values({
        id: randomUUID(),
        entityId: entity.id,
        postedOn: '2026-10-01',
        sourceTable: 'wallet_card',
        sourceId: '2',
        event: 'activation_received',
      })
      .returning();
    const [account] = await db.insert(chartOfAccount).values({ code: 'CASH-3', name: 'Cash', type: 'ASSET' }).returning();

    await expect(
      db.insert(journalLine).values({ entryId: entry.id, accountId: account.id, debit: '0', credit: '0' }),
    ).rejects.toThrow();
    await expect(
      db.insert(journalLine).values({ entryId: entry.id, accountId: account.id, debit: '100', credit: '100' }),
    ).rejects.toThrow();

    const line = await db
      .insert(journalLine)
      .values({ entryId: entry.id, accountId: account.id, debit: '100', credit: '0' })
      .returning();
    expect(line).toHaveLength(1);
  });

  it('points a journal line only at a real entry and a real account', async () => {
    await expect(
      db.insert(journalLine).values({ entryId: randomUUID(), accountId: 999999, debit: '10', credit: '0' }),
    ).rejects.toThrow();
  });

  it('allows only one ledger period row per entity per month', async () => {
    const [entity] = await db.insert(legalEntity).values({ code: 'STORE-4', name: 'Store 4' }).returning();
    await db.insert(ledgerPeriod).values({ entityId: entity.id, period: '2026-10-01' });

    await expect(db.insert(ledgerPeriod).values({ entityId: entity.id, period: '2026-10-01' })).rejects.toThrow();

    const other = await db.insert(ledgerPeriod).values({ entityId: entity.id, period: '2026-11-01' }).returning();
    expect(other).toHaveLength(1);
  });
});
