import { z } from 'zod';

export const submitWalletCardSchema = z.object({
  tierId: z.number().int().positive(),
  amount: z.number().positive(),
  cardNumber: z.string().optional(),
  receiptReference: z.string().optional(),
  receiptFileName: z.string().optional(),
});

export const rejectWalletCardSchema = z.object({
  note: z.string().min(1),
});

export const redeemPointsSchema = z.object({
  points: z.number().int().positive(),
});

export const createReferralSchema = z.object({
  inviteePhone: z.string().min(10).max(10),
});

export type SubmitWalletCardDto = z.infer<typeof submitWalletCardSchema>;
export type RejectWalletCardDto = z.infer<typeof rejectWalletCardSchema>;
export type RedeemPointsDto = z.infer<typeof redeemPointsSchema>;
export type CreateReferralDto = z.infer<typeof createReferralSchema>;
