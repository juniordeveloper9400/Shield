import { Body, Controller, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { AdminService } from './admin.service';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { createStaffSchema, updateStaffSchema, type CreateStaffDto, type UpdateStaffDto } from './dto';

@Controller('v1/staff/admins')
@RequireRole('SUPERADMIN')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get()
  list() {
    return this.admin.listStaff();
  }

  @Post()
  create(@Body(new ZodValidationPipe(createStaffSchema)) dto: CreateStaffDto) {
    return this.admin.createStaff(dto);
  }

  @Patch(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(updateStaffSchema)) dto: UpdateStaffDto) {
    return this.admin.updateStaff(id, dto);
  }
}
