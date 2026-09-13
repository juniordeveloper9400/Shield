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
});

export const updateLabBookingStatusSchema = z.object({
  status: z.enum(['REQUESTED', 'CONFIRMED', 'SAMPLE_COLLECTED', 'REPORT_READY', 'CANCELLED']),
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
export type BookAppointmentDto = z.infer<typeof bookAppointmentSchema>;
export type UpdateAppointmentStatusDto = z.infer<typeof updateAppointmentStatusSchema>;
