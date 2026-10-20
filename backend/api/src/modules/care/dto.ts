import { z } from 'zod';

const optionalContactPhone = z.string().trim().refine((v) => v === '' || /^\d{10}$/.test(v), 'Enter a 10-digit phone number');
const bookingPatientSchema = z
  .object({
    bookingPatientId: z.number().int().positive().optional(),
    patientId: z.number().int().positive().optional(),
    name: z.string().optional(),
    age: z.number().int().min(0).max(120).optional(),
    phone: optionalContactPhone.optional(),
    dob: z.string().refine((v) => v === '' || (/^\d{4}-\d{2}-\d{2}$/.test(v) && Number.isFinite(Date.parse(v)) && new Date(v).toISOString().slice(0, 10) === v && Date.parse(v) <= Date.now()), 'Enter a valid date of birth').optional(),
    gender: z.enum(['', 'MALE', 'FEMALE', 'OTHER']).optional(),
    relation: z.enum(['', 'SELF', 'SPOUSE', 'CHILD', 'PARENT', 'OTHER']).optional(),
    abhaId: z.string().refine((v) => v === '' || /^\d{14}$/.test(v), 'Enter a 14-digit ABHA number').optional(),
    /** This patient's own collection address — an id from the member's own
     *  saved address book. Omitted/null falls back to the booking's own
     *  address (BookingService's own doc on labBookingPatient.addressId). */
    addressId: z.number().int().positive().nullable().optional(),
    /** Admin-only free-text override for this one patient — never written
     *  back to the member's saved address book. `''`/null clears it back
     *  to addressId (or the booking's own address if that's unset too). */
    addressOverride: z.string().max(500).nullable().optional(),
  })
  .refine((v) => v.patientId !== undefined || (v.name && v.name.length > 0), {
    message: 'Each patient needs either patientId (an owned patient) or a name',
  });

export const bookLabTestSchema = z.object({
  labPackageId: z.number().int().positive(),
  patients: z.array(bookingPatientSchema).min(1),
  // Not required server-side even for home collection — the app's own
  // checkout screen already blocks placing a home-collection booking
  // without one (see LabCheckoutScreen._canPlace); the server stays as
  // permissive here as it always was for a client that doesn't.
  addressId: z.number().int().positive().optional(),
  scheduledFor: z.string().datetime().optional(),
  /** The branch to route this booking to. Falls back to the member's own
   *  home branch when omitted — see BookingService.bookLabTest's own doc. */
  storeId: z.number().int().positive().optional(),
  /** How the sample reaches the lab — defaults to the original behaviour
   *  (the lab visits the member) for a client that predates this field. */
  fulfillmentType: z.enum(['HOME_COLLECTION', 'STORE_VISIT']).default('HOME_COLLECTION'),
  /** The member tapped "Apply" on their Health Pass coupon at checkout —
   *  see app-care.ts's own doc on labBooking.healthPassApplied. */
  healthPassApplied: z.boolean().default(false),
  healthPassTier: z.string().max(100).optional(),
});

export const updateLabBookingStatusSchema = z.object({
  status: z.enum(['REQUESTED', 'CONFIRMED', 'SAMPLE_COLLECTED', 'REPORT_READY', 'CANCELLED']),
});

// Same convention as commerce's sendOrderInvoice (the *priced*-invoice path,
// not sendBillSchema's simpler photo-only one) — a data: URI photo of the
// paper invoice, optional: a lab bill is priced from the booking's own row,
// not built from a photographed script the way a prescription bill is, so
// there's often no picture at all. '' reads the same as "no image" on the
// member's own app, exactly like an empty app.bill.image already does.
// The amount itself is never client-supplied: BookingService.sendLabBill
// prices it from the booking's own unit_price × patients_count, net of this
// discount.
export const sendLabBillSchema = z.object({
  image: z.string().default(''),
  billNumber: z.string().max(100).default(''),
  discountAmount: z.number().nonnegative().default(0),
});

/** Money the counter takes against a lab bill after the wallet step — GPay
 *  and/or cash, the same shape as a standard order bill's receive. */
export const receiveLabBillPaymentSchema = z
  .object({
    cash: z.number().nonnegative().max(10000000).default(0),
    gpay: z.number().nonnegative().max(10000000).default(0),
  })
  .refine((v) => v.cash + v.gpay > 0, { message: 'Enter an amount to receive.' });

export const bookAppointmentSchema = z.object({
  kind: z.enum(['CLINIC', 'TELE', 'DENTAL', 'DIETITIAN']),
  clinicId: z.number().int().positive().optional(),
  dietitianId: z.number().int().positive().optional(),
  patientId: z.number().int().positive().optional(),
  doctorName: z.string().optional(),
  scheduledFor: z.string().datetime().optional(),
  remarks: z.string().optional(),
});

