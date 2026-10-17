import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { chargePreviewSchema, labChargeSchema, type LabChargeInput } from './lab-charges.dto';
import { LabChargesService } from './lab-charges.service';

@Controller('v1/staff/lab-charges')
@RequireRole('SUPERADMIN', 'ADMIN', 'LAB')
export class StaffLabChargesController {
  constructor(private readonly charges: LabChargesService) {}
  @Get() list() { return this.charges.list(); }
  @Post() create(@Body(new ZodValidationPipe(labChargeSchema)) dto: LabChargeInput) { return this.charges.save(null, dto); }
  @Post('preview') preview(@Body(new ZodValidationPipe(chargePreviewSchema)) dto: { distanceKm: number }) {
    return this.charges.preview(dto.distanceKm);
  }
  @Patch(':id') update(@Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(labChargeSchema)) dto: LabChargeInput) { return this.charges.save(id, dto); }
  @Delete(':id') remove(@Param('id', ParseIntPipe) id: number) { return this.charges.remove(id); }
}
