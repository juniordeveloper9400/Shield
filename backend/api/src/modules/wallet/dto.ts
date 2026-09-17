import { z } from 'zod';

export const submitWalletCardSchema = z.object({
  tierId: z.number().int().positive(),
  amount: z.number().positive(),
  cardNumber: z.string().optional(),
  receiptReference: z.string().optional(),
  receiptFileName: z.string().optional(),
  receiptImage: z.string().regex(/^data:image\/(png|jpe?g);base64,/, 'receiptImage must be a data: URI (png/jpeg)').optional(),
  /**
   * The agent code a member optionally typed in at checkout ("Agent code
   * (optional)" — an agent helping them, not a requirement). Resolved to a
   * real `app.agent` row in `WalletService.submitCard`; an unknown or
   * mistyped code is never a reason to refuse the submission — a member's
   * plan purchase must not fail over someone else's typo.
   */
  agentCode: z.string().trim().optional(),
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

/** Whatever a new member typed into the "Referral ID" field at registration
 *  — see `ReferralService.applySignupCode`'s own doc for what it resolves to. */
export const applyReferralCodeSchema = z.object({
  code: z.string().trim().min(1),
});

export type SubmitWalletCardDto = z.infer<typeof submitWalletCardSchema>;
export type RejectWalletCardDto = z.infer<typeof rejectWalletCardSchema>;
export type RedeemPointsDto = z.infer<typeof redeemPointsSchema>;
export type CreateReferralDto = z.infer<typeof createReferralSchema>;
export type ApplyReferralCodeDto = z.infer<typeof applyReferralCodeSchema>;