export const updateAppointmentStatusSchema = z.object({
  status: z.enum(['REQUESTED', 'CONFIRMED', 'COMPLETED', 'CANCELLED']),
});

export const createLabCategorySchema = z.object({
  name: z.string().min(1),
  image: z.string().default(''),
  sort: z.number().int().default(0),
  isActive: z.boolean().default(true),
});

export const updateLabCategorySchema = createLabCategorySchema;
export const setLabCategoryActiveSchema = z.object({ isActive: z.boolean() });
export const setLabCategorySortSchema = z.object({ sort: z.number().int() });

export const updateLabBookingDetailsSchema = z.object({
  contactName: z.string().trim().min(1).max(160).optional(),
  contactPhone: optionalContactPhone.optional(),
  addressPhone: optionalContactPhone.optional(),
  labPackageId: z.number().int().positive().optional(),
  fulfillmentType: z.enum(['HOME_COLLECTION', 'STORE_VISIT']).optional(),
  assignedStaffId: z.number().int().positive().nullable().optional(),
  unitPrice: z.number().finite().nonnegative().max(10000000).refine((v) => Math.abs(v * 100 - Math.round(v * 100)) < 0.000001, 'Use at most two decimal places').optional(),
  fixCharge: z.number().finite().nonnegative().max(10000000).refine((v) => Math.abs(v * 100 - Math.round(v * 100)) < 0.000001, 'Use at most two decimal places').optional(),
  scheduledFor: z.string().datetime().nullable(),
  note: z.string().default(''),
  /** Re-routes the booking to a different lab-eligible branch. Omitted
   *  keeps whatever branch is already on record. */
  storeId: z.number().int().positive().optional(),
  /** A free-text override of the collection address shown for this booking
   *  only — never writes back to the member's own saved address book. `''`
   *  clears it back to the member's own address (BookingService.
   *  updateLabBookingDetails's own doc). Omitted leaves it unchanged. */
  address: z.string().max(500).optional(),
  /** Replaces every patient on the booking wholesale — same shape
   *  bookLabTestSchema's own patients array accepts. Recomputes
   *  patientsCount/totalPrice from the new headcount, the same formula
   *  booking creation uses, never an admin-typed number. Omitted leaves
   *  the existing patients alone. */
  patients: z.array(bookingPatientSchema).min(1).optional(),
});

export const assignLabStaffSchema = z.object({ staffId: z.number().int().positive().nullable() });

export const addLabReportPagesSchema = z.object({
  pages: z.array(z.object({ name: z.string().default(''), image: z.string().min(1) })).min(1),
});

// ---- Test Master (app.lab_test) ------------------------------------------
// Matches shieldweb's own LabTestInput (src/types/index.ts) field for
// field — the Test Master form posts this shape directly, no reshaping.

export const labTestInputSchema = z.object({
  testType: z.enum(['TEST', 'GROUP', 'PACKAGE']),
  name: z.string().min(1),
  categoryId: z.string().default(''),
  showInApp: z.boolean().default(false),
  isMostCommon: z.boolean().default(false),
  shortName: z.string().default(''),
  calcCode: z.string().default(''),
  division: z.string().default('LAB'),
  department: z.string().default(''),
  method: z.string().default(''),
  unit: z.string().default(''),
  rate: z.number().nonnegative().default(0),
  discountPercent: z.number().min(0).max(100).default(0),
  amount: z.number().nonnegative().default(0),
  labRate: z.number().nonnegative().default(0),
  sample: z.string().default(''),
  volume: z.string().default(''),
  scheduledDays: z.string().default(''),
  cutOfTime: z.string().default(''),
  reportingTime: z.string().default(''),
  technology: z.string().default(''),
  testMode: z.string().default(''),
  reportOnValue: z.number().int().nonnegative().default(0),
  reportOnUnit: z.enum(['Minutes', 'Hours', 'Days']).default('Minutes'),
  performAt: z.string().default('In House'),
  description: z.string().optional(),
  internalNote: z.string().default(''),
  nablAccredited: z.boolean().default(false),
  sendSms: z.boolean().default(false),
  sampleTypeBarcode: z.boolean().default(false),
  freeTest: z.boolean().default(false),
  avoidIncentive: z.boolean().default(false),
  alphanumericCritical: z.boolean().default(false),
  commonTechnology: z.boolean().default(false),
  avoidResultEntry: z.boolean().default(false),
  hideHead: z.boolean().default(false),
  editTestRate: z.boolean().default(false),
  ref1: z.string().default(''),
  ref2: z.string().default(''),
  specification1: z.string().default(''),
  specification2: z.string().default(''),
  specification3: z.string().default(''),
  /** Only meaningful while testType is PACKAGE — see app-care.ts's own doc. */
  fasting: z.string().default(''),
  /** Chips for "Symptoms that may indicate this test" — see app-care.ts's own doc. */
  symptoms: z.array(z.string()).default([]),
  resultTemplate: z.string().default(''),
  isActive: z.boolean().default(true),
});

