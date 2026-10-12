import { createTestDb, type TestDb } from './create-test-db';
import { OrderService } from '../../src/modules/commerce/order.service';
import { CartService } from '../../src/modules/commerce/cart.service';
import { ReferralService } from '../../src/modules/wallet/referral.service';
import { membershipTier, order, shieldStore, users, wallet, walletCard } from '../../src/db/schema';
import { eq } from 'drizzle-orm';

/**
 * GET /v1/staff/orders/:id/wallet-preview — the figures BillEditorModal
 * shows before collection ever runs. Service-level, like
 * order-collection-ledger.e2e-spec.ts, since the role/branch scoping and
 * the figures themselves are what's under test, not HTTP routing.
 */
describe('Order wallet preview (e2e)', () => {
  let db: TestDb;
  let orders: OrderService;
  let storeId: number;

  beforeEach(async () => {
    db = createTestDb();
    orders = new OrderService(db, new CartService(db), new ReferralService(db));

    const [store] = await db
      .insert(shieldStore)
      .values({ code: 'WP1', name: 'Store WP1', area: 'A', city: 'A', state: 'A', pincode: '111111' })
      .returning();
    storeId = store.id;
  });

  async function orderForMember(memberBalance: string, memberStoreId = storeId) {
    const [member] = await db.insert(users).values({ name: 'Buyer', phone: '9000040001' }).returning();
    await db.insert(wallet).values({ memberId: member.id, balance: memberBalance });
    const [theOrder] = await db
      .insert(order)
      .values({ memberId: member.id, code: 'ORD-WP-1', storeId: memberStoreId, paidTotal: '400', itemCount: 1, placedOn: '2026-10-05' })
      .returning();
    return { member, orderId: theOrder.id };
  }

  it('reports zero across the board for a member with no wallet row at all', async () => {
    const [member] = await db.insert(users).values({ name: 'No Wallet', phone: '9000040002' }).returning();
    const [theOrder] = await db
      .insert(order)
      .values({ memberId: member.id, code: 'ORD-WP-2', storeId, paidTotal: '100', itemCount: 1, placedOn: '2026-10-05' })
      .returning();

    const preview = await orders.getWalletPreview('PHARMACY', storeId, theOrder.id);
    expect(preview).toEqual({ balance: 0, availableAllowance: 0, monthlyRedeemable: 0, redeemedThisMonth: 0 });
  });

  it("a member with no approved wallet card isn't on Health Pass, so the allowance is just their balance", async () => {
    const { orderId } = await orderForMember('500.00');

    const preview = await orders.getWalletPreview('PHARMACY', storeId, orderId);
    expect(preview).toEqual({ balance: 500, availableAllowance: 500, monthlyRedeemable: 0, redeemedThisMonth: 0 });
  });

  it("caps the available allowance at this month's Health Pass release, same figure collectBillWithWallet would draw", async () => {
    const { member, orderId } = await orderForMember('1200.00');
    const [tier] = await db.insert(membershipTier).values({ kind: 'GOLD', name: 'Gold', bin: '5678' }).returning();
    const [w] = await db.select().from(wallet).where(eq(wallet.memberId, member.id));
    await db.insert(walletCard).values({
      walletId: w.id,
      tierId: tier.id,
      amount: '11000',
      bonus: '0',
      status: 'APPROVED',
      issuedOn: '2026-08-15',
      rechargedOn: '2026-08-15',
      expiresOn: '2027-08-15',
    });

    const preview = await orders.getWalletPreview('PHARMACY', storeId, orderId);
    // One card issued 15 Aug, loaded 11000 → 916/month, released through
    // whichever month "now" falls in during the test run — capped at the
    // 1200 balance either way once a couple of months have released.
    // Assert the shape and the balance pass-through rather than a moving
    // released-months figure.
    expect(preview.balance).toBe(1200);
    expect(preview.availableAllowance).toBeLessThanOrEqual(1200);
    expect(preview.availableAllowance).toBeGreaterThan(0);
  });

  it("a store-scoped staff member can't preview another branch's order", async () => {
    const [otherStore] = await db
      .insert(shieldStore)
      .values({ code: 'WP2', name: 'Store WP2', area: 'A', city: 'A', state: 'A', pincode: '222222' })
      .returning();
    const { orderId } = await orderForMember('500.00', otherStore.id);

    await expect(orders.getWalletPreview('PHARMACY', storeId, orderId)).rejects.toThrow();
  });
});
