import { sql } from 'drizzle-orm';
import { bigint, boolean, integer, numeric, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';
import { memberAddress, patient } from './app-identity';
import { orderPaymentStatusEnum } from './app-commerce';

/**
 * Typed READ/WRITE MIRROR of care-service tables owned by
 * backend/db/app_schema.sql — see backend/docs/erd.md §2. Neither
 * lab_booking nor appointment carries a store_id in the live schema — this
 * module has no branch scoping to enforce, unlike commerce/prescription.
 */
export const appointmentKindEnum = appSchema.enum('appointment_kind', ['CLINIC', 'TELE', 'DENTAL', 'DIETITIAN']);
export const appointmentStatusEnum = appSchema.enum('appointment_status', [
  'REQUESTED',
  'CONFIRMED',
  'COMPLETED',
  'CANCELLED',
]);
export const labBookingStatusEnum = appSchema.enum('lab_booking_status', [
  'REQUESTED',
  'CONFIRMED',
  'SAMPLE_COLLECTED',
  'REPORT_READY',
  'CANCELLED',
]);
/** migration 0094 — how the member's sample reaches the lab: the lab visits
 *  them, or they visit the branch. Defaults HOME_COLLECTION, matching every
 *  booking made before this existed. */
export const labBookingFulfillmentEnum = appSchema.enum('lab_booking_fulfillment', [
  'HOME_COLLECTION',
  'STORE_VISIT',
]);

/**
 * "Explore by health concern" — a member-browsable category (migration
 * 0055), managed on the console's Lab Tests → Categories tab. `image` is an
 * uploaded data URI, the same shape as `app.product_category.image`.
 */
export const labCategory = appSchema.table('lab_category', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  name: text('name').notNull(),
  image: text('image'),
  sort: integer('sort').notNull().default(0),
  isActive: boolean('is_active').notNull().default(true),
});

export const labPackage = appSchema.table('lab_package', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  slug: text('slug').notNull(),
  name: text('name').notNull(),
  /** Migration 0055 — which "Explore by health concern" tile this sits under. */
  categoryId: bigint('category_id', { mode: 'number' }),
  /** Migration 0056 — set on the one-profile listing the console keeps for a
   *  test / group test switched on with "Show in the app" (what the apps show
   *  under "Top Profiles and Tests"); null on a real package. */
  sourceTestId: bigint('source_test_id', { mode: 'number' }),
  testCount: integer('test_count').notNull().default(0),
  profileCount: integer('profile_count').notNull().default(0),
  rating: text('rating'),
  booked: text('booked'),
  reportIn: text('report_in'),
  price: numeric('price', { precision: 12, scale: 2 }).notNull().default('0'),
  mrp: numeric('mrp', { precision: 12, scale: 2 }).notNull().default('0'),
  saved: numeric('saved', { precision: 12, scale: 2 }).notNull().default('0'),
  inheritsFrom: text('inherits_from'),
  inheritsSummary: text('inherits_summary'),
  extrasLabel: text('extras_label'),
  forWhom: text('for_whom'),
  ageRange: text('age_range'),
  preparation: text('preparation'),
  sample: text('sample'),
  organs: text('organs').array().notNull().default([]),
  about: text('about').notNull().default(''),
  isActive: boolean('is_active').notNull().default(true),
  sort: integer('sort').notNull().default(0),
  /** Migration 0068 — the Test Master's "Most Common Test" switch, mirrored
   *  onto this listing by `syncLabTestListing` the same way `sourceTestId`'s
   *  other copied fields are. Leads the apps' "Most Common Tests" banner;
   *  staff-curated rather than guessed from [sort]. */
  isMostCommon: boolean('is_most_common').notNull().default(false),
});

/**
 * Migration 0067 — any number of ADDITIONAL categories a package also shows
 * under, on top of its one primary {@link labPackage.categoryId}. A test that
 * genuinely belongs under more than one "Explore by health concern" tile
 * (FSH/LH/SHBG under both Men health and women health, say) keeps its
 * primary category unchanged and gets a row here per extra tile instead.
 */
