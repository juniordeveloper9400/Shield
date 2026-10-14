import { Body, Controller, Delete, Get, HttpCode, Param, ParseIntPipe, Patch, Post, Query } from '@nestjs/common';
import { IdentityService } from './identity.service';
import { AgentService } from '../agent/agent.service';
import { InvestorService } from '../investor/investor.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireRole, RequireStaff } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { adminConvertToAgentSchema, type AdminConvertToAgentDto } from '../agent/dto';
import { adminConvertToInvestorSchema, type AdminConvertToInvestorDto } from '../investor/dto';
import {
  createPatientSchema,
  updateMemberContactSchema,
  type CreatePatientDto,
  type UpdateMemberContactDto,
} from './dto';
import type { RequestSubject } from '../auth/session.types';

@Controller('v1/staff')
@RequireStaff()
export class StaffController {
  constructor(
    private readonly identity: IdentityService,
    private readonly agents: AgentService,
    private readonly investors: InvestorService,
  ) {}

  @Get('me')
  async me(@CurrentUser() user: RequestSubject) {
    return this.identity.getStaffProfile(Number(user.subjectId));
  }

  // ---- Users page ---------------------------------------------------------
  // 'users' in shieldweb/src/config/permissions.ts is superadmin/admin/
  // pharmacy — matched here for the plain reads/contact-fix below. Granting
  // or revoking a persona is tightened to SUPERADMIN/ADMIN only (each
  // route below overrides individually), the same boundary
  // permanentlyDeleteMember already draws for the one other irreversible
  // action on this page.

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Get('users')
  listUsers(@Query('storeCode') storeCode?: string) {
    return this.identity.listUsersForStaff(storeCode);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Get('users/:id')
  getUser(@Param('id', ParseIntPipe) id: number) {
    return this.identity.getUserForStaff(id);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Get('users/:id/detail')
  getUserDetail(@Param('id', ParseIntPipe) id: number) {
    return this.identity.getUserDetailForStaff(id);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Patch('users/:id/contact')
  async updateContact(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateMemberContactSchema)) dto: UpdateMemberContactDto,
  ) {
    const changed = await this.identity.updateMemberContactForStaff(id, dto);
    return { changed };
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Get('users/:id/patients')
  listPatients(@Param('id', ParseIntPipe) id: number) {
    return this.identity.listPatients(id);
  }

  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Post('users/:id/patients')
  createPatient(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(createPatientSchema)) dto: CreatePatientDto,
  ) {
    return this.identity.createPatient(id, dto);
  }

  /** Grants the agent persona directly — see AgentService.adminConvertToAgent
   *  for the invariants this enforces, including the 409 it throws when the
   *  member already has a persona. */
  @RequireRole('SUPERADMIN', 'ADMIN')
  @Post('users/:id/convert-to-agent')
  convertToAgent(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(adminConvertToAgentSchema)) dto: AdminConvertToAgentDto,
  ) {
    return this.agents.adminConvertToAgent(id, dto);
  }

  @RequireRole('SUPERADMIN', 'ADMIN')
  @Post('users/:id/convert-to-investor')
  convertToInvestor(
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(adminConvertToInvestorSchema)) dto: AdminConvertToInvestorDto,
  ) {
    return this.investors.adminConvertToInvestor(id, dto);
  }

  /** Drops the member back to a plain member — removes whichever of
   *  app.agent / app.investor they hold. Never both at once in practice,
   *  but harmless to clear either unconditionally, same as the direct-SQL
   *  version this replaces. */
  @RequireRole('SUPERADMIN', 'ADMIN')
  @Delete('users/:id/persona')
  @HttpCode(204)
  async revokePersona(@Param('id', ParseIntPipe) id: number) {
    await this.agents.adminRevokeAgent(id);
    await this.investors.adminRevokeInvestor(id);
  }

  @Delete('users/:id')
  @HttpCode(204)
  @RequireRole('SUPERADMIN', 'ADMIN')
  async permanentlyDeleteMember(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: RequestSubject,
  ) {
    await this.identity.permanentlyDeleteMember(id, user.sessionId);
  }
}
