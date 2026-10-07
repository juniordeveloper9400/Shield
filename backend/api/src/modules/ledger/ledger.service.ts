import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, desc, eq, sql } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { chartOfAccount, journalEntry, journalLine, ledgerPeriod, legalEntity } from '../../db/schema';

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/**
 * Reads only — migration 0074/0075's journal and chart of accounts. See
 * that migration's own header for what is and isn't posted yet: today only
 * a store's cash receipt on activation, and agent withdrawal/wallet-move
 * payouts, write anything here. Every account and posting rule is
 * provisional until an accountant reviews it (see `isProvisional` below) —
 * this service surfaces that flag rather than hiding it, so nobody mistakes
 * a provisional figure for a reviewed one.
 */
@Injectable()
export class LedgerService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  listEntities() {
    return this.db
      .select({
        id: legalEntity.id,
        code: legalEntity.code,
        name: legalEntity.name,
        isProvisional: legalEntity.isProvisional,
      })
      .from(legalEntity)
      .orderBy(legalEntity.name);
  }

  /**
   * Every account that has at least one posted line, summed — scoped to one
   * entity and/or one calendar month when given. `net` is debit minus
   * credit; whether that's the account's "normal" side depends on its type
   * (an ASSET or EXPENSE account normally sits net-debit, a LIABILITY,
   * EQUITY or REVENUE account normally sits net-credit) — left for the
   * caller to interpret rather than guessed at here.
   */
  async trialBalance(params: { entityId?: number; period?: string; type?: string }) {
    const conditions = [];
    if (params.entityId !== undefined) conditions.push(eq(journalEntry.entityId, params.entityId));
    if (params.period) {
      conditions.push(
        sql`${journalEntry.postedOn} >= ${params.period}::date
            AND ${journalEntry.postedOn} < (${params.period}::date + interval '1 month')`,
      );
    }
    if (params.type) conditions.push(eq(chartOfAccount.type, params.type));

    const rows = await this.db
      .select({
        accountCode: chartOfAccount.code,
        accountName: chartOfAccount.name,
        accountType: chartOfAccount.type,
        isProvisional: chartOfAccount.isProvisional,
        debit: sql<string>`coalesce(sum(${journalLine.debit}), 0)`,
        credit: sql<string>`coalesce(sum(${journalLine.credit}), 0)`,
      })
      .from(journalLine)
      .innerJoin(journalEntry, eq(journalEntry.id, journalLine.entryId))
      .innerJoin(chartOfAccount, eq(chartOfAccount.id, journalLine.accountId))
      .where(conditions.length ? and(...conditions) : undefined)
      .groupBy(chartOfAccount.id, chartOfAccount.code, chartOfAccount.name, chartOfAccount.type, chartOfAccount.isProvisional)
      .orderBy(chartOfAccount.code);

    return rows.map((r) => ({
      accountCode: r.accountCode,
      accountName: r.accountName,
      accountType: r.accountType,
      isProvisional: r.isProvisional,
      debit: Number(r.debit),
      credit: Number(r.credit),
      net: round2(Number(r.debit) - Number(r.credit)),
    }));
  }

  listPeriods(entityId?: number) {
    return this.db
      .select()
      .from(ledgerPeriod)
      .where(entityId !== undefined ? eq(ledgerPeriod.entityId, entityId) : undefined)
      .orderBy(desc(ledgerPeriod.period));
  }

  /** Blocks any further posting into this entity's month — enforced by
   *  `app.assert_ledger_period_open`, which every posting function calls. */
  async closePeriod(entityId: number, period: string, closedBy: string) {
    const [entity] = await this.db.select({ id: legalEntity.id }).from(legalEntity).where(eq(legalEntity.id, entityId));
    if (!entity) throw new NotFoundException('No such legal entity');

    const [row] = await this.db
      .insert(ledgerPeriod)
      .values({ entityId, period, closedAt: new Date(), closedBy })
      .onConflictDoUpdate({
        target: [ledgerPeriod.entityId, ledgerPeriod.period],
        set: { closedAt: new Date(), closedBy },
      })
      .returning();
    return row;
  }
}
