import { Inject, Injectable, Logger } from '@nestjs/common';
import { and, desc, eq, gte, ilike, lt, lte, or } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { adminUser, staffAuditLog } from '../../db/schema';
import type { ListAuditLogQuery } from './dto';

export type AuditAction = 'LOGIN' | 'LOGIN_FAILED' | 'CREATE' | 'UPDATE' | 'DELETE';

export interface AuditEntryInput {
  staffId: number | null;
  staffLoginId: string;
  staffName: string;
  staffRole: string;
  storeId: number | null;
  action: AuditAction;
  method: string;
  path: string;
  statusCode: number;
  requestBody?: unknown;
  ip?: string | null;
}

/** Keys redacted wherever they appear in a logged request body, however
 *  deep — matched case-insensitively against the bare key name, not the
 *  full path, since a credential field is a credential field regardless
 *  of which object it's nested in. */
const REDACT_KEYS = new Set(['password', 'passwordhash', 'otpidtoken', 'token', 'accesstoken', 'refreshtoken']);

/**
 * The Super Admin's own audit trail — see app-audit.ts's own doc on the
 * table this writes/reads. Writes come from two places: AuditInterceptor
 * (every mutating /v1/staff/* request, generically) and AuthService.
 * loginStaff (both successful and failed sign-ins, which the interceptor
 * can't cover itself — there's no authenticated actor yet to read off the
 * request at that point).
 */
@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  private redact(value: unknown): unknown {
    if (Array.isArray(value)) return value.map((v) => this.redact(v));
    if (value && typeof value === 'object') {
      const out: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
        out[k] = REDACT_KEYS.has(k.toLowerCase()) ? '[redacted]' : this.redact(v);
      }
      return out;
    }
    return value;
  }

  /**
   * Fire-and-forget by design — not awaited by any caller. A logging
   * failure must never fail, or even slow down, the real staff action it
   * is trying to record.
   */
  record(entry: AuditEntryInput): void {
    void this.db
      .insert(staffAuditLog)
      .values({
        staffId: entry.staffId,
        staffLoginId: entry.staffLoginId,
        staffName: entry.staffName,
        staffRole: entry.staffRole,
        storeId: entry.storeId,
        action: entry.action,
        method: entry.method,
        path: entry.path,
        statusCode: entry.statusCode,
        requestBody: entry.requestBody !== undefined ? this.redact(entry.requestBody) : null,
        ip: entry.ip ?? null,
      })
      .catch((err: unknown) => this.logger.error('Failed to write audit log entry', err as Error));
  }

  /**
   * The generic half of the trail — AuditInterceptor calls this for every
   * mutating /v1/staff/* request, with only what AuthGuard's own JWT
   * claims carry (staffId/role/storeId, no name or login id). The one
   * extra lookup resolves those for the snapshot columns; this whole
   * method is itself fired-and-forgotten by the interceptor, so the
   * lookup never adds latency to the real request.
   */
  async recordStaffRequest(params: {
    staffId: number;
    role: string;
    storeId: number | null;
    method: string;
    path: string;
    statusCode: number;
    requestBody: unknown;
    ip: string | null;
  }): Promise<void> {
    const [staff] = await this.db.select({ loginId: adminUser.loginId, name: adminUser.name }).from(adminUser).where(eq(adminUser.id, params.staffId)).limit(1);
    this.record({
      staffId: params.staffId,
      staffLoginId: staff?.loginId ?? '(unknown)',
      staffName: staff?.name ?? '(unknown)',
      staffRole: params.role,
      storeId: params.storeId,
      action: params.method === 'DELETE' ? 'DELETE' : params.method === 'POST' ? 'CREATE' : 'UPDATE',
      method: params.method,
      path: params.path,
      statusCode: params.statusCode,
      requestBody: params.requestBody,
      ip: params.ip,
    });
  }

  /** Newest first, cursor-paginated on id (stable even for two rows with
   *  the same created_at). SUPERADMIN-only — see AuditLogController. */
  async list(query: ListAuditLogQuery) {
    const conditions = [];
    if (query.staffId !== undefined) conditions.push(eq(staffAuditLog.staffId, query.staffId));
    if (query.action !== undefined) conditions.push(eq(staffAuditLog.action, query.action));
    if (query.from !== undefined) conditions.push(gte(staffAuditLog.createdAt, new Date(`${query.from}T00:00:00.000Z`)));
    if (query.to !== undefined) conditions.push(lte(staffAuditLog.createdAt, new Date(`${query.to}T23:59:59.999Z`)));
    if (query.q) {
      const like = `%${query.q}%`;
      conditions.push(or(ilike(staffAuditLog.staffName, like), ilike(staffAuditLog.staffLoginId, like), ilike(staffAuditLog.path, like)));
    }
    if (query.cursor !== undefined) conditions.push(lt(staffAuditLog.id, query.cursor));

    const rows = await this.db
      .select()
      .from(staffAuditLog)
      .where(conditions.length > 0 ? and(...conditions) : undefined)
      .orderBy(desc(staffAuditLog.id))
      .limit(query.limit);

    return { items: rows, nextCursor: rows.length === query.limit ? rows[rows.length - 1].id : null };
  }
}
