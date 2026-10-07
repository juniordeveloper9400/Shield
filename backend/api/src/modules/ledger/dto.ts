import { z } from 'zod';

/** 'YYYY-MM-01' — the first day of the calendar month a period covers. */
export const closePeriodSchema = z.object({
  period: z.string().regex(/^\d{4}-\d{2}-01$/, 'period must be the first day of a month, e.g. 2026-10-01'),
});

export type ClosePeriodDto = z.infer<typeof closePeriodSchema>;
