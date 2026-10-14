import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, desc, eq, sql } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { agent, agentCommission, chartOfAccount, journalEntry, journalLine, ledgerPeriod, legalEntity } from '../../db/schema';

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

  /** The chart of accounts — small and static, for the Account filter on
   *  the per-person ledger report. */
  chartOfAccounts() {
    return this.db
      .select({
        code: chartOfAccount.code,
        name: chartOfAccount.name,
        type: chartOfAccount.type,
        isProvisional: chartOfAccount.isProvisional,
      })
      .from(chartOfAccount)
      .orderBy(chartOfAccount.code);
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

  /**
   * One subject's (member/agent/investor) Debit, Credit and running Closing
   * balance for one account, for one calendar month — a real sub-ledger, not
   * a store-wide trial-balance row. Opening balance is every line posted
   * before the month started; closing = opening + this month's movement,
   * signed per the account's own type (asset/expense: debit grows the
   * balance; liability/equity/revenue: credit grows it — see
   * `shieldweb/src/lib/ledgerReport.ts`'s `movementBalance`, the same
   * convention this mirrors server-side).
   */
  async subjectLedger(params: {
    subjectType: string;
    subjectId: number;
    accountCode: string;
    entityId?: number;
    period: string;
  }) {
    const [account] = await this.db
      .select({ id: chartOfAccount.id, code: chartOfAccount.code, name: chartOfAccount.name, type: chartOfAccount.type })
      .from(chartOfAccount)
      .where(eq(chartOfAccount.code, params.accountCode));
    if (!account) throw new NotFoundException('No such account');

    const subjectCondition = and(
      eq(journalLine.subjectType, params.subjectType),
      eq(journalLine.subjectId, params.subjectId),
      eq(journalLine.accountId, account.id),
    );
    const entityCondition = params.entityId !== undefined ? eq(journalEntry.entityId, params.entityId) : undefined;

    const sums = async (extra: ReturnType<typeof sql> | undefined) => {
      const [row] = await this.db
        .select({
          debit: sql<string>`coalesce(sum(${journalLine.debit}), 0)`,
          credit: sql<string>`coalesce(sum(${journalLine.credit}), 0)`,
        })
        .from(journalLine)
        .innerJoin(journalEntry, eq(journalEntry.id, journalLine.entryId))
        .where(and(subjectCondition, entityCondition, extra));
      return { debit: Number(row.debit), credit: Number(row.credit) };
    };

    const opening = await sums(sql`${journalEntry.postedOn} < ${params.period}::date`);
    const movement = await sums(
      sql`${journalEntry.postedOn} >= ${params.period}::date
          AND ${journalEntry.postedOn} < (${params.period}::date + interval '1 month')`,
    );

    // Debit grows an ASSET/EXPENSE account's balance; credit grows the other
    // three types — same convention `trialBalance`'s own `net` leaves for
    // the caller, made explicit here since a closing balance needs a sign,
    // not just a net figure.
    const debitNormal = account.type === 'ASSET' || account.type === 'EXPENSE';
    const signed = (s: { debit: number; credit: number }) => (debitNormal ? s.debit - s.credit : s.credit - s.debit);

    const openingBalance = round2(signed(opening));
    const closingBalance = round2(openingBalance + signed(movement));

    const lines = await this.db
      .select({
        id: journalLine.id,
        debit: journalLine.debit,
        credit: journalLine.credit,
        postedOn: journalEntry.postedOn,
        description: journalEntry.description,
        event: journalEntry.event,
      })
      .from(journalLine)
      .innerJoin(journalEntry, eq(journalEntry.id, journalLine.entryId))
      .where(
        and(
          subjectCondition,
          entityCondition,
          sql`${journalEntry.postedOn} >= ${params.period}::date
              AND ${journalEntry.postedOn} < (${params.period}::date + interval '1 month')`,
        ),
      )
      .orderBy(journalEntry.postedOn);

    return {
      accountCode: account.code,
      accountName: account.name,
      accountType: account.type,
      openingBalance,
      debit: round2(movement.debit),
      credit: round2(movement.credit),
      closingBalance,
      lines: lines.map((l) => ({
        id: l.id,
        postedOn: l.postedOn,
        description: l.description,
        event: l.event,
        debit: Number(l.debit),
        credit: Number(l.credit),
      })),
    };
  }

  listPeriods(entityId?: number) {
    return this.db
      .select()
      .from(ledgerPeriod)
      .where(entityId !== undefined ? eq(ledgerPeriod.entityId, entityId) : undefined)
      .orderBy(desc(ledgerPeriod.period));
  }

  /** Every agent actually credited from one activation's commission pool —
   *  the row-level record behind `app.agent.earned`'s running total (see
   *  migration 0079). `walletCardId` or `agentId` narrows it; neither
   *  returns everything, which isn't useful on a real dataset. */
  async agentCommissions(params: { walletCardId?: number; agentId?: number }) {
    if (params.walletCardId === undefined && params.agentId === undefined) return [];
    const conditions = [];
    if (params.walletCardId !== undefined) conditions.push(eq(agentCommission.walletCardId, params.walletCardId));
    if (params.agentId !== undefined) conditions.push(eq(agentCommission.agentId, params.agentId));

    return this.db
      .select({
        id: agentCommission.id,
        walletCardId: agentCommission.walletCardId,
        agentId: agentCommission.agentId,
        agentCode: agent.code,
        agentName: agent.name,
        hop: agentCommission.hop,
        rate: agentCommission.rate,
        amount: agentCommission.amount,
        journalEntryId: agentCommission.journalEntryId,
        createdAt: agentCommission.createdAt,
      })
      .from(agentCommission)
      .innerJoin(agent, eq(agent.id, agentCommission.agentId))
      .where(and(...conditions))
      .orderBy(agentCommission.hop);
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
