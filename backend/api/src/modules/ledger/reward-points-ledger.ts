import { randomUUID } from 'node:crypto';
import { and, eq, inArray } from 'drizzle-orm';
import type { Database } from '../../db/client';
import { chartOfAccount, journalEntry, journalLine, legalEntity, postingRule } from '../../db/schema';

// Mirrors RewardsService.POINTS_PER_RUPEE — kept as its own constant here
// rather than imported, to avoid a circular import between this file and
// rewards.service.ts (which calls postRewardPointsRedeemed below). Change
// both together if the exchange rate ever does.
const POINTS_PER_RUPEE = 100;

/**
 * Posts reward points to the ledger (migration 0074's `reward_points_issued`
 * / `reward_points_redeemed` events) — company-wide money, not tied to any
 * shop, so always at the `HQ` entity. Called from every place that writes
 * an `app.reward_point_transaction` row: identity.service.ts (signup),
 * referral.service.ts (referral level), order.service.ts (order reward),
 * and rewards.service.ts (redemption). Never blocks the real award or
 * redemption — the same tolerance every other posting helper in this
 * codebase uses, since this is new, still-unreviewed infrastructure riding
 * alongside working code.
 */
async function ledgerAccounts(tx: Database, event: string, roles: string[]) {
  const mapped = await tx
    .select({ lineRole: postingRule.lineRole, accountId: chartOfAccount.id })
    .from(postingRule)
    .innerJoin(chartOfAccount, eq(chartOfAccount.code, postingRule.accountCode))
    .where(and(eq(postingRule.event, event), inArray(postingRule.lineRole, roles)));
  return Object.fromEntries(mapped.map((a) => [a.lineRole, a.accountId])) as Record<string, number | undefined>;
}

/** Dr Reward points expense / Cr Reward points liability, for points just
 *  awarded (`points` is positive). */
export async function postRewardPointsIssued(
  tx: Database,
  params: { rewardPointTransactionId: number; points: number; reason: string },
) {
  try {
    if (params.points <= 0) return;
    const [hq] = await tx.select({ id: legalEntity.id }).from(legalEntity).where(eq(legalEntity.code, 'HQ'));
    if (!hq) return;

    const byRole = await ledgerAccounts(tx, 'reward_points_issued', ['expense', 'liability']);
    if (!byRole.expense || !byRole.liability) return;

    const rupees = (params.points / POINTS_PER_RUPEE).toFixed(2);
    const [entry] = await tx
      .insert(journalEntry)
      .values({
        id: randomUUID(),
        entityId: hq.id,
        postedOn: new Date().toISOString().slice(0, 10),
        sourceTable: 'reward_point_transaction',
        sourceId: String(params.rewardPointTransactionId),
        event: 'reward_points_issued',
        description: `${params.points} reward points awarded — ${params.reason}`,
      })
      .returning();
    if (!entry) return;

    await tx.insert(journalLine).values([
      { entryId: entry.id, accountId: byRole.expense, debit: rupees, credit: '0' },
      { entryId: entry.id, accountId: byRole.liability, debit: '0', credit: rupees },
    ]);
  } catch {
    // Ledger posting must never block a real reward points award.
  }
}

/** Dr Reward points liability / Cr Member wallet liability, for points just
 *  redeemed into the wallet (`points` is positive, the amount redeemed). */
export async function postRewardPointsRedeemed(
  tx: Database,
  params: { rewardPointTransactionId: number; points: number },
) {
  try {
    if (params.points <= 0) return;
    const [hq] = await tx.select({ id: legalEntity.id }).from(legalEntity).where(eq(legalEntity.code, 'HQ'));
    if (!hq) return;

    const byRole = await ledgerAccounts(tx, 'reward_points_redeemed', ['liability', 'member_wallet']);
    if (!byRole.liability || !byRole.member_wallet) return;

    const rupees = (params.points / POINTS_PER_RUPEE).toFixed(2);
    const [entry] = await tx
      .insert(journalEntry)
      .values({
        id: randomUUID(),
        entityId: hq.id,
        postedOn: new Date().toISOString().slice(0, 10),
        sourceTable: 'reward_point_transaction',
        sourceId: String(params.rewardPointTransactionId),
        event: 'reward_points_redeemed',
        description: `${params.points} reward points redeemed`,
      })
      .returning();
    if (!entry) return;

    await tx.insert(journalLine).values([
      { entryId: entry.id, accountId: byRole.liability, debit: rupees, credit: '0' },
      { entryId: entry.id, accountId: byRole.member_wallet, debit: '0', credit: rupees },
    ]);
  } catch {
    // Ledger posting must never block a real redemption.
  }
}
