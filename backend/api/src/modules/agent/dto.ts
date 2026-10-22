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
  // The MSG91 code texted to the agent's registered phone by
  // POST agent-withdrawals/:id/otp. Required (and checked server-side) for
  // APPROVED only.
  otpCode: z.string().trim().regex(/^\d{4,6}$/, 'otpCode must be 4-6 digits').optional(),
});

export const moveEarningsToWalletSchema = z.object({
  amount: z.number().finite().positive().multipleOf(0.01),
});

/**
 * The Users page's own "Make agent" action — an admin granting the
 * persona directly to an existing member, bypassing the agent_request
 * queue entirely (unlike submitAgentRequestSchema above). See
 * AgentService.adminConvertToAgent.
 */
export const adminConvertToAgentSchema = z
  .object({
    level: z.enum(['NATIONAL', 'REGION', 'STATE', 'DISTRICT', 'ASSEMBLY', 'LSGD', 'WARD']),
    // Explicit null clears it back to the geography-derived default; an
    // admin who leaves this unset gets that same default (see
    // AgentService.deriveParentAgentId) rather than a forced top-of-tree.
    parentId: z.number().int().positive().nullable().optional(),
    area: z.string().trim().default(''),
    areaId: z.string().uuid().nullable().optional(),
  })
  .refine((v) => v.level === 'NATIONAL' || !!v.areaId, {
    message: 'areaId is required for every level except NATIONAL',
    path: ['areaId'],
  });

/**
 * The approval screen's own confirm — same level/parent/position shape as
 * adminConvertToAgentSchema, but every field optional: the reviewer may
 * confirm the request exactly as filed (send nothing here) or override
 * any of them (most often the level/position, when the recruiter picked
 * the wrong tier). See AgentService.approveRequest.
 */
export const approveAgentRequestSchema = z.object({
  level: z.enum(['NATIONAL', 'REGION', 'STATE', 'DISTRICT', 'ASSEMBLY', 'LSGD', 'WARD']).optional(),
  parentId: z.number().int().positive().nullable().optional(),
  area: z.string().trim().optional(),
  areaId: z.string().uuid().optional(),
});

/**
 * The "All agents" roster's own edit — re-assigns an already-approved
 * agent's level/parent/position under the exact same invariants approving
 * a request enforces, this agent's own current row excluded from each
 * check (confirming their existing position again must never refuse
 * itself). See AgentService.updateAgentPosition.
 */
export const updateAgentPositionSchema = z
  .object({
    level: z.enum(['NATIONAL', 'REGION', 'STATE', 'DISTRICT', 'ASSEMBLY', 'LSGD', 'WARD']),
    parentId: z.number().int().positive().nullable().optional(),
    area: z.string().trim().default(''),
    areaId: z.string().uuid().nullable().optional(),
  })
  .refine((v) => v.level === 'NATIONAL' || !!v.areaId, {
    message: 'areaId is required for every level except NATIONAL',
    path: ['areaId'],
  });

export const setAgentActiveSchema = z.object({ active: z.boolean() });

export type SubmitAgentRequestDto = z.infer<typeof submitAgentRequestSchema>;
export type RejectAgentRequestDto = z.infer<typeof rejectAgentRequestSchema>;
export type LinkCustomerDto = z.infer<typeof linkCustomerSchema>;
export type RequestWithdrawalDto = z.infer<typeof requestWithdrawalSchema>;
export type ResolveWithdrawalDto = z.infer<typeof resolveWithdrawalSchema>;
export type MoveEarningsToWalletDto = z.infer<typeof moveEarningsToWalletSchema>;
export type AdminConvertToAgentDto = z.infer<typeof adminConvertToAgentSchema>;
export type ApproveAgentRequestDto = z.infer<typeof approveAgentRequestSchema>;
export type UpdateAgentPositionDto = z.infer<typeof updateAgentPositionSchema>;
export type SetAgentActiveDto = z.infer<typeof setAgentActiveSchema>;
