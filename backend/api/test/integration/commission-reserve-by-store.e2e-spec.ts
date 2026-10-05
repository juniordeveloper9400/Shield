import { createTestDb, type TestDb } from './create-test-db';
import { ReferralService } from '../../src/modules/wallet/referral.service';
import { WalletService } from '../../src/modules/wallet/wallet.service';
import {
  commissionReserveEntry,
  membershipTier,
  shieldStore,
  users,
  wallet,
  walletCard,
} from '../../src/db/schema';

describe('Commission reserve, split by store', () => {
  let db: TestDb;
  let wallets: WalletService;
  let storeA: number;
  let storeB: number;

  beforeEach(async () => {
    db = createTestDb();
    wallets = new WalletService(db, new ReferralService(db));

    const [a] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-RA', name: 'Store A', area: 'A', city: 'A', state: 'A', pincode: '111111' })
      .returning();
    const [b] = await db
      .insert(shieldStore)
      .values({ code: 'SHD-RB', name: 'Store B', area: 'B', city: 'B', state: 'B', pincode: '222222' })
      .returning();
    storeA = a.id;
    storeB = b.id;

    const [tier] = await db
      .insert(membershipTier)
      .values({ kind: 'SILVER', name: 'Silver', bin: '1234', bonusRate: '0.1', validityMonths: 12 })
      .returning();
    const [member] = await db.insert(users).values({ name: 'Buyer', phone: '9000020001' }).returning();
    const [account] = await db.insert(wallet).values({ memberId: member.id }).returning();

    // Two activations: one made at store A, one at store B, plus one with no store.
    const cards = [
      { storeId: storeA, amount: '1000', reserve: 80, source: 'COMPANY_SHARE' as const },
      { storeId: storeB, amount: '2000', reserve: 160, source: 'COMPANY_SHARE' as const },
      { storeId: null, amount: '500', reserve: 40, source: 'POOL_LEFTOVER' as const },
    ];
    for (const c of cards) {
      const [card] = await db
        .insert(walletCard)
        .values({
          walletId: account.id,
          tierId: tier.id,
          amount: c.amount,
          bonus: '0',
          storeId: c.storeId,
          status: 'APPROVED',
          issuedOn: '2026-09-20',
          rechargedOn: '2026-09-20',
          expiresOn: '2027-09-20',
        })
        .returning();
      await db.insert(commissionReserveEntry).values({ walletCardId: card.id, amount: String(c.reserve), source: c.source });
    }
  });

  it('gives an admin every store, each with its own total, and the grand total', async () => {
    const view = await wallets.getCommissionReserve('ADMIN', null);

    expect(view.total).toBe(280);
    const byCode = Object.fromEntries(view.byStore.map((s) => [s.storeName, s.total]));
    expect(byCode).toEqual({ 'Store A': 80, 'Store B': 160, Unassigned: 40 });

    const storeB_ = view.byStore.find((s) => s.storeId === storeB)!;
    expect(storeB_.companyShare).toBe(160);
    expect(storeB_.poolLeftover).toBe(0);
    expect(view.entries).toHaveLength(3);
  });

  it('gives a pharmacy admin only its own store, with that store as the total', async () => {
    const view = await wallets.getCommissionReserve('PHARMACY', storeA);

    expect(view.total).toBe(80);
    expect(view.byStore.map((s) => s.storeId)).toEqual([storeA]);
    expect(view.entries.every((e) => e.storeId === storeA)).toBe(true);
  });

  it('shows a store-bound admin nothing when it has no store assigned', async () => {
    const view = await wallets.getCommissionReserve('PHARMACY', null);
    expect(view.total).toBe(0);
    expect(view.byStore).toEqual([]);
    expect(view.entries).toEqual([]);
  });
});