const labGroupItemSchema = z.object({
  testId: z.string().min(1),
  name: z.string().default(''),
  department: z.string().default(''),
  sample: z.string().default(''),
  amount: z.number().nonnegative().default(0),
  setOrder: z.number().int().default(0),
  isSubhead: z.boolean().default(false),
});

const labSpecialRateSchema = z.object({
  refLab: z.string().min(1),
  rate: z.number().nonnegative().default(0),
});

export const saveLabTestSchema = z.object({
  input: labTestInputSchema,
  groupItems: z.array(labGroupItemSchema).default([]),
  specialRates: z.array(labSpecialRateSchema).default([]),
});

// ---- Lab test field options (app.lab_test_field_option) -------------------

/** Which {@link labTestInputSchema} free-text field a pick-list entry is
 *  for — matches `LabTestService.FIELD_KEYS` and shieldweb's own
 *  `LabTestFieldKey` one for one. */
export const LAB_TEST_FIELD_KEYS = [
  'department',
  'method',
  'sample',
  'volume',
  'scheduledDays',
  'cutOfTime',
  'reportingTime',
  'technology',
  'testMode',
  'performAt',
] as const;
export const labTestFieldKeySchema = z.enum(LAB_TEST_FIELD_KEYS);

export const createLabTestFieldOptionSchema = z.object({
  fieldKey: labTestFieldKeySchema,
  value: z.string().trim().min(1),
});
export const updateLabTestFieldOptionSchema = z.object({
  value: z.string().trim().min(1),
});

// ---- Lab Packages (app.lab_package, staff-built) --------------------------

export const setLabPackageActiveSchema = z.object({ isActive: z.boolean() });
export const updateLabPackagePriceSchema = z.object({
  price: z.number().nonnegative(),
  mrp: z.number().nonnegative(),
});

const labPackageInputSchema = z.object({
  name: z.string().min(1),
  categoryId: z.string().default(''),
  price: z.number().nonnegative(),
  mrp: z.number().nonnegative(),
  forWhom: z.string().default(''),
  sample: z.string().default(''),
  preparation: z.string().default(''),
  fasting: z.string().default(''),
  reportIn: z.string().default(''),
  about: z.string().default(''),
  testIds: z.array(z.string()).default([]),
});

export const createLabPackageSchema = labPackageInputSchema;
export const updateLabPackageBuildSchema = z.object({
  input: labPackageInputSchema,
  testsChanged: z.boolean().default(false),
});

export type BookLabTestDto = z.infer<typeof bookLabTestSchema>;
export type UpdateLabBookingStatusDto = z.infer<typeof updateLabBookingStatusSchema>;
export type SendLabBillDto = z.infer<typeof sendLabBillSchema>;
export type ReceiveLabBillPaymentDto = z.infer<typeof receiveLabBillPaymentSchema>;
export type BookAppointmentDto = z.infer<typeof bookAppointmentSchema>;
export type UpdateAppointmentStatusDto = z.infer<typeof updateAppointmentStatusSchema>;
export type CreateLabCategoryDto = z.infer<typeof createLabCategorySchema>;
export type UpdateLabCategoryDto = z.infer<typeof updateLabCategorySchema>;
export type SetLabCategoryActiveDto = z.infer<typeof setLabCategoryActiveSchema>;
export type SetLabCategorySortDto = z.infer<typeof setLabCategorySortSchema>;
export type UpdateLabBookingDetailsDto = z.infer<typeof updateLabBookingDetailsSchema>;
export type AssignLabStaffDto = z.infer<typeof assignLabStaffSchema>;
export type AddLabReportPagesDto = z.infer<typeof addLabReportPagesSchema>;
export type LabTestInputDto = z.infer<typeof labTestInputSchema>;
export type LabTestFieldKey = z.infer<typeof labTestFieldKeySchema>;
export type CreateLabTestFieldOptionDto = z.infer<typeof createLabTestFieldOptionSchema>;
export type UpdateLabTestFieldOptionDto = z.infer<typeof updateLabTestFieldOptionSchema>;
export type SaveLabTestDto = z.infer<typeof saveLabTestSchema>;
export type SetLabPackageActiveDto = z.infer<typeof setLabPackageActiveSchema>;
export type UpdateLabPackagePriceDto = z.infer<typeof updateLabPackagePriceSchema>;
export type CreateLabPackageDto = z.infer<typeof createLabPackageSchema>;
export type UpdateLabPackageBuildDto = z.infer<typeof updateLabPackageBuildSchema>;
