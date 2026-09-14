import { z } from 'zod';

export const uploadPrescriptionSchema = z.object({
  patientId: z.number().int().positive(),
  // Optional — a script phoned in with no photo attached (the pharmacist
  // fills it in from the call) is a real, existing flow, not an error case.
  image: z.string().regex(/^data:image\/(png|jpe?g);base64,/, 'image must be a data: URI (png/jpeg)').optional(),
  fileName: z.string().default(''),
  doctor: z.string().default(''),
  duration: z.enum(['ONE_WEEK', 'FIFTEEN_DAYS', 'ONE_MONTH', 'TWO_MONTHS', 'THREE_MONTHS']).optional(),
  customDays: z.number().int().positive().optional(),
  recurringFrom: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  recurringUntil: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

export const addMedicineLineSchema = z.object({
  name: z.string().min(1),
  pack: z.string().default(''),
  doseMorning: z.number().int().min(0).default(0),
  doseAfternoon: z.number().int().min(0).default(0),
  doseNight: z.number().int().min(0).default(0),
  totalUnits: z.number().int().min(0).default(0),
  routeTime: z.string().default(''),
  productId: z.number().int().positive().optional(),
});

export const updateMedicineStatusSchema = z.object({
  status: z.enum(['AVAILABLE', 'OUT_OF_STOCK', 'NOT_POSSIBLE', 'ORDERED']),
});

export const updatePrescriptionStatusSchema = z.object({
  status: z.enum(['AWAITING_REVIEW', 'READ', 'IN_CART', 'ORDERED']),
});

export const raiseApprovalSchema = z.object({
  prescriptionId: z.number().int().positive(),
  pharmacistNote: z.string().default(''),
  items: z
    .array(
      z.object({
        name: z.string().min(1),
        pack: z.string().default(''),
        quantity: z.number().int().min(1).default(1),
        price: z.number().nonnegative().default(0),
        note: z.string().default(''),
      }),
    )
    .min(1),
});

export const respondApprovalSchema = z.object({
  items: z
    .array(
      z.object({
        approvalItemId: z.number().int().positive(),
        isAccepted: z.boolean(),
      }),
    )
    .min(1),
});

export type UploadPrescriptionDto = z.infer<typeof uploadPrescriptionSchema>;
export type AddMedicineLineDto = z.infer<typeof addMedicineLineSchema>;
export type UpdateMedicineStatusDto = z.infer<typeof updateMedicineStatusSchema>;
export type UpdatePrescriptionStatusDto = z.infer<typeof updatePrescriptionStatusSchema>;
export type RaiseApprovalDto = z.infer<typeof raiseApprovalSchema>;
export type RespondApprovalDto = z.infer<typeof respondApprovalSchema>;
