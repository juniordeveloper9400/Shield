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
  abhaId: z.string().default(''),
});

export const updatePatientSchema = createPatientSchema.partial();

/**
 * Registration save / profile edit. Deliberately excludes `phone`,
 * `firebaseUid`, `rewardPoints`, `referralCode`, `referredByMemberId` — none
 * of those are ever client-settable. `registrationCompletedAt` is likewise
 * never accepted from the client; the server sets it itself on first save.
 */
export const updateMemberProfileSchema = z.object({
  name: z.string().min(1).optional(),
  email: z.string().email().optional(),
  gender: z.enum(['MALE', 'FEMALE', 'OTHER']).optional(),
  dob: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'dob must be YYYY-MM-DD').optional(),
  address: z.string().optional(),
  place: z.string().optional(),
  pincode: z.string().optional(),
  state: z.string().optional(),
  homeStoreId: z.number().int().positive().optional(),
});

export type CreateAddressDto = z.infer<typeof createAddressSchema>;
export type CreatePatientDto = z.infer<typeof createPatientSchema>;
export type UpdatePatientDto = z.infer<typeof updatePatientSchema>;
export type UpdateMemberProfileDto = z.infer<typeof updateMemberProfileSchema>;
