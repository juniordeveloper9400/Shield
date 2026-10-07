import { createTestDb, type TestDb } from './create-test-db';
import { OrderService } from '../../src/modules/commerce/order.service';
import { CartService } from '../../src/modules/commerce/cart.service';
import { ReferralService } from '../../src/modules/wallet/referral.service';
import {
  bill,
  chartOfAccount,
  journalEntry,
  journalLine,
  legalEntity,
  order,
  postingRule,
  shieldStore,
  users,
  wallet,
} from '../../src/db/schema';
import { eq } from 'drizzle-orm';

/**
 * Migration 0074's posting_rule for 'order_collected' is seeded there
 * already (cash_in → 1001, wallet_in → 2001, revenue → 4001) — unlike the
 * withdrawal/activation functions, order/bill collection is plain
 * TypeScript (OrderService.postOrderCollection), so it runs under pg-mem
 * like any other service and needs no live-database verification script.
 */
describe('Order/bill collection posts to the ledger (e2e)', () => {
  let db: TestDb;
  let orders: OrderService;
  let entityId: number;
  let storeId: number;
  let orderId: number;
  let cashAcct: number;
  let walletAcct: number;
  let revenueAcct: number;

  beforeEach(async () => {
    db = createTestDb();
    orders = new OrderService(db, new CartService(db), new ReferralService(db));

    const [entity] = await db.insert(legalEntity).values({ code: 'STORE-OC1', name: 'Store OC1' }).returning();
    entityId = entity.id;
    const [store] = await db
      .insert(shieldStore)
      .values({ code: 'OC1', name: 'Store OC1', area: 'A', city: 'A', state: 'A', pincode: '111111', entityId })
      .returning();
    storeId = store.id;

    const [cash] = await db.insert(chartOfAccount).values({ code: 'CASH-OC', name: 'Cash — store', type: 'ASSET' }).returning();
    const [walletLiability] = await db
      .insert(chartOfAccount)
      .values({ code: 'WALLET-OC', name: 'Member wallet liability', type: 'LIABILITY' })
      .returning();
    const [revenue] = await db.insert(chartOfAccount).values({ code: 'REV-OC', name: 'Sales revenue', type: 'REVENUE' }).returning();
    cashAcct = cash.id;
    walletAcct = walletLiability.id;
    revenueAcct = revenue.id;

    await db.insert(postingRule).values([
      { event: 'order_collected', lineRole: 'cash_in', accountCode: 'CASH-OC' },
      { event: 'order_collected', lineRole: 'wallet_in', accountCode: 'WALLET-OC' },
      { event: 'order_collected', lineRole: 'revenue', accountCode: 'REV-OC' },
    ]);

    const [member] = await db.insert(users).values({ name: 'Buyer', phone: '9000030001' }).returning();
    await db.insert(wallet).values({ memberId: member.id, balance: '500' });
    const [theOrder] = await db
      .insert(order)
      .values({ memberId: member.id, code: 'ORD-OC-1', storeId: store.id, paidTotal: '400', itemCount: 1, placedOn: '2026-10-05' })
      .returning();
    orderId = theOrder.id;
    await db.insert(bill).values({ orderId, image: 'x', amount: '400' });
  });

  async function journalRowsFor(sourceTable: string) {
    return db
      .select({ debit: journalLine.debit, credit: journalLine.credit, accountId: journalLine.accountId })
      .from(journalEntry)
      .innerJoin(journalLine, eq(journalLine.entryId, journalEntry.id))
      .where(eq(journalEntry.sourceTable, sourceTable));
  }

  it('posts cash received against a bill: Dr cash / Cr revenue', async () => {
    const result = await orders.receiveBillPayment('PHARMACY', storeId, orderId, { cash: 400, gpay: 0 });
    expect(result.ok).toBe(true);

    const lines = await journalRowsFor('bill');
    expect(lines).toHaveLength(2);
    const cashLine = lines.find((l) => l.accountId === cashAcct)!;
    const revenueLine = lines.find((l) => l.accountId === revenueAcct)!;
    expect(Number(cashLine.debit)).toBe(400);
    expect(Number(revenueLine.credit)).toBe(400);
  });

  it('posts cash and GPay as one combined receipt', async () => {
    await orders.receiveBillPayment('PHARMACY', storeId, orderId, { cash: 150, gpay: 250 });

    const lines = await journalRowsFor('bill');
    const cashLine = lines.find((l) => l.accountId === cashAcct)!;
    expect(Number(cashLine.debit)).toBe(400); // cash + gpay, same clearing account for now
  });

  it('posts a wallet-settled bill: Dr member wallet liability / Cr revenue', async () => {
    const result = await orders.collectBillWithWallet('PHARMACY', storeId, orderId);
    expect(result.ok).toBe(true);

    const lines = await journalRowsFor('bill');
    expect(lines).toHaveLength(2);
    const walletLine = lines.find((l) => l.accountId === walletAcct)!;
    const revenueLine = lines.find((l) => l.accountId === revenueAcct)!;
    expect(Number(walletLine.debit)).toBe(400); // full bill, wallet had 500
    expect(Number(revenueLine.credit)).toBe(400);
  });

  it('posts two separate entries for a cash-then-GPay split payment', async () => {
    await orders.receiveBillPayment('PHARMACY', storeId, orderId, { cash: 150, gpay: 0 });
    await orders.receiveBillPayment('PHARMACY', storeId, orderId, { cash: 0, gpay: 250 });

    const entries = await db.select().from(journalEntry).where(eq(journalEntry.sourceTable, 'bill'));
    expect(entries).toHaveLength(2);
    const totalCredited = (await journalRowsFor('bill'))
      .filter((l) => l.accountId === revenueAcct)
      .reduce((sum, l) => sum + Number(l.credit), 0);
    expect(totalCredited).toBe(400);
  });

  it('still records the payment even when the store has no legal entity (ledger posting is skipped, not fatal)', async () => {
    // A store with entityId null — nothing was backfilled for it.
    const [bareStore] = await db
      .insert(shieldStore)
      .values({ code: 'OC2', name: 'Store OC2', area: 'A', city: 'A', state: 'A', pincode: '222222' })
      .returning();
    const [member2] = await db.insert(users).values({ name: 'Buyer2', phone: '9000030002' }).returning();
    const [order2] = await db
      .insert(order)
      .values({ memberId: member2.id, code: 'ORD-OC-2', storeId: bareStore.id, paidTotal: '100', itemCount: 1, placedOn: '2026-10-05' })
      .returning();
    await db.insert(bill).values({ orderId: order2.id, image: 'x', amount: '100' });

    const result = await orders.receiveBillPayment('PHARMACY', bareStore.id, order2.id, { cash: 100, gpay: 0 });
    expect(result.ok).toBe(true); // the real payment still goes through

    const entries = await db.select().from(journalEntry).where(eq(journalEntry.sourceTable, 'bill'));
    expect(entries).toHaveLength(0); // nothing posted — no entity to post to
  });
});
