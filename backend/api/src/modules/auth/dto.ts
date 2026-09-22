import { z } from 'zod';

export const idTokenSchema = z.object({
  idToken: z.string().min(10, 'idToken looks too short to be valid'),
});

/** Member self-registration — see auth.service.ts registerMember. */
export const registerMemberSchema = z.object({
  idToken: z.string().min(10, 'idToken looks too short to be valid'),
  name: z.string().min(1),
});

/** Staff login — see auth.service.ts loginStaff. A short handle, not an email. */
export const staffLoginSchema = z.object({
  loginId: z.string().min(1),
  password: z.string().min(1),
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(10, 'refreshToken looks too short to be valid'),
});

/**
 * Pre-verification "does this number already have an account" check — see
 * member-auth.controller.ts's own doc on why this route exists at all and
 * why it's throttled the same as the token-exchange routes.
 */
export const phoneLookupSchema = z.object({
  phone: z.string().regex(/^[6-9]\d{9}$/, 'phone must be a 10-digit Indian mobile number'),
});

export type IdTokenDto = z.infer<typeof idTokenSchema>;
export type RegisterMemberDto = z.infer<typeof registerMemberSchema>;
export type StaffLoginDto = z.infer<typeof staffLoginSchema>;
export type RefreshTokenDto = z.infer<typeof refreshTokenSchema>;
export type PhoneLookupDto = z.infer<typeof phoneLookupSchema>;
