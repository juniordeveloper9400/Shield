import { bigint, boolean, date, numeric, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';

/**
 * Typed READ/WRITE MIRROR of agent tables owned by
 * backend/db/app_schema.sql — see backend/docs/erd.md §2.
 * `agent.area_id` is deliberately a plain uuid, no FK — polymorphic by
 * `level` into region/state/district/assembly/lsgd/ward, exactly as
 * migration 0017 documents. Application-enforced, see
 * modules/agent/agent.service.ts.
 */
export const agentLevelEnum = appSchema.enum('agent_level', [
  'NATIONAL',
  'REGION',
  'STATE',
  'DISTRICT',
  'ASSEMBLY',
  'LSGD',
  'WARD',
]);
export const agentApprovalEnum = appSchema.enum('agent_approval', ['PENDING', 'APPROVED', 'REJECTED']);
export const withdrawalStatusEnum = appSchema.enum('withdrawal_status', ['PENDING', 'PAID', 'REJECTED']);

export const agent = appSchema.table('agent', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  memberId: bigint('member_id', { mode: 'number' }),
  code: text('code').notNull(),
  name: text('name').notNull(),
  phone: text('phone').notNull(),
  level: agentLevelEnum('level').notNull(),
  parentId: bigint('parent_id', { mode: 'number' }),
  active: boolean('active').notNull().default(true),
  area: text('area').notNull().default(''),
  areaId: uuid('area_id'), // polymorphic — see doc comment above
  firstName: text('first_name').notNull().default(''),
  middleName: text('middle_name').notNull().default(''),
  lastName: text('last_name').notNull().default(''),
  dob: date('dob'),
  aadhaar: text('aadhaar').notNull().default(''),
  pan: text('pan').notNull().default(''),
  address: text('address').notNull().default(''),
  pincode: text('pincode').notNull().default(''),
  place: text('place').notNull().default(''),
  accountNumber: text('account_number').notNull().default(''),
  photoPath: text('photo_path'),
  approvalStatus: agentApprovalEnum('approval_status').notNull().default('APPROVED'),
  reviewedAt: timestamp('reviewed_at', { withTimezone: true }),
  reviewerNote: text('reviewer_note').notNull().default(''),
  earned: numeric('earned', { precision: 12, scale: 2 }).notNull().default('0'),
  redeemed: numeric('redeemed', { precision: 12, scale: 2 }).notNull().default('0'),
  personalSales: numeric('personal_sales', { precision: 12, scale: 2 }).notNull().default('0'),
  movedToWallet: numeric('moved_to_wallet', { precision: 12, scale: 2 }).notNull().default('0'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const agentRequest = appSchema.table('agent_request', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  parentAgentId: bigint('parent_agent_id', { mode: 'number' }),
  requestedLevel: agentLevelEnum('requested_level').notNull(),
  requestedArea: text('requested_area').notNull().default(''),
  requestedAreaId: uuid('requested_area_id'),
  name: text('name').notNull(),
  phone: text('phone').notNull(),
  firstName: text('first_name').notNull().default(''),
  middleName: text('middle_name').notNull().default(''),
  lastName: text('last_name').notNull().default(''),
  dob: date('dob'),
  aadhaar: text('aadhaar').notNull().default(''),
  pan: text('pan').notNull().default(''),
  address: text('address').notNull().default(''),
  pincode: text('pincode').notNull().default(''),
  place: text('place').notNull().default(''),
  accountNumber: text('account_number').notNull().default(''),
  photoPath: text('photo_path'),
  status: agentApprovalEnum('status').notNull().default('PENDING'),
  reviewerNote: text('reviewer_note').notNull().default(''),
  reviewedAt: timestamp('reviewed_at', { withTimezone: true }),
  agentId: bigint('agent_id', { mode: 'number' }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const agentCustomer = appSchema.table('agent_customer', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  agentId: bigint('agent_id', { mode: 'number' }).notNull(),
  memberId: bigint('member_id', { mode: 'number' }),
  name: text('name').notNull(),
  phone: text('phone').notNull().default(''),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

/** One Health Pass activation credited to a `agentCustomer` link — written
 *  on every `WalletService.approveCard`, whether or not it happened to pay
 *  commission, for the agent portal's own "Direct sale"/"Team sales"
 *  bookkeeping (a different concern from `agent.earned`). */
export const agentCustomerPlan = appSchema.table('agent_customer_plan', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  agentCustomerId: bigint('agent_customer_id', { mode: 'number' }).notNull(),
  tierId: bigint('tier_id', { mode: 'number' }).notNull(),
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull(),
  activatedOn: date('activated_on').notNull(),
  walletCardId: bigint('wallet_card_id', { mode: 'number' }),
});

export const agentWithdrawal = appSchema.table('agent_withdrawal', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  agentId: bigint('agent_id', { mode: 'number' }).notNull(),
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull(),
  status: withdrawalStatusEnum('status').notNull().default('PENDING'),
  requestedOn: date('requested_on').notNull(),
  processedOn: date('processed_on'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  // Migration 0059 — the cross-verification review trail. `approvedAt` set
  // (status still PENDING) means "verified, awaiting payment" — a real
  // third state app.withdrawal_status has no enum value for, distinguished
  // by this column rather than a status value. See
  // app.review_agent_withdrawal's own doc: APPROVE never touches status,
  // only PAY/REJECT do.
  approvedAt: timestamp('approved_at', { withTimezone: true }),
  approvedBy: text('approved_by'),
  verifiedAccount: text('verified_account'),
  verificationNote: text('verification_note'),
  paymentReference: text('payment_reference'),
  processedBy: text('processed_by'),
});
