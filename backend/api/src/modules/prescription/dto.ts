import { z } from 'zod';

const dataUriImage = z
  .string()
  .regex(/^data:image\/(png|jpe?g);base64,/, 'image must be a data: URI (png/jpeg)');

export const uploadPrescriptionSchema = z.object({
  patientId: z.number().int().positive(),
  // Optional — a script phoned in with no photo attached (the pharmacist
  // fills it in from the call) is a real, existing flow, not an error case.
  // Up to 3 — a script is often more than one page (front/back, or several
  // pages of a longer prescription).
  images: z.array(dataUriImage).max(3, 'Up to 3 images per prescription').optional(),
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

export const setPrescriptionImageRotationSchema = z.object({
  rotation: z.union([z.literal(0), z.literal(90), z.literal(180), z.literal(270)]),
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

/**
 * Submits one or more uploaded prescriptions for fulfilment — an unpriced
 * order shell the pharmacist prices at the counter, not a real-time
 * checkout. See `PrescriptionService.submitForOrder`.
 */
export const submitPrescriptionOrderSchema = z.object({
  prescriptionIds: z.array(z.number().int().positive()).min(1),
  addressId: z.number().int().positive().optional(),
  paymentMethodId: z.number().int().positive().optional(),
  // migration 0031: how the order reaches the member once it's priced.
  // Defaults to HOME_DELIVERY server-side (the column's own default) when
  // omitted. Never paid here either way — a prescription is priced at the
  // counter first (see `app.bill`), this only states the member's stated
  // preference up front.
  fulfillmentType: z.enum(['HOME_DELIVERY', 'STORE_PICKUP']).optional(),
});

export type UploadPrescriptionDto = z.infer<typeof uploadPrescriptionSchema>;
export type AddMedicineLineDto = z.infer<typeof addMedicineLineSchema>;
export type UpdateMedicineStatusDto = z.infer<typeof updateMedicineStatusSchema>;
export type UpdatePrescriptionStatusDto = z.infer<typeof updatePrescriptionStatusSchema>;
export type SetPrescriptionImageRotationDto = z.infer<typeof setPrescriptionImageRotationSchema>;
export type RaiseApprovalDto = z.infer<typeof raiseApprovalSchema>;
export type RespondApprovalDto = z.infer<typeof respondApprovalSchema>;
export type SubmitPrescriptionOrderDto = z.infer<typeof submitPrescriptionOrderSchema>;
