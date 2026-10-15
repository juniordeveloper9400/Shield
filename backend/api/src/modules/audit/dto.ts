import { z } from 'zod';

export const listAuditLogQuerySchema = z.object({
  staffId: z.coerce.number().int().positive().optional(),
  action: z.enum(['LOGIN', 'LOGIN_FAILED', 'CREATE', 'UPDATE', 'DELETE']).optional(),
  // Plain YYYY-MM-DD — compared against created_at's own date, inclusive on
  // both ends, same convention the console's other date-range filters use.
  from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  to: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  // Matches staffName/staffLoginId/path — the report's own free-text search box.
  q: z.string().trim().optional(),
  cursor: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().min(1).max(200).default(50),
});

export type ListAuditLogQuery = z.infer<typeof listAuditLogQuerySchema>;