export const labPackageExtraCategory = appSchema.table(
  'lab_package_extra_category',
  {
    packageId: bigint('package_id', { mode: 'number' }).notNull(),
    categoryId: bigint('category_id', { mode: 'number' }).notNull(),
  },
);

export const labProfile = appSchema.table('lab_profile', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  labPackageId: bigint('lab_package_id', { mode: 'number' }).notNull(),
  emoji: text('emoji').notNull().default(''),
  name: text('name').notNull(),
  parameters: integer('parameters').notNull().default(0),
  isExtra: boolean('is_extra').notNull().default(false),
  sort: integer('sort').notNull().default(0),
});

/**
 * Migration 0046 — the Test Master's own record: a single Test, a Group
 * Test (one row per real test it's made of, in {@link labTestGroupItem}),
 * or a Package (same shape as {@link labPackage} below, pre-Test-Master).
 * `test_type`/`source`/`report_on_unit` are plain `text` with a CHECK
 * constraint at the DB level, not a real Postgres enum — mirrored here the
 * same way. `is_most_common` added by migration 0068.
 */
export const labTest = appSchema.table('lab_test', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  // Hands out from app.lab_test_lis_code_seq (migration 0046) — never set
  // explicitly on insert.
  lisCode: integer('lis_code').notNull().default(sql`nextval('app.lab_test_lis_code_seq')`),
  testType: text('test_type').notNull().default('TEST'), // 'TEST' | 'GROUP' | 'PACKAGE'
  name: text('name').notNull(),
  shortName: text('short_name').notNull().default(''),
  calcCode: text('calc_code').notNull().default(''),
  division: text('division').notNull().default('LAB'),
  department: text('department').notNull().default(''),
  method: text('method').notNull().default(''),
  unit: text('unit').notNull().default(''),
  rate: numeric('rate', { precision: 12, scale: 2 }).notNull().default('0'),
  discountPercent: numeric('discount_percent', { precision: 5, scale: 2 }).notNull().default('0'),
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull().default('0'),
  sample: text('sample').notNull().default(''),
  volume: text('volume').notNull().default(''),
  cutOfTime: text('cut_of_time').notNull().default(''),
  technology: text('technology').notNull().default(''),
  testMode: text('test_mode').notNull().default(''),
  reportOnValue: integer('report_on_value').notNull().default(0),
  reportOnUnit: text('report_on_unit').notNull().default('Minutes'), // 'Minutes' | 'Hours' | 'Days'
  performAt: text('perform_at').notNull().default('In House'),
  internalNote: text('internal_note').notNull().default(''),
  nablAccredited: boolean('nabl_accredited').notNull().default(false),
  sendSms: boolean('send_sms').notNull().default(false),
  sampleTypeBarcode: boolean('sample_type_barcode').notNull().default(false),
  freeTest: boolean('free_test').notNull().default(false),
  avoidIncentive: boolean('avoid_incentive').notNull().default(false),
  alphanumericCritical: boolean('alphanumeric_critical').notNull().default(false),
  commonTechnology: boolean('common_technology').notNull().default(false),
  avoidResultEntry: boolean('avoid_result_entry').notNull().default(false),
  hideHead: boolean('hide_head').notNull().default(false),
  editTestRate: boolean('edit_test_rate').notNull().default(false),
  ref1: text('ref1').notNull().default(''),
  ref2: text('ref2').notNull().default(''),
  specification1: text('specification_1').notNull().default(''),
  specification2: text('specification_2').notNull().default(''),
  specification3: text('specification_3').notNull().default(''),
  resultTemplate: text('result_template').notNull().default(''),
  isActive: boolean('is_active').notNull().default(true),
  createdBy: text('created_by').notNull().default(''),
  updatedBy: text('updated_by').notNull().default(''),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  scheduledDays: text('scheduled_days').notNull().default(''),
  reportingTime: text('reporting_time').notNull().default(''),
  labRate: numeric('lab_rate', { precision: 12, scale: 2 }).notNull().default('0'),
  source: text('source').notNull().default('ADMIN'), // 'ADMIN' | 'RATE_LIST'
  categoryId: bigint('category_id', { mode: 'number' }),
  showInApp: boolean('show_in_app').notNull().default(false),
  isMostCommon: boolean('is_most_common').notNull().default(false),
});

