import { bigint, boolean, date, integer, numeric, smallint, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';
import { order } from './app-commerce';
import { product, shieldStore } from './app-catalogue';

/**
 * Typed READ/WRITE MIRROR of prescription tables owned by
 * backend/db/app_schema.sql — see backend/docs/erd.md §2. `prescription.
 * storage_path` already exists in the live DDL for exactly the object-
 * storage migration backend/docs/security.md calls for — this module is
 * the first to actually use it instead of writing to `image` (a data: URI).
 * A prescription's actual image content lives in `prescriptionImage`
 * (migration 0040, up to a handful of photos per prescription) — the
 * `image`/`imageRotation` columns on `prescription` itself are legacy.
 */
export const medicineDurationEnum = appSchema.enum('medicine_duration', [
  'ONE_WEEK',
  'FIFTEEN_DAYS',
  'ONE_MONTH',
  'TWO_MONTHS',
  'THREE_MONTHS',
]);
export const prescriptionStatusEnum = appSchema.enum('prescription_status', [
  'AWAITING_REVIEW',
  'READ',
  'IN_CART',
  'ORDERED',
]);
// Pharmacist-only, never surfaced on a member-facing read — see
// modules/prescription/prescription.service.ts field projection.
export const prescriptionMedicineStatusEnum = appSchema.enum('prescription_medicine_status', [
  'AVAILABLE',
  'OUT_OF_STOCK',
  'NOT_POSSIBLE',
  'ORDERED',
]);
export const approvalStatusEnum = appSchema.enum('approval_status', [
  'PENDING',
  'APPROVED',
  'PARTIALLY_APPROVED',
  'REJECTED',
  'CANCELLED',
  'ON_HOLD',
]);

export const prescription = appSchema.table('prescription', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  memberId: bigint('member_id', { mode: 'number' }).notNull(),
  patientId: bigint('patient_id', { mode: 'number' }).notNull(),
  storeId: bigint('store_id', { mode: 'number' }).references(() => shieldStore.id),
  code: text('code').notNull(),
  fileName: text('file_name').notNull().default(''),
  storagePath: text('storage_path'),
  image: text('image'), // legacy data: URI column — new uploads use storagePath instead, see above
  imageRotation: smallint('image_rotation').notNull().default(0),
  doctor: text('doctor').notNull().default(''),
  duration: medicineDurationEnum('duration'),
  customDays: integer('custom_days'),
  recurringFrom: date('recurring_from'),
  recurringUntil: date('recurring_until'),
  status: prescriptionStatusEnum('status').notNull().default('AWAITING_REVIEW'),
  reviewedAt: timestamp('reviewed_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  deletedAt: timestamp('deleted_at', { withTimezone: true }),
});

/**
 * Up to a handful of photos per prescription (a script is often more than
 * one page), each independently rotatable — see migration 0040. `prescription.
 * image` / `image_rotation` are legacy, no longer written to; this table is
 * the one source of truth going forward.
 */
export const prescriptionImage = appSchema.table('prescription_image', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  prescriptionId: bigint('prescription_id', { mode: 'number' }).notNull(),
  sort: integer('sort').notNull().default(0),
  image: text('image').notNull(),
  imageRotation: smallint('image_rotation').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const prescriptionMedicine = appSchema.table('prescription_medicine', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  prescriptionId: bigint('prescription_id', { mode: 'number' }).notNull(),
  sort: integer('sort').notNull().default(0),
  name: text('name').notNull(),
  pack: text('pack').notNull().default(''),
  doseMorning: integer('dose_morning').notNull().default(0),
  doseAfternoon: integer('dose_afternoon').notNull().default(0),
  doseNight: integer('dose_night').notNull().default(0),
  totalUnits: integer('total_units').notNull().default(0),
  routeTime: text('route_time').notNull().default(''),
  productId: bigint('product_id', { mode: 'number' }).references(() => product.id),
  status: prescriptionMedicineStatusEnum('status').notNull().default('AVAILABLE'),
});

export const prescriptionOrder = appSchema.table('prescription_order', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  prescriptionId: bigint('prescription_id', { mode: 'number' }).notNull(),
  orderId: bigint('order_id', { mode: 'number' }).references(() => order.id),
  storeId: bigint('store_id', { mode: 'number' }).references(() => shieldStore.id),
  status: text('status').notNull().default('SUBMITTED'),
  customerNotes: text('customer_notes'),
  submittedAt: timestamp('submitted_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const approval = appSchema.table('approval', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  memberId: bigint('member_id', { mode: 'number' }).notNull(),
  orderId: bigint('order_id', { mode: 'number' }).references(() => order.id),
  prescriptionId: bigint('prescription_id', { mode: 'number' }).references(() => prescription.id),
  code: text('code').notNull(),
  orderRef: text('order_ref'),
  patientName: text('patient_name'),
  pharmacistNote: text('pharmacist_note').notNull().default(''),
  status: approvalStatusEnum('status').notNull().default('PENDING'),
  raisedOn: date('raised_on').notNull(),
  respondedAt: timestamp('responded_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const approvalItem = appSchema.table('approval_item', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  approvalId: bigint('approval_id', { mode: 'number' }).notNull(),
  name: text('name').notNull(),
  pack: text('pack').notNull().default(''),
  quantity: integer('quantity').notNull().default(1),
  price: numeric('price', { precision: 12, scale: 2 }).notNull().default('0'),
  note: text('note').notNull().default(''),
  isAccepted: boolean('is_accepted'),
});
