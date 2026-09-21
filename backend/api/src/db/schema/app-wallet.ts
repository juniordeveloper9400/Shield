import { bigint, boolean, date, integer, numeric, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';
import { shieldStore } from './app-catalogue';
import { order } from './app-commerce';
import { approvalStatusEnum } from './app-prescription';

/**
 * Typed READ/WRITE MIRROR of wallet/rewards tables owned by
 * backend/db/app_schema.sql — see backend/docs/erd.md §2.
 * `wallet_card.sold_by_agent_id` is left as plain bigint (no FK) — `agent`
 * isn't mirrored yet; M7 adds it. `wallet_card.status` reuses
 * app.approval_status (PENDING/APPROVED/... — same enum as prescription
 * approvals, per the live schema).
 */
export const privilegeCardKindEnum = appSchema.enum('privilege_card_kind', ['SILVER', 'GOLD', 'PLATINUM']);
export const walletEntryKindEnum = appSchema.enum('wallet_entry_kind', [
  'ACTIVATION',
  'BONUS',
  'TOPUP',
  'SPEND',
  'POINTS_REDEEMED',
  'AGENT_EARNINGS',
  'REFERRAL_EARNINGS',
]);
export const rewardTxnReasonEnum = appSchema.enum('reward_txn_reason', [
  'REGISTRATION',
  'REFERRAL_LEVEL',
  'ORDER',
  'REDEMPTION',
  'ADJUSTMENT',
]);
export const referralStatusEnum = appSchema.enum('referral_status', [
  'SHARED',
  'REGISTERED',
  'TRANSACTED',
  'PLAN_ACTIVATED',
]);

export const membershipTier = appSchema.table('membership_tier', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  kind: privilegeCardKindEnum('kind').notNull(),
  name: text('name').notNull(),
  bin: text('bin').notNull(),
  blurb: text('blurb').notNull().default(''),
  bonusRate: numeric('bonus_rate', { precision: 4, scale: 3 }).notNull().default('0.100'),
  validityMonths: integer('validity_months').notNull().default(12),
  sort: integer('sort').notNull().default(0),
});

export const membershipTierLoad = appSchema.table('membership_tier_load', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  tierId: bigint('tier_id', { mode: 'number' }).notNull(),
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull(),
  sort: integer('sort').notNull().default(0),
});

export const wallet = appSchema.table('wallet', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  memberId: bigint('member_id', { mode: 'number' }).notNull(),
  balance: numeric('balance', { precision: 12, scale: 2 }).notNull().default('0'),
  rewardPoints: integer('reward_points').notNull().default(0),
  redeemedThisMonth: numeric('redeemed_this_month', { precision: 12, scale: 2 }).notNull().default('0'),
  openedAt: timestamp('opened_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const walletCard = appSchema.table('wallet_card', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  walletId: bigint('wallet_id', { mode: 'number' }).notNull(),
  tierId: bigint('tier_id', { mode: 'number' }).notNull(),
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull(),
  bonus: numeric('bonus', { precision: 12, scale: 2 }).notNull(),
  rechargedExtra: numeric('recharged_extra', { precision: 12, scale: 2 }).notNull().default('0'),
  cardNumber: text('card_number'),
  storeId: bigint('store_id', { mode: 'number' }).references(() => shieldStore.id),
  status: approvalStatusEnum('status').notNull().default('PENDING'),
  submittedAt: timestamp('submitted_at', { withTimezone: true }).notNull().defaultNow(),
  reviewedAt: timestamp('reviewed_at', { withTimezone: true }),
  reviewerNote: text('reviewer_note').notNull().default(''),
  receiptReference: text('receipt_reference'),
  receiptFileName: text('receipt_file_name'),
  // Real column in the live schema (migration 0012), missing from this
  // mirror until now — same known drift as other tables here.
  receiptImage: text('receipt_image'),
  issuedOn: date('issued_on').notNull(),
  rechargedOn: date('recharged_on').notNull(),
  expiresOn: date('expires_on').notNull(),
  soldByAgentId: bigint('sold_by_agent_id', { mode: 'number' }),
  // migration 0054: the admin's own verification checklist — separate from
  // what the member submitted above, and never read by
  // approve_wallet_card_activation() or any commission logic.
  verifiedReference: text('verified_reference'),
  receivedOn: date('received_on'),
  receiptVerified: boolean('receipt_verified').notNull().default(false),
  receivedAmount: numeric('received_amount', { precision: 12, scale: 2 }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

/**
 * A Health Pass activation's commission pool (10% of the loaded amount) is
 * split on approval: 60% of the pool to the agent who made the direct sale,
 * 10% to the one national agent when someone else made that sale, and
 * whatever is left over is the company's own share, not owed to any
 * agent — logged here (migration 0032) rather than credited nowhere, so the
 * admin console has a real, auditable "Reserved" total. Never surfaced to a
 * member or an agent anywhere in the app — see `wallet.service.ts`'s
 * `approveCard`.
 */
export const commissionReserveEntry = appSchema.table('commission_reserve_entry', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  walletCardId: bigint('wallet_card_id', { mode: 'number' }).notNull(),
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull(),
  /** 'POOL_LEFTOVER' (unspent agent pool) or 'COMPANY_SHARE' (8% of every activation) — migration 0053. */
  source: text('source').notNull().default('POOL_LEFTOVER'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const walletEntry = appSchema.table('wallet_entry', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  walletId: bigint('wallet_id', { mode: 'number' }).notNull(),
  kind: walletEntryKindEnum('kind').notNull(),
  label: text('label').notNull(),
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull(), // signed: credits positive, debits negative
  occurredOn: date('occurred_on').notNull(),
  walletCardId: bigint('wallet_card_id', { mode: 'number' }).references(() => walletCard.id),
  orderId: bigint('order_id', { mode: 'number' }).references(() => order.id),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const rewardPointTransaction = appSchema.table('reward_point_transaction', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  memberId: bigint('member_id', { mode: 'number' }).notNull(),
  points: integer('points').notNull(), // signed
  reason: rewardTxnReasonEnum('reason').notNull(),
  refType: text('ref_type'),
  refId: bigint('ref_id', { mode: 'number' }),
  note: text('note'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

/**
 * The refer-and-earn ladder (migration: pre-existing table, wired up in
 * 0042) — exact mirror of `lib/module/refer/referral_level.dart`'s
 * `ReferralLadder.levels`. Read by `ReferralService.awardLevelPointsIfCrossed`
 * to credit real reward points the moment an inviter's own direct-referral
 * count actually crosses a rung, rather than the client only ever
 * projecting what a rung "would" pay.
 */
export const referralLevel = appSchema.table('referral_level', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  level: integer('level').notNull(),
  name: text('name').notNull(),
  referralsRequired: integer('referrals_required').notNull(),
  points: integer('points').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const referral = appSchema.table('referral', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  inviterMemberId: bigint('inviter_member_id', { mode: 'number' }).notNull(),
  inviteeMemberId: bigint('invitee_member_id', { mode: 'number' }),
  inviteePhone: text('invitee_phone'),
  codeUsed: text('code_used'),
  status: referralStatusEnum('status').notNull().default('SHARED'),
  planAmount: numeric('plan_amount', { precision: 12, scale: 2 }),
  commissionAmount: numeric('commission_amount', { precision: 12, scale: 2 }).notNull().default('0'),
  registeredAt: timestamp('registered_at', { withTimezone: true }),
  transactedAt: timestamp('transacted_at', { withTimezone: true }),
  planActivatedAt: timestamp('plan_activated_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});
