import { Body, Controller, Get, Post } from '@nestjs/common';
import { InvestorService } from './investor.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireMember } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { createPlanChangeRequestSchema, type CreatePlanChangeRequestDto } from './dto';
import type { RequestSubject } from '../auth/session.types';

@Controller('v1/investor')
@RequireMember()
export class MemberInvestorController {
  constructor(private readonly investors: InvestorService) {}

  @Get('me')
  getProfile(@CurrentUser() user: RequestSubject) {
    return this.investors.getOwnProfile(Number(user.subjectId));
  }

  @Post('plan-change-requests')
  requestPlanChange(
    @CurrentUser() user: RequestSubject,
    @Body(new ZodValidationPipe(createPlanChangeRequestSchema)) dto: CreatePlanChangeRequestDto,
  ) {
    return this.investors.requestPlanChange(Number(user.subjectId), dto);
  }

  @Get('plan-change-requests')
  listPlanChangeRequests(@CurrentUser() user: RequestSubject) {
    return this.investors.listOwnPlanChangeRequests(Number(user.subjectId));
  }
}
