import { z } from 'zod';

const kycFields = {
  firstName: z.string().default(''),
  middleName: z.string().default(''),
  lastName: z.string().default(''),
  dob: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  aadhaar: z.string().default(''),
  pan: z.string().default(''),
  address: z.string().default(''),
  pincode: z.string().default(''),
  place: z.string().default(''),
  accountNumber: z.string().default(''),
};

export const submitAgentRequestSchema = z
  .object({
    parentAgentId: z.number().int().positive().optional(),
    // The recruit's own, already OTP-verified phone — sent only when an
    // existing agent is filling in someone *else's* KYC form (that other
    // person is the recruit, not the caller). Absent on a plain self
    // "become an agent" request — parentAgentId alone doesn't distinguish
    // the two, since a self-request can name one too — where the caller's
    // own session phone is the right answer instead. See
    // agent.service.ts's submitRequest.
    phone: z.string().optional(),
    requestedLevel: z.enum(['NATIONAL', 'REGION', 'STATE', 'DISTRICT', 'ASSEMBLY', 'LSGD', 'WARD']),
    requestedArea: z.string().default(''),
    requestedAreaId: z.string().uuid().optional(),
    ...kycFields,
  })
  .refine((v) => v.requestedLevel === 'NATIONAL' || v.requestedAreaId !== undefined, {
    message: 'requestedAreaId is required for every level except NATIONAL',
    path: ['requestedAreaId'],
  });

export const rejectAgentRequestSchema = z.object({
  note: z.string().min(1),
});

export const linkCustomerSchema = z.object({
  memberId: z.number().int().positive().optional(),
  name: z.string().min(1),
  phone: z.string().default(''),
});

export const requestWithdrawalSchema = z.object({
  amount: z.number().finite().min(3000).multipleOf(0.01),
});

export const resolveWithdrawalSchema = z.object({
  status: z.enum(['APPROVED', 'PAID', 'REJECTED']),
  accountNumber: z.string().trim().default(''),
  identityVerified: z.boolean().default(false),
  earningsVerified: z.boolean().default(false),
  note: z.string().trim().max(2000).default(''),
  paymentReference: z.string().trim().max(200).default(''),
});

export type SubmitAgentRequestDto = z.infer<typeof submitAgentRequestSchema>;
export type RejectAgentRequestDto = z.infer<typeof rejectAgentRequestSchema>;
export type LinkCustomerDto = z.infer<typeof linkCustomerSchema>;
export type RequestWithdrawalDto = z.infer<typeof requestWithdrawalSchema>;
export type ResolveWithdrawalDto = z.infer<typeof resolveWithdrawalSchema>;
