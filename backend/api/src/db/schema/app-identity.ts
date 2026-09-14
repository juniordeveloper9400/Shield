import { bigint, boolean, date, integer, pgSchema, text, timestamp, uuid } from 'drizzle-orm/pg-core';

/**
 * Typed READ/WRITE MIRROR of tables owned by backend/db/app_schema.sql.
 * This file is not the source of truth for the DDL — it must be kept in
 * sync by hand whenever that file changes. See backend/docs/erd.md §2.
 *
 * Only the columns this service's identity/auth module actually needs are
 * mirrored here; add columns as later modules need them rather than
 * speculatively mirroring the whole table up front.
 */
export const appSchema = pgSchema('app');

export const genderEnum = appSchema.enum('gender', ['MALE', 'FEMALE', 'OTHER']);
export const addressLabelEnum = appSchema.enum('address_label', ['HOME', 'WORK', 'OTHER']);
export const patientRelationEnum = appSchema.enum('patient_relation', [
  'SELF',
  'SPOUSE',
  'CHILD',
  'PARENT',
  'OTHER',
]);

export const users = appSchema.table('users', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  phone: text('phone').notNull(),
  name: text('name').notNull(),
  firebaseUid: text('firebase_uid'),
  email: text('email'),
  gender: genderEnum('gender'),
  dob: date('dob'),
  homeStoreId: bigint('home_store_id', { mode: 'number' }),
  rewardPoints: integer('reward_points').notNull().default(0),
  registrationCompletedAt: timestamp('registration_completed_at', { withTimezone: true }),
  lastLoginAt: timestamp('last_login_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  deletedAt: timestamp('deleted_at', { withTimezone: true }),
});

export const memberAddress = appSchema.table('member_address', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  memberId: bigint('member_id', { mode: 'number' }).notNull(),
  label: addressLabelEnum('label').notNull().default('HOME'),
  house: text('house').notNull(),
  area: text('area').notNull(),
  landmark: text('landmark').notNull().default(''),
  pincode: text('pincode').notNull(),
  city: text('city'),
  state: text('state'),
  firstName: text('first_name').notNull().default(''),
  lastName: text('last_name').notNull().default(''),
  phone: text('phone').notNull().default(''),
  patientId: bigint('patient_id', { mode: 'number' }),
  isDefault: boolean('is_default').notNull().default(false),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  deletedAt: timestamp('deleted_at', { withTimezone: true }),
});

export const patient = appSchema.table('patient', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  memberId: bigint('member_id', { mode: 'number' }).notNull(),
  name: text('name').notNull(),
  phone: text('phone').notNull().default(''),
  address: text('address').notNull().default(''),
  dob: date('dob').notNull(),
  gender: genderEnum('gender').notNull().default('OTHER'),
  relation: patientRelationEnum('relation').notNull().default('SELF'),
  // Real column in the live schema (app_schema.sql), missing from this
  // mirror until now — same known drift as other tables here.
  abhaId: text('abha_id').notNull().default(''),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  deletedAt: timestamp('deleted_at', { withTimezone: true }),
});
