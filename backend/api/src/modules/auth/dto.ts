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

/** 10-digit Indian mobile — the shared shape every MSG91-backed member-auth
 *  route below validates its [phone] against. */
const indianPhone = z.string().regex(/^[6-9]\d{9}$/, 'phone must be a 10-digit Indian mobile number');

/** Sends the member-login OTP — see auth.service.ts sendMemberOtp. */
export const sendMemberOtpSchema = z.object({
  phone: indianPhone,
});

/** Member sign-in: the phone already has an app.users row — see
 *  auth.service.ts exchangeMemberPhone. */
export const verifyMemberOtpSchema = z.object({
  phone: indianPhone,
  code: z.string().min(4).max(6),
});

/** Member self-registration by phone — see auth.service.ts
 *  registerMemberByPhone. */
export const registerMemberOtpSchema = z.object({
  phone: indianPhone,
  code: z.string().min(4).max(6),
  name: z.string().min(1),
});

export type IdTokenDto = z.infer<typeof idTokenSchema>;
export type RegisterMemberDto = z.infer<typeof registerMemberSchema>;
export type StaffLoginDto = z.infer<typeof staffLoginSchema>;
export type RefreshTokenDto = z.infer<typeof refreshTokenSchema>;
export type PhoneLookupDto = z.infer<typeof phoneLookupSchema>;
export type SendMemberOtpDto = z.infer<typeof sendMemberOtpSchema>;
export type VerifyMemberOtpDto = z.infer<typeof verifyMemberOtpSchema>;
export type RegisterMemberOtpDto = z.infer<typeof registerMemberOtpSchema>;
