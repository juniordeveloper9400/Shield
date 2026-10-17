import { z } from 'zod';

const roleEnum = z.enum(['SUPERADMIN', 'ADMIN', 'PHARMACY', 'LAB', 'APPOINTMENTS', 'DELIVERY', 'LAB_TECHNICIAN']);

/** Mirrors shieldweb's `ModuleKey` (src/types/index.ts) / the `key` of each
 *  entry in config/permissions.ts's MODULES array — kept in sync by hand,
 *  the same way roleEnum above mirrors `Role`. See common/module-routes.ts
 *  for what each of these actually gates on the backend. */
const moduleKeyEnum = z.enum([
  'dashboard',
  'stores',
  'products',
  'banners',
  'customer_videos',
  'orders',
  'bills',
  'prescriptions',
  'activations',
  'health_passes',
  'agent_approvals',
  'agent_withdrawals',
  'agent_portal',
  'lab_orders',
  'lab_bills',
  'lab_tests',
  'appointments',
  'accounts',
  'users',
  'admins',
  'deliveries',
  'commission_reserve',
  'ledger',
  'audit_log',
]);

/** `null` (the default) means "everything the role grants" — see
 *  app-admin.ts's own doc on the column this becomes. `undefined` (the key
 *  simply omitted) leaves whatever is already on the row untouched on an
 *  update; only an explicit `null` or array value changes it. */
const modulesSchema = z.array(moduleKeyEnum).nullable().optional();

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
  modules: modulesSchema,
});

export const updateStaffSchema = z.object({
  name: z.string().min(1).optional(),
  loginId: loginIdSchema.optional(),
  /** Optional — set to change/reset the password; omit to leave it as is. */
  password: z.string().min(8, 'Password must be at least 8 characters').optional(),
  role: roleEnum.optional(),
  storeId: z.number().int().positive().nullable().optional(),
  isActive: z.boolean().optional(),
  modules: modulesSchema,
});

export type CreateStaffDto = z.infer<typeof createStaffSchema>;
export type UpdateStaffDto = z.infer<typeof updateStaffSchema>;
