import { Body, Controller, Get, Param, ParseIntPipe, Post } from '@nestjs/common';
import { AgentService } from './agent.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { RequestSubject } from '../auth/session.types';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  rejectAgentRequestSchema,
  resolveWithdrawalSchema,
  type RejectAgentRequestDto,
  type ResolveWithdrawalDto,
} from './dto';

/**
 * SUPERADMIN and ADMIN — matching shieldweb's canApproveAgents()
 * (shieldweb/src/config/permissions.ts: "for the app managers — Super
 * Admin and Admin") AND its ROLE_PERMISSIONS, where 'agent_approvals' isn't
 * in the pharmacy/lab/appointments module lists at all — those roles never
 * see this screen, not even read-only. Class-wide is deliberate here.
 */
@Controller('v1/staff')
@RequireRole('SUPERADMIN', 'ADMIN')
export class StaffAgentController {
  constructor(private readonly agents: AgentService) {}

  @Get('agent-requests')
  listPending() {
    return this.agents.listPendingRequests();
  }

  @Post('agent-requests/:id/approve')
  approve(@Param('id', ParseIntPipe) id: number) {
    return this.agents.approveRequest(id);
  }

  @Post('agent-requests/:id/reject')
  reject(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(rejectAgentRequestSchema)) dto: RejectAgentRequestDto) {
    return this.agents.rejectRequest(id, dto);
  }

  @Get('agent-withdrawals')
  listWithdrawals() {
    return this.agents.listWithdrawalsForStaff();
  }

  @Post('agent-withdrawals/:id/resolve')
  resolveWithdrawal(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(resolveWithdrawalSchema)) dto: ResolveWithdrawalDto,
  ) {
    return this.agents.resolveWithdrawal(id, dto, String(user.subjectId));
  }
}
