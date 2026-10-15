import { bigint, integer, jsonb, text, timestamp } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';

/**
 * The Super Admin's own audit trail (migration 0097) — every staff login
 * (success or failure) and every mutating staff-console request
 * (create/update/delete), who did it, when, from where, and what was sent.
 * Written by AuditInterceptor for ordinary mutations and directly by
 * AuthService.loginStaff for logins, since a login has no authenticated
 * actor yet for the interceptor to read off the request. Read by
 * AuditService.list, SUPERADMIN-only (see AuditLogController).
 *
 * staffId is ON DELETE SET NULL rather than CASCADE — a deleted staff
 * account's own history is exactly what this table exists to keep; the
 * staffLoginId/staffName/staffRole columns are a snapshot for this same
 * reason, so the log still reads sensibly once the live row is gone or
 * has since changed.
 */
export const staffAuditLog = appSchema.table('staff_audit_log', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  staffId: bigint('staff_id', { mode: 'number' }),
  staffLoginId: text('staff_login_id').notNull(),
  staffName: text('staff_name').notNull(),
  staffRole: text('staff_role').notNull(),
  storeId: bigint('store_id', { mode: 'number' }),
  // 'LOGIN' | 'LOGIN_FAILED' | 'CREATE' | 'UPDATE' | 'DELETE' — see
  // AuditInterceptor's own doc for how CREATE/UPDATE/DELETE are derived
  // from the HTTP method; path carries the specific action either way.
  action: text('action').notNull(),
  method: text('method').notNull(),
  path: text('path').notNull(),
  statusCode: integer('status_code').notNull(),
  // Redacted (AuditService.redact strips password/token-shaped fields)
  // before it ever reaches this column.
  requestBody: jsonb('request_body'),
  ip: text('ip'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});
