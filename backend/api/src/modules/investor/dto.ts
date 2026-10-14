import { z } from 'zod';

export const createPlanChangeRequestSchema = z.object({
  requestedPlanType: z.enum(['YEARLY', 'MONTHLY']),
  note: z.string().optional(),
});

export const resolvePlanChangeRequestSchema = z.object({
  status: z.enum(['APPROVED', 'REJECTED']),
});

/** The Users page's own "Make investor" action. See InvestorService.adminConvertToInvestor. */
export const adminConvertToInvestorSchema = z.object({
  storeCode: z.string().trim().nullable().optional(),
  totalUnits: z.number().int().nonnegative(),
  unitPrice: z.number().nonnegative(),
  roiPercent: z.number().nonnegative(),
  planType: z.enum(['YEARLY', 'MONTHLY']),
});

export type CreatePlanChangeRequestDto = z.infer<typeof createPlanChangeRequestSchema>;
export type ResolvePlanChangeRequestDto = z.infer<typeof resolvePlanChangeRequestSchema>;
export type AdminConvertToInvestorDto = z.infer<typeof adminConvertToInvestorSchema>;