/** Migration 0046 — one real test inside a GROUP-type {@link labTest}. */
export const labTestGroupItem = appSchema.table('lab_test_group_item', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  groupId: bigint('group_id', { mode: 'number' }).notNull(),
  testId: bigint('test_id', { mode: 'number' }).notNull(),
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull().default('0'),
  setOrder: integer('set_order').notNull().default(0),
  isSubhead: boolean('is_subhead').notNull().default(false),
});

/** Migration 0046 — a reference lab's own rate for one test, on the
 *  "Special Rates" tab. */
export const labTestSpecialRate = appSchema.table('lab_test_special_rate', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  testId: bigint('test_id', { mode: 'number' }).notNull(),
  refLab: text('ref_lab').notNull(),
  rate: numeric('rate', { precision: 12, scale: 2 }).notNull().default('0'),
});

/** Migration 0055 — the real {@link labTest} rows a member-bookable
 *  {@link labPackage} is built from (the package builder's own picker). */
export const labPackageTestItem = appSchema.table('lab_package_test_item', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  packageId: bigint('package_id', { mode: 'number' }).notNull(),
  testId: bigint('test_id', { mode: 'number' }).notNull(),
  sort: integer('sort').notNull().default(0),
});

export const clinic = appSchema.table('clinic', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  name: text('name').notNull(),
  type: text('type'),
  location: text('location'),
  phone: text('phone'),
  description: text('description').notNull().default(''),
  isVerified: boolean('is_verified').notNull().default(false),
  specialities: text('specialities').array().notNull().default([]),
  isActive: boolean('is_active').notNull().default(true),
  sort: integer('sort').notNull().default(0),
});

export const clinicDoctor = appSchema.table('clinic_doctor', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  clinicId: bigint('clinic_id', { mode: 'number' }).notNull(),
  name: text('name').notNull(),
  speciality: text('speciality'),
  fee: text('fee'),
  sort: integer('sort').notNull().default(0),
});

export const dietitian = appSchema.table('dietitian', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  name: text('name').notNull(),
  qualification: text('qualification'),
  focus: text('focus').array().notNull().default([]),
  experienceYears: integer('experience_years').notNull().default(0),
  languages: text('languages').array().notNull().default([]),
  fee: numeric('fee', { precision: 12, scale: 2 }).notNull().default('0'),
  nextSlot: text('next_slot'),
  isActive: boolean('is_active').notNull().default(true),
  sort: integer('sort').notNull().default(0),
});

