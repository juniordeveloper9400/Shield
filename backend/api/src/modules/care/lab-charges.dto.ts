import { z } from 'zod';

const money = z.number().finite().min(0).max(1000000).multipleOf(0.01);
const common = { name: z.string().trim().min(1).max(120), isActive: z.boolean().default(true) };
export const labChargeSchema = z.discriminatedUnion('kind', [
  z.object({ ...common, kind: z.literal('TECHNICIAN'), amount: money }),
  z.object({ ...common, kind: z.literal('KM'), distanceKm: z.number().finite().positive().max(10000) }),
  z.object({ ...common, kind: z.literal('DISTANCE'), firstKm: z.number().positive().max(10000),
    firstAmount: money, secondKm: z.number().positive().max(10000), secondAmount: money, extraPerKm: money }),
]).refine(v => v.kind !== 'DISTANCE' || (v.secondKm > v.firstKm && v.secondAmount >= v.firstAmount),
  'Distance thresholds must increase and charges must not decrease');
export type LabChargeInput = z.infer<typeof labChargeSchema>;
export const chargePreviewSchema = z.object({ distanceKm: z.number().finite().min(0).max(10000) });
