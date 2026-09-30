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
  addressId: z.number().int().positive().optional(),
  scheduledFor: z.string().datetime().optional(),
  /** The branch to route this booking to. Falls back to the member's own
   *  home branch when omitted — see BookingService.bookLabTest's own doc. */
  storeId: z.number().int().positive().optional(),
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

export type BookLabTestDto = z.infer<typeof bookLabTestSchema>;
export type UpdateLabBookingStatusDto = z.infer<typeof updateLabBookingStatusSchema>;
export type SendLabBillDto = z.infer<typeof sendLabBillSchema>;
export type BookAppointmentDto = z.infer<typeof bookAppointmentSchema>;
export type UpdateAppointmentStatusDto = z.infer<typeof updateAppointmentStatusSchema>;
