import { Body, Controller, Get, HttpCode, HttpStatus, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { AgentService } from './agent.service';
import { AuthThrottle } from '../../common/throttle';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { RequestSubject } from '../auth/session.types';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  approveAgentRequestSchema,
  rejectAgentRequestSchema,
  resolveWithdrawalSchema,
  setAgentActiveSchema,
  updateAgentPositionSchema,
  type ApproveAgentRequestDto,
  type RejectAgentRequestDto,
  type ResolveWithdrawalDto,
  type SetAgentActiveDto,
  type UpdateAgentPositionDto,
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

  @Get('agent-requests/:id')
  getPending(@Param('id', ParseIntPipe) id: number) {
    return this.agents.getPendingRequest(id);
  }

  /** Approved agents only, for the "parent" picker on both the
   *  agent_request KYC form and the Users page's direct-convert form. */
  @Get('agent-options')
  listAgentOptions() {
    return this.agents.listApprovedAgentOptions();
  }

  @Post('agent-requests/:id/approve')
  approve(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(approveAgentRequestSchema)) dto: ApproveAgentRequestDto,
  ) {
    return this.agents.approveRequest(id, dto);
  }

  @Post('agent-requests/:id/reject')
  reject(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(rejectAgentRequestSchema)) dto: RejectAgentRequestDto) {
    return this.agents.rejectRequest(id, dto);
  }

  // ---- The live roster ("All agents") ------------------------------------

  @Get('agents')
  listApproved() {
    return this.agents.listApprovedAgents();
  }

  @Get('agents/:id')
  getApproved(@Param('id', ParseIntPipe) id: number) {
    return this.agents.getApprovedAgent(id);
  }

  @Patch('agents/:id/position')
  updatePosition(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateAgentPositionSchema)) dto: UpdateAgentPositionDto,
  ) {
    return this.agents.updateAgentPosition(id, dto);
  }

  @Patch('agents/:id/active')
  setActive(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(setAgentActiveSchema)) dto: SetAgentActiveDto) {
    return this.agents.setAgentActive(id, dto);
  }

  /** This agent's own direct customers and activated plans — the Agent
   *  Portal's money-flow view, same shape the agent's own app shows. */
  @Get('agents/:id/customers')
  listCustomers(@Param('id', ParseIntPipe) id: number) {
    return this.agents.listCustomersForAgent(id);
  }

  /** This agent's own withdrawal history. */
  @Get('agents/:id/withdrawals')
  listAgentWithdrawals(@Param('id', ParseIntPipe) id: number) {
    return this.agents.listWithdrawalsForAgent(id);
  }

  @Get('agent-withdrawals')
  listWithdrawals() {
    return this.agents.listWithdrawalsForStaff();
  }

  /** Texts the approval OTP to the agent's registered phone. */
  @AuthThrottle()
  @HttpCode(HttpStatus.OK)
  @Post('agent-withdrawals/:id/otp')
  sendWithdrawalOtp(@Param('id', ParseIntPipe) id: number) {
    return this.agents.sendApprovalOtp(id);
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
