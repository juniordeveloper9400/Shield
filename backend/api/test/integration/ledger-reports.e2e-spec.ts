import { randomUUID } from 'node:crypto';
import { createTestDb, type TestDb } from './create-test-db';
import { LedgerService } from '../../src/modules/ledger/ledger.service';
import { chartOfAccount, journalEntry, journalLine, legalEntity } from '../../src/db/schema';

describe('Ledger reports (e2e)', () => {
  let db: TestDb;
  let ledger: LedgerService;
  let storeEntityId: number;
  let hqEntityId: number;
  let cash: number;
  let dueToHq: number;

  beforeEach(async () => {
    db = createTestDb();
    ledger = new LedgerService(db);

    const [store] = await db.insert(legalEntity).values({ code: 'STORE-R1', name: 'Store R1' }).returning();
    const [hq] = await db.insert(legalEntity).values({ code: 'HQ', name: 'Head Office' }).returning();
    storeEntityId = store.id;
    hqEntityId = hq.id;

    const [cashAcct] = await db.insert(chartOfAccount).values({ code: 'CASH-R', name: 'Cash — store', type: 'ASSET' }).returning();
    const [dueAcct] = await db
      .insert(chartOfAccount)
      .values({ code: 'DUE-R', name: 'Due to Head Office', type: 'LIABILITY' })
      .returning();
    cash = cashAcct.id;
    dueToHq = dueAcct.id;

    // Two activations at the store entity, one in October, one in September.
    const [entryOct] = await db
      .insert(journalEntry)
      .values({ id: randomUUID(), entityId: storeEntityId, postedOn: '2026-10-05', sourceTable: 'wallet_card', sourceId: '1', event: 'activation_received' })
      .returning();
    await db.insert(journalLine).values([
      { entryId: entryOct.id, accountId: cash, debit: '1000', credit: '0' },
      { entryId: entryOct.id, accountId: dueToHq, debit: '0', credit: '1000' },
    ]);

    const [entrySep] = await db
      .insert(journalEntry)
      .values({ id: randomUUID(), entityId: storeEntityId, postedOn: '2026-09-15', sourceTable: 'wallet_card', sourceId: '2', event: 'activation_received' })
      .returning();
    await db.insert(journalLine).values([
      { entryId: entrySep.id, accountId: cash, debit: '500', credit: '0' },
      { entryId: entrySep.id, accountId: dueToHq, debit: '0', credit: '500' },
    ]);
  });

  it('lists every legal entity', async () => {
    const entities = await ledger.listEntities();
    expect(entities.map((e) => e.code).sort()).toEqual(['HQ', 'STORE-R1']);
  });

  it('sums every account across all entities and periods when nothing is scoped', async () => {
    const balance = await ledger.trialBalance({});
    const cashRow = balance.find((r) => r.accountCode === 'CASH-R')!;
    expect(cashRow.debit).toBe(1500);
    expect(cashRow.net).toBe(1500);
    const dueRow = balance.find((r) => r.accountCode === 'DUE-R')!;
    expect(dueRow.credit).toBe(1500);
    expect(dueRow.net).toBe(-1500);
  });

  it('scopes the trial balance to one entity', async () => {
    const balance = await ledger.trialBalance({ entityId: hqEntityId });
    expect(balance).toEqual([]);

    const storeBalance = await ledger.trialBalance({ entityId: storeEntityId });
    expect(storeBalance.find((r) => r.accountCode === 'CASH-R')!.debit).toBe(1500);
  });

  it('scopes the trial balance to one calendar month', async () => {
    const october = await ledger.trialBalance({ period: '2026-10-01' });
    expect(october.find((r) => r.accountCode === 'CASH-R')!.debit).toBe(1000);

    const september = await ledger.trialBalance({ period: '2026-09-01' });
    expect(september.find((r) => r.accountCode === 'CASH-R')!.debit).toBe(500);
  });

  it('filters the trial balance by account type', async () => {
    const assets = await ledger.trialBalance({ type: 'ASSET' });
    expect(assets.map((r) => r.accountCode)).toEqual(['CASH-R']);
  });

  it('closes a period and blocks it from being reopened silently', async () => {
    const closed = await ledger.closePeriod(storeEntityId, '2026-10-01', 'admin-1');
    expect(closed.closedAt).not.toBeNull();
    expect(closed.closedBy).toBe('admin-1');

    const periods = await ledger.listPeriods(storeEntityId);
    expect(periods).toHaveLength(1);

    // Closing again (a different reviewer) updates the same row, not a new one.
    const reclosed = await ledger.closePeriod(storeEntityId, '2026-10-01', 'admin-2');
    expect(reclosed.closedBy).toBe('admin-2');
    expect(await ledger.listPeriods(storeEntityId)).toHaveLength(1);
  });

  it('refuses to close a period for an entity that does not exist', async () => {
    await expect(ledger.closePeriod(999999, '2026-10-01', 'admin-1')).rejects.toThrow();
  });
});
