import { bigint, boolean, date, numeric, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';

/**
 * Typed READ/WRITE MIRROR of ledger tables owned by
 * backend/db/app_schema.sql — see backend/db/migrations/0074_ledger_core.sql
 * for why these exist and backend/docs/erd.md §2 for the wider schema.
 *
 * Each shop is its own legal entity; every journal entry belongs to one.
 * `chart_of_account` and `posting_rule` are provisional until an accountant
 * reviews them — see `isProvisional` on both.
 */
export const legalEntity = appSchema.table('legal_entity', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  code: text('code').notNull(),
  name: text('name').notNull(),
  isProvisional: boolean('is_provisional').notNull().default(true),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const chartOfAccount = appSchema.table('chart_of_account', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  code: text('code').notNull(),
  name: text('name').notNull(),
  /** 'ASSET' | 'LIABILITY' | 'EQUITY' | 'REVENUE' | 'EXPENSE' */
  type: text('type').notNull(),
  isProvisional: boolean('is_provisional').notNull().default(true),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

/** Maps one event's named line (`lineRole`) to the account it posts to, so a
 *  posting function looks the account up instead of hardcoding it. */
export const postingRule = appSchema.table('posting_rule', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  event: text('event').notNull(),
  lineRole: text('line_role').notNull(),
  accountCode: text('account_code').notNull(),
  isProvisional: boolean('is_provisional').notNull().default(true),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const journalEntry = appSchema.table('journal_entry', {
  id: uuid('id').primaryKey().defaultRandom(),
  entityId: bigint('entity_id', { mode: 'number' }).notNull(),
  postedOn: date('posted_on').notNull(),
  sourceTable: text('source_table').notNull(),
  sourceId: text('source_id').notNull(),
  event: text('event').notNull(),
  description: text('description').notNull().default(''),
  /** A correction is a reversing entry — these two columns link the pair.
   *  An entry is never edited after it's posted. */
  reversalOf: uuid('reversal_of'),
  reversedBy: uuid('reversed_by'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const journalLine = appSchema.table('journal_line', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  entryId: uuid('entry_id').notNull(),
  accountId: bigint('account_id', { mode: 'number' }).notNull(),
  debit: numeric('debit', { precision: 12, scale: 2 }).notNull().default('0'),
  credit: numeric('credit', { precision: 12, scale: 2 }).notNull().default('0'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

/** One row per entity per calendar month. `closedAt` set blocks any further
 *  posting into that month for that entity — enforced by
 *  `app.assert_ledger_period_open`, called from inside each posting
 *  function's own transaction. */
export const ledgerPeriod = appSchema.table('ledger_period', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  entityId: bigint('entity_id', { mode: 'number' }).notNull(),
  period: date('period').notNull(),
  closedAt: timestamp('closed_at', { withTimezone: true }),
  closedBy: text('closed_by'),
});
