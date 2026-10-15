import { Controller, Get, Query } from '@nestjs/common';
import { AuditService } from './audit.service';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { listAuditLogQuerySchema, type ListAuditLogQuery } from './dto';

/** The Super Admin's own report: every staff login and every mutating
 *  action across the console. SUPERADMIN-only — not even ADMIN, since
 *  this is the one place an admin's own actions on *other* admins are
 *  reviewable, and an admin reviewing themselves defeats the point. */
@Controller('v1/staff/audit-log')
@RequireRole('SUPERADMIN')
export class AuditLogController {
  constructor(private readonly audit: AuditService) {}

  @Get()
  list(@Query(new ZodValidationPipe(listAuditLogQuerySchema)) query: ListAuditLogQuery) {
    return this.audit.list(query);
  }
}
