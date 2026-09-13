import { z } from 'zod';

export const idTokenSchema = z.object({
  idToken: z.string().min(10, 'idToken looks too short to be valid'),
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(10, 'refreshToken looks too short to be valid'),
});

export type IdTokenDto = z.infer<typeof idTokenSchema>;
export type RefreshTokenDto = z.infer<typeof refreshTokenSchema>;
