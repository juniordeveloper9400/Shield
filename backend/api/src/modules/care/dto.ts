import { z } from 'zod';

const bookingPatientSchema = z
  .object({
    patientId: z.number().int().positive().optional(),
    name: z.string().optional(),
    age: z.number().int().positive().optional(),
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
  discountAmount: z.number().nonnegative().default(0),
});

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
export type SaveLabTestDto = z.infer<typeof saveLabTestSchema>;
export type SetLabPackageActiveDto = z.infer<typeof setLabPackageActiveSchema>;
export type UpdateLabPackagePriceDto = z.infer<typeof updateLabPackagePriceSchema>;
export type CreateLabPackageDto = z.infer<typeof createLabPackageSchema>;
export type UpdateLabPackageBuildDto = z.infer<typeof updateLabPackageBuildSchema>;
