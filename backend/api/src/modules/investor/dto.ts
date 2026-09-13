import { z } from 'zod';

export const createPlanChangeRequestSchema = z.object({
  requestedPlanType: z.enum(['YEARLY', 'MONTHLY']),
  note: z.string().optional(),
});

export const resolvePlanChangeRequestSchema = z.object({
  status: z.enum(['APPROVED', 'REJECTED']),
});

export type CreatePlanChangeRequestDto = z.infer<typeof createPlanChangeRequestSchema>;
export type ResolvePlanChangeRequestDto = z.infer<typeof resolvePlanChangeRequestSchema>;
