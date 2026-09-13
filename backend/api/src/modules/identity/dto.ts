import { z } from 'zod';

export const createAddressSchema = z.object({
  label: z.enum(['HOME', 'WORK', 'OTHER']).default('HOME'),
  house: z.string().min(1),
  area: z.string().min(1),
  landmark: z.string().default(''),
  pincode: z.string().min(4).max(10),
  city: z.string().optional(),
  state: z.string().optional(),
  firstName: z.string().default(''),
  lastName: z.string().default(''),
  phone: z.string().default(''),
  patientId: z.number().int().positive().optional(),
  isDefault: z.boolean().default(false),
});

export const createPatientSchema = z.object({
  name: z.string().min(1),
  phone: z.string().default(''),
  address: z.string().default(''),
  dob: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'dob must be YYYY-MM-DD'),
  gender: z.enum(['MALE', 'FEMALE', 'OTHER']).default('OTHER'),
  relation: z.enum(['SELF', 'SPOUSE', 'CHILD', 'PARENT', 'OTHER']).default('SELF'),
});

export type CreateAddressDto = z.infer<typeof createAddressSchema>;
export type CreatePatientDto = z.infer<typeof createPatientSchema>;
