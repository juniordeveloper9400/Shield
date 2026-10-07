import { eq } from 'drizzle-orm';
import { createTestDb, type TestDb } from './create-test-db';
import { BookingService } from '../../src/modules/care/booking.service';
import {
  chartOfAccount,
  journalEntry,
  journalLine,
  labBill,
  labBooking,
  labPackage,
  legalEntity,
  postingRule,
  shieldStore,
  users,
  wallet,
} from '../../src/db/schema';

/**
 * Same pattern as order-collection-ledger.e2e-spec.ts: lab bill collection
 * is plain TypeScript (BookingService.postLabBillCollection), so it runs
 * under pg-mem and needs no live-database verification script.
 */
describe('Lab bill collection posts to the ledger (e2e)', () => {
  let db: TestDb;
  let bookings: BookingService;
  let storeId: number;
  let cashAcct: number;
  let walletAcct: number;
  let revenueAcct: number;

  async function seedBooking(totalPrice: string) {
    const [member] = await db.insert(users).values({ name: 'Patient', phone: `9000040${Math.floor(Math.random() * 9000 + 1000)}` }).returning();
    const [pkg] = await db
      .insert(labPackage)
      .values({ slug: `pkg-${Date.now()}-${Math.random()}`, name: 'Full Body Checkup', price: totalPrice, mrp: totalPrice })
      .returning();
    const [booking] = await db
      .insert(labBooking)
      .values({ memberId: member.id, labPackageId: pkg.id, storeId, totalPrice, unitPrice: totalPrice })
      .returning();
    await db.insert(labBill).values({ labBookingId: booking.id, image: 'x', amount: totalPrice });
    return { memberId: member.id, bookingId: booking.id };
  }

  beforeEach(async () => {
    db = createTestDb();
    bookings = new BookingService(db);

    const [entity] = await db.insert(legalEntity).values({ code: 'STORE-LB1', name: 'Store LB1' }).returning();
    const [store] = await db
      .insert(shieldStore)
      .values({ code: 'LB1', name: 'Store LB1', area: 'A', city: 'A', state: 'A', pincode: '111111', entityId: entity.id })
      .returning();
    storeId = store.id;

    const [cash] = await db.insert(chartOfAccount).values({ code: 'CASH-LB', name: 'Cash — store', type: 'ASSET' }).returning();
    const [walletLiability] = await db
      .insert(chartOfAccount)
      .values({ code: 'WALLET-LB', name: 'Member wallet liability', type: 'LIABILITY' })
      .returning();
    const [revenue] = await db.insert(chartOfAccount).values({ code: 'REV-LB', name: 'Sales revenue — lab', type: 'REVENUE' }).returning();
    cashAcct = cash.id;
    walletAcct = walletLiability.id;
    revenueAcct = revenue.id;

    await db.insert(postingRule).values([
      { event: 'lab_bill_collected', lineRole: 'cash_in', accountCode: 'CASH-LB' },
      { event: 'lab_bill_collected', lineRole: 'wallet_in', accountCode: 'WALLET-LB' },
      { event: 'lab_bill_collected', lineRole: 'revenue', accountCode: 'REV-LB' },
    ]);
  });

  async function journalRowsFor(bookingId: number) {
    return db
      .select({ debit: journalLine.debit, credit: journalLine.credit, accountId: journalLine.accountId })
      .from(journalEntry)
      .innerJoin(journalLine, eq(journalLine.entryId, journalEntry.id))
      .where(eq(journalEntry.sourceId, String(bookingId)));
  }

  it('posts an all-cash settlement: Dr cash / Cr lab revenue', async () => {
    const { bookingId } = await seedBooking('1000');
    const result = await bookings.collectLabBillWithWallet('LAB', storeId, bookingId);
    expect(result.ok).toBe(true);

    const lines = await journalRowsFor(bookingId);
    expect(lines).toHaveLength(2);
    expect(Number(lines.find((l) => l.accountId === cashAcct)!.debit)).toBe(1000);
    expect(Number(lines.find((l) => l.accountId === revenueAcct)!.credit)).toBe(1000);
  });

  it('splits a settlement between wallet and cash, both posted', async () => {
    const { memberId, bookingId } = await seedBooking('1000');
    await db.insert(wallet).values({ memberId, balance: '400' });

    const result = await bookings.collectLabBillWithWallet('LAB', storeId, bookingId);
    if (!result.ok) throw new Error(result.reason);
    expect(result.walletAmount).toBe(400);
    expect(result.cashAmount).toBe(600);

    const lines = await journalRowsFor(bookingId);
    expect(lines).toHaveLength(3);
    expect(Number(lines.find((l) => l.accountId === walletAcct)!.debit)).toBe(400);
    expect(Number(lines.find((l) => l.accountId === cashAcct)!.debit)).toBe(600);
    expect(Number(lines.find((l) => l.accountId === revenueAcct)!.credit)).toBe(1000);
  });

  it('posts nothing a second time once the bill is already paid', async () => {
    const { bookingId } = await seedBooking('500');
    await bookings.collectLabBillWithWallet('LAB', storeId, bookingId);
    const second = await bookings.collectLabBillWithWallet('LAB', storeId, bookingId);
    expect(second.ok).toBe(false);

    const entries = await db.select().from(journalEntry).where(eq(journalEntry.sourceId, String(bookingId)));
    expect(entries).toHaveLength(1);
  });
});