export const labBooking = appSchema.table('lab_booking', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  memberId: bigint('member_id', { mode: 'number' }).notNull(),
  labPackageId: bigint('lab_package_id', { mode: 'number' }).notNull(),
  patientsCount: integer('patients_count').notNull().default(1),
  unitPrice: numeric('unit_price', { precision: 12, scale: 2 }).notNull().default('0'),
  totalPrice: numeric('total_price', { precision: 12, scale: 2 }).notNull().default('0'),
  status: labBookingStatusEnum('status').notNull().default('REQUESTED'),
  /** migration 0094 — see labBookingFulfillmentEnum's own doc. */
  fulfillmentType: labBookingFulfillmentEnum('fulfillment_type').notNull().default('HOME_COLLECTION'),
  scheduledFor: timestamp('scheduled_for', { withTimezone: true }),
  addressId: bigint('address_id', { mode: 'number' }).references(() => memberAddress.id),
  /** Which branch this booking is routed to (migration 0057) — defaults to
   *  the member's own home branch, changeable at checkout to any branch with
   *  `offersLabCollection`. Null for a booking made before this existed, or
   *  whose branch has since been removed. */
  storeId: bigint('store_id', { mode: 'number' }),
  /** migration 0095 — who collects this booking's sample. Only meaningful
   *  for a HOME_COLLECTION booking; see BookingService.updateLabBookingStatus's
   *  own STAFF_REQUIRED gate. References app.admin_user(id). */
  assignedStaffId: bigint('assigned_staff_id', { mode: 'number' }),
  /** migration 0095 — an admin's free-text override of the collection
   *  address for this booking only. Never written back to the member's own
   *  saved `member_address` row; `''`/null falls back to that row's own
   *  formatted address. */
  addressOverride: text('address_override'),
  /** A line from the lab to the member (migration 0052). */
  note: text('note'),
  /** When the report was last attached (migration 0052). */
  reportUploadedAt: timestamp('report_uploaded_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const labBookingPatient = appSchema.table('lab_booking_patient', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  labBookingId: bigint('lab_booking_id', { mode: 'number' }).notNull(),
  patientId: bigint('patient_id', { mode: 'number' }).references(() => patient.id),
  name: text('name'),
  age: integer('age'),
});

/** One page of a booking's lab report — a resized JPEG data URI (migration 0052). */
export const labBookingReport = appSchema.table('lab_booking_report', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  labBookingId: bigint('lab_booking_id', { mode: 'number' }).notNull(),
  name: text('name').notNull().default(''),
  image: text('image').notNull(),
  sort: integer('sort').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

/**
 * A lab booking's own bill (migration 0066) — same shape as
 * app.bill/app.bill_line, its own table rather than widening that one's
 * order_id (NOT NULL UNIQUE, every existing read/write path assumes an
 * order) into something polymorphic. One row per booking (labBookingId is
 * UNIQUE); status reuses orderPaymentStatusEnum, which already means
 * exactly PENDING/PAID here too.
 */
export const labBill = appSchema.table('lab_bill', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  labBookingId: bigint('lab_booking_id', { mode: 'number' }).notNull(),
  image: text('image').notNull(),
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull().default('0'),
  discountAmount: numeric('discount_amount', { precision: 12, scale: 2 }).notNull().default('0'),
  status: orderPaymentStatusEnum('status').notNull().default('PENDING'),
  paidAt: timestamp('paid_at', { withTimezone: true }),
  walletCollected: numeric('wallet_collected', { precision: 12, scale: 2 }).notNull().default('0'),
  cashCollected: numeric('cash_collected', { precision: 12, scale: 2 }).notNull().default('0'),
  sentAt: timestamp('sent_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

/** Auto-filled from the booking's own package/unit price at send time — see
 *  app.lab_bill's own doc on why this isn't a staff-typed line-item table
 *  the way app.bill_line is. */
export const labBillLine = appSchema.table('lab_bill_line', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  labBillId: bigint('lab_bill_id', { mode: 'number' }).notNull(),
  name: text('name').notNull(),
  pack: text('pack').notNull().default(''),
  unitPrice: numeric('unit_price', { precision: 12, scale: 2 }).notNull().default('0'),
  qty: integer('qty').notNull().default(1),
});

export const appointment = appSchema.table('appointment', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  memberId: bigint('member_id', { mode: 'number' }).notNull(),
  kind: appointmentKindEnum('kind').notNull().default('CLINIC'),
  clinicId: bigint('clinic_id', { mode: 'number' }).references(() => clinic.id),
  dietitianId: bigint('dietitian_id', { mode: 'number' }).references(() => dietitian.id),
  patientId: bigint('patient_id', { mode: 'number' }).references(() => patient.id),
  doctorName: text('doctor_name'),
  fee: numeric('fee', { precision: 12, scale: 2 }),
  status: appointmentStatusEnum('status').notNull().default('REQUESTED'),
  scheduledFor: timestamp('scheduled_for', { withTimezone: true }),
  remarks: text('remarks'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
