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
  amount: z.number().positive(),
});

export const resolveWithdrawalSchema = z.object({
  status: z.enum(['PAID', 'REJECTED']),
});

export type SubmitAgentRequestDto = z.infer<typeof submitAgentRequestSchema>;
export type RejectAgentRequestDto = z.infer<typeof rejectAgentRequestSchema>;
export type LinkCustomerDto = z.infer<typeof linkCustomerSchema>;
export type RequestWithdrawalDto = z.infer<typeof requestWithdrawalSchema>;
export type ResolveWithdrawalDto = z.infer<typeof resolveWithdrawalSchema>;
