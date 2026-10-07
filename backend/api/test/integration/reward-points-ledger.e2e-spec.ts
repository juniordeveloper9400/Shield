import { eq } from 'drizzle-orm';
import { createTestDb, type TestDb } from './create-test-db';
import { postRewardPointsIssued, postRewardPointsRedeemed } from '../../src/modules/ledger/reward-points-ledger';
import { chartOfAccount, journalEntry, journalLine, legalEntity, postingRule } from '../../src/db/schema';

/**
 * Reward points posting is plain TypeScript (reward-points-ledger.ts),
 * called from identity.service.ts (registration), referral.service.ts
 * (referral level), order.service.ts (order reward) and rewards.service.ts
 * (redemption) — so it runs under pg-mem like any other service.
 *
 * Not covered: app.award_referral_level_points, the PL/pgSQL duplicate of
 * referral.service.ts's own award function, called from inside
 * approve_wallet_card_activation (migration 0053). That path needs its own
 * SQL posting, same as migrations 0075/0076, and isn't done yet.
 */
describe('Reward points posting (e2e)', () => {
  let db: TestDb;
  let hqEntityId: number;
  let expenseAcct: number;
  let liabilityAcct: number;
  let walletAcct: number;

  beforeEach(async () => {
    db = createTestDb();
    const [hq] = await db.insert(legalEntity).values({ code: 'HQ', name: 'Head Office' }).returning();
    hqEntityId = hq.id;

    const [expense] = await db.insert(chartOfAccount).values({ code: 'RPEXP', name: 'Reward points expense', type: 'EXPENSE' }).returning();
    const [liability] = await db.insert(chartOfAccount).values({ code: 'RPLIAB', name: 'Reward points liability', type: 'LIABILITY' }).returning();
    const [walletLiability] = await db.insert(chartOfAccount).values({ code: 'WLIAB', name: 'Member wallet liability', type: 'LIABILITY' }).returning();
    expenseAcct = expense.id;
    liabilityAcct = liability.id;
    walletAcct = walletLiability.id;

    await db.insert(postingRule).values([
      { event: 'reward_points_issued', lineRole: 'expense', accountCode: 'RPEXP' },
      { event: 'reward_points_issued', lineRole: 'liability', accountCode: 'RPLIAB' },
      { event: 'reward_points_redeemed', lineRole: 'liability', accountCode: 'RPLIAB' },
      { event: 'reward_points_redeemed', lineRole: 'member_wallet', accountCode: 'WLIAB' },
    ]);
  });

  async function linesFor(sourceId: string) {
    return db
      .select({ debit: journalLine.debit, credit: journalLine.credit, accountId: journalLine.accountId })
      .from(journalEntry)
      .innerJoin(journalLine, eq(journalLine.entryId, journalEntry.id))
      .where(eq(journalEntry.sourceId, sourceId));
  }

  it('posts an award: Dr reward points expense / Cr reward points liability', async () => {
    await postRewardPointsIssued(db, { rewardPointTransactionId: 1, points: 500, reason: 'registration bonus' });

    const lines = await linesFor('1');
    expect(lines).toHaveLength(2);
    expect(Number(lines.find((l) => l.accountId === expenseAcct)!.debit)).toBe(5); // 500 points / 100 = ₹5
    expect(Number(lines.find((l) => l.accountId === liabilityAcct)!.credit)).toBe(5);
  });

  it('posts a redemption: Dr reward points liability / Cr member wallet liability', async () => {
    await postRewardPointsRedeemed(db, { rewardPointTransactionId: 2, points: 1000 });

    const lines = await linesFor('2');
    expect(lines).toHaveLength(2);
    expect(Number(lines.find((l) => l.accountId === liabilityAcct)!.debit)).toBe(10); // ₹10
    expect(Number(lines.find((l) => l.accountId === walletAcct)!.credit)).toBe(10);
  });

  it('posts nothing for zero or negative points, without throwing', async () => {
    await postRewardPointsIssued(db, { rewardPointTransactionId: 3, points: 0, reason: 'nothing' });
    await postRewardPointsRedeemed(db, { rewardPointTransactionId: 4, points: -1 });

    expect(await linesFor('3')).toHaveLength(0);
    expect(await linesFor('4')).toHaveLength(0);
  });

  it('posts nothing, and does not throw, when there is no HQ entity', async () => {
    const fresh = createTestDb(); // no legal_entity rows at all
    await expect(postRewardPointsIssued(fresh, { rewardPointTransactionId: 5, points: 100, reason: 'x' })).resolves.toBeUndefined();
    const lines = await fresh
      .select()
      .from(journalEntry)
      .where(eq(journalEntry.sourceTable, 'reward_point_transaction'));
    expect(lines).toHaveLength(0);
  });

  it('every posted entry is scoped to the HQ entity, not any store', async () => {
    await postRewardPointsIssued(db, { rewardPointTransactionId: 6, points: 200, reason: 'x' });
    const [entry] = await db.select().from(journalEntry).where(eq(journalEntry.sourceId, '6'));
    expect(entry.entityId).toBe(hqEntityId);
  });
});
