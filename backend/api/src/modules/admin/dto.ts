import { z } from 'zod';

const roleEnum = z.enum(['SUPERADMIN', 'PHARMACY', 'LAB', 'APPOINTMENTS']);

export const createStaffSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
  role: roleEnum,
  storeId: z.number().int().positive().optional(),
});

export const updateStaffSchema = z.object({
  name: z.string().min(1).optional(),
  role: roleEnum.optional(),
  storeId: z.number().int().positive().nullable().optional(),
  isActive: z.boolean().optional(),
});

export type CreateStaffDto = z.infer<typeof createStaffSchema>;
export type UpdateStaffDto = z.infer<typeof updateStaffSchema>;
