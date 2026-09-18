import { bigint, boolean, integer, numeric, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';
import { memberAddress, patient } from './app-identity';

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

export const labPackage = appSchema.table('lab_package', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  slug: text('slug').notNull(),
  name: text('name').notNull(),
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
});

export const labProfile = appSchema.table('lab_profile', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  labPackageId: bigint('lab_package_id', { mode: 'number' }).notNull(),
  emoji: text('emoji').notNull().default(''),
  name: text('name').notNull(),
  parameters: integer('parameters').notNull().default(0),
  isExtra: boolean('is_extra').notNull().default(false),
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
  scheduledFor: timestamp('scheduled_for', { withTimezone: true }),
  addressId: bigint('address_id', { mode: 'number' }).references(() => memberAddress.id),
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
