import { bigint, date, integer, numeric, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';
import { shieldStore } from './app-catalogue';

export const investorPlanTypeEnum = appSchema.enum('investor_plan_type', ['YEARLY', 'MONTHLY']);
export const planChangeStatusEnum = appSchema.enum('plan_change_status', ['REQUESTED', 'APPROVED', 'REJECTED']);

export const investor = appSchema.table('investor', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  memberId: bigint('member_id', { mode: 'number' }),
  code: text('code').notNull(),
  name: text('name').notNull(),
  phone: text('phone').notNull(),
  investedStoreId: bigint('invested_store_id', { mode: 'number' }).references(() => shieldStore.id),
  totalUnits: integer('total_units').notNull().default(0),
  unitPrice: numeric('unit_price', { precision: 12, scale: 2 }).notNull().default('150000'),
  investedSince: date('invested_since').notNull(),
  roiPercent: numeric('roi_percent', { precision: 6, scale: 2 }).notNull().default('0'),
  planType: investorPlanTypeEnum('plan_type').notNull().default('YEARLY'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const investorPlanChangeRequest = appSchema.table('investor_plan_change_request', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  investorId: bigint('investor_id', { mode: 'number' }).notNull(),
  requestedPlanType: investorPlanTypeEnum('requested_plan_type').notNull(),
  status: planChangeStatusEnum('status').notNull().default('REQUESTED'),
  note: text('note'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  resolvedAt: timestamp('resolved_at', { withTimezone: true }),
});
