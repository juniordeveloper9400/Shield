import { Body, Controller, Get, Post } from '@nestjs/common';
import { AgentService } from './agent.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireMember } from '../../common/decorators/require-role.decorator';
import { FinancialThrottle } from '../../common/throttle';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  linkCustomerSchema,
  requestWithdrawalSchema,
  submitAgentRequestSchema,
  type LinkCustomerDto,
  type RequestWithdrawalDto,
  type SubmitAgentRequestDto,
} from './dto';
import type { RequestSubject } from '../auth/session.types';

@Controller('v1/agent')
@RequireMember()
export class MemberAgentController {
  constructor(private readonly agents: AgentService) {}

  @Post('requests')
  submitRequest(
    @CurrentUser() user: RequestSubject,
    @Body(new ZodValidationPipe(submitAgentRequestSchema)) dto: SubmitAgentRequestDto,
  ) {
    return this.agents.submitRequest(Number(user.subjectId), dto);
  }

  @Get('requests')
  listOwnRequests(@CurrentUser() user: RequestSubject) {
    return this.agents.listOwnRequests(Number(user.subjectId));
  }

  @Get('team')
  getTeam(@CurrentUser() user: RequestSubject) {
    return this.agents.getTeamForMember(Number(user.subjectId));
  }

  @Post('customers')
  linkCustomer(@CurrentUser() user: RequestSubject, @Body(new ZodValidationPipe(linkCustomerSchema)) dto: LinkCustomerDto) {
    return this.agents.linkCustomer(Number(user.subjectId), dto);
  }

  @Get('customers')
  listCustomers(@CurrentUser() user: RequestSubject) {
    return this.agents.listCustomers(Number(user.subjectId));
  }

  @FinancialThrottle()
  @Post('withdrawals')
  requestWithdrawal(
    @CurrentUser() user: RequestSubject,
    @Body(new ZodValidationPipe(requestWithdrawalSchema)) dto: RequestWithdrawalDto,
  ) {
    return this.agents.requestWithdrawal(Number(user.subjectId), dto);
  }
}
