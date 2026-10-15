import { Body, Controller, Get, Param, ParseIntPipe, Patch, Post, Query } from '@nestjs/common';
import { AdminService } from './admin.service';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { RequestSubject } from '../auth/session.types';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { createStaffSchema, updateStaffSchema, type CreateStaffDto, type UpdateStaffDto } from './dto';

/**
 * SUPERADMIN and ADMIN both manage staff logins now (a branch can have many
 * — one per counter/shift, not just one) — ADMIN was shut out entirely
 * before this. `createStaff`/`updateStaff` still refuse an ADMIN caller
 * anything SUPERADMIN/ADMIN-level (see AdminService's own guard): granting
 * console-wide access is still SUPERADMIN-only, only store-bound and
 * operational logins opened up.
 */
@Controller('v1/staff/admins')
@RequireRole('SUPERADMIN', 'ADMIN')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get()
  list(@Query('storeId') storeId?: string) {
    return this.admin.listStaff(storeId ? Number(storeId) : undefined);
  }

  @Post()
  create(@Body(new ZodValidationPipe(createStaffSchema)) dto: CreateStaffDto, @CurrentUser() user: RequestSubject) {
    return this.admin.createStaff(dto, user.role);
  }

  @Patch(':id')
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateStaffSchema)) dto: UpdateStaffDto,
    @CurrentUser() user: RequestSubject,
  ) {
    return this.admin.updateStaff(id, dto, user.role);
  }
}
