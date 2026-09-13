import { Body, Controller, Get, Param, ParseIntPipe, Post } from '@nestjs/common';
import { InvestorService } from './investor.service';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { resolvePlanChangeRequestSchema, type ResolvePlanChangeRequestDto } from './dto';

@Controller('v1/staff/investor-plan-change-requests')
@RequireRole('SUPERADMIN')
export class StaffInvestorController {
  constructor(private readonly investors: InvestorService) {}

  @Get()
  listPending() {
    return this.investors.listPendingPlanChangeRequests();
  }

  @Post(':id/resolve')
  resolve(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(resolvePlanChangeRequestSchema)) dto: ResolvePlanChangeRequestDto,
  ) {
    return this.investors.resolvePlanChangeRequest(id, dto);
  }
}
