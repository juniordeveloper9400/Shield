import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import type { Request } from 'express';
import { Observable } from 'rxjs';
import { catchError, tap } from 'rxjs/operators';
import { AuditService } from './audit.service';
import type { RequestSubject } from '../auth/session.types';

const MUTATING_METHODS = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

/**
 * The generic half of the audit trail (see app-audit.ts's own doc) —
 * every mutating /v1/staff/* request, logged after the fact with
 * whichever actor AuthGuard already resolved onto the request. Deliberately
 * skips /v1/staff/auth/* (a login has no authenticated actor yet for this
 * to read off the request — AuthService.loginStaff logs that side itself)
 * and every GET (reads aren't audited).
 *
 * Registered globally (APP_INTERCEPTOR, see audit.module.ts) rather than
 * per-controller, so a new staff route is covered automatically — nobody
 * has to remember to wire this up by hand for the next module.
 */
@Injectable()
export class AuditInterceptor implements NestInterceptor {
  constructor(private readonly audit: AuditService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') return next.handle();

    const request = context.switchToHttp().getRequest<Request & { user?: RequestSubject }>();
    const path: string = request.path ?? request.url ?? '';
    const method = request.method;

    if (!path.startsWith('/v1/staff') || path.startsWith('/v1/staff/auth') || !MUTATING_METHODS.has(method)) {
      return next.handle();
    }

    const user = request.user;
    if (!user || user.subjectType !== 'STAFF') return next.handle();

    const staffId = Number(user.subjectId);
    const role = user.role ?? '';
    const storeId = user.storeId ?? null;
    const ip = request.ip ?? null;
    const requestBody = request.body;

    const write = (statusCode: number) => {
      void this.audit.recordStaffRequest({ staffId, role, storeId, method, path, statusCode, requestBody, ip });
    };

    return next.handle().pipe(
      tap({ next: () => write(context.switchToHttp().getResponse().statusCode ?? 200) }),
      catchError((err: unknown) => {
        const status = (err as { status?: number; getStatus?: () => number })?.getStatus?.() ?? (err as { status?: number })?.status ?? 500;
        write(status);
        throw err;
      }),
    );
  }
}
