import { z } from 'zod';

export const verifyMsg91Schema = z.object({
  /** The widget's own JWT, from its `success` callback's `token` field —
   *  never trusted on its own; this call exists to check it server-side. */
  accessToken: z.string().min(1),
  /** Whoever this check is meant to prove holds the phone — the member's
   *  number on file, in whatever format the caller already has it in
   *  (normalised here before comparing). */
  expectedPhone: z.string().min(1),
});

export type VerifyMsg91Dto = z.infer<typeof verifyMsg91Schema>;

/** The phone to send a code to — the recruit's number on the agent
 *  registration form, not the recruiting agent's own. */
export const sendAgentOtpSchema = z.object({
  phone: z.string().min(10).max(15),
});

export type SendAgentOtpDto = z.infer<typeof sendAgentOtpSchema>;

export const verifyAgentOtpSchema = z.object({
  phone: z.string().min(10).max(15),
  code: z.string().min(4).max(6),
});

export type VerifyAgentOtpDto = z.infer<typeof verifyAgentOtpSchema>;
