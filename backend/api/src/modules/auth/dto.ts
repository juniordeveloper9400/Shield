import { z } from 'zod';

export const idTokenSchema = z.object({
  idToken: z.string().min(10, 'idToken looks too short to be valid'),
});

/** Staff login — see auth.service.ts loginStaff. A short handle, not an email. */
export const staffLoginSchema = z.object({
  loginId: z.string().min(1),
  password: z.string().min(1),
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(10, 'refreshToken looks too short to be valid'),
});

export type IdTokenDto = z.infer<typeof idTokenSchema>;
export type StaffLoginDto = z.infer<typeof staffLoginSchema>;
export type RefreshTokenDto = z.infer<typeof refreshTokenSchema>;
