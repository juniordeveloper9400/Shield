import { z } from 'zod';

const roleEnum = z.enum(['SUPERADMIN', 'ADMIN', 'PHARMACY', 'LAB', 'APPOINTMENTS']);

export const createStaffSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  role: roleEnum,
  storeId: z.number().int().positive().optional(),
});

export const updateStaffSchema = z.object({
  name: z.string().min(1).optional(),
  /** Optional — set to change/reset the password; omit to leave it as is. */
  password: z.string().min(8, 'Password must be at least 8 characters').optional(),
  role: roleEnum.optional(),
  storeId: z.number().int().positive().nullable().optional(),
  isActive: z.boolean().optional(),
});

export type CreateStaffDto = z.infer<typeof createStaffSchema>;
export type UpdateStaffDto = z.infer<typeof updateStaffSchema>;
