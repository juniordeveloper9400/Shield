import { z } from 'zod';

const roleEnum = z.enum(['SUPERADMIN', 'ADMIN', 'PHARMACY', 'LAB', 'APPOINTMENTS', 'DELIVERY']);

/** A short handle, e.g. 'pharmacy_mel' — not an email. */
const loginIdSchema = z
  .string()
  .min(3, 'Login id must be at least 3 characters')
  .max(64)
  .regex(/^[a-zA-Z0-9_.@-]+$/, 'Login id can only contain letters, numbers, "_", ".", "@" and "-"');

export const createStaffSchema = z.object({
  loginId: loginIdSchema,
  name: z.string().min(1),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  role: roleEnum,
  storeId: z.number().int().positive().optional(),
});

export const updateStaffSchema = z.object({
  name: z.string().min(1).optional(),
  loginId: loginIdSchema.optional(),
  /** Optional — set to change/reset the password; omit to leave it as is. */
  password: z.string().min(8, 'Password must be at least 8 characters').optional(),
  role: roleEnum.optional(),
  storeId: z.number().int().positive().nullable().optional(),
  isActive: z.boolean().optional(),
});

export type CreateStaffDto = z.infer<typeof createStaffSchema>;
export type UpdateStaffDto = z.infer<typeof updateStaffSchema>;
