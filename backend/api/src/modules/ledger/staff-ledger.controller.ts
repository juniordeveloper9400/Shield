import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { LedgerService } from './ledger.service';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { RequestSubject } from '../auth/session.types';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { closePeriodSchema, type ClosePeriodDto } from './dto';

/**
 * SUPERADMIN and ADMIN — raw accounting data, so held to the same bar as
 * activation review (see StaffWalletController's own comment). Closing a
 * period is SUPERADMIN only; it blocks every future posting into that
 * entity's month, so a store-bound or operational role must not do it.
 */
@Controller('v1/staff/ledger')
@RequireRole('SUPERADMIN', 'ADMIN')
export class StaffLedgerController {
  constructor(private readonly ledger: LedgerService) {}

  @Get('entities')
  listEntities() {
    return this.ledger.listEntities();
  }

  @Get('trial-balance')
  trialBalance(
    @Query('entityId') entityId?: string,
    @Query('period') period?: string,
    @Query('type') type?: string,
  ) {
    return this.ledger.trialBalance({
      entityId: entityId ? Number(entityId) : undefined,
      period,
      type,
    });
  }

  @Get('periods')
  listPeriods(@Query('entityId') entityId?: string) {
    return this.ledger.listPeriods(entityId ? Number(entityId) : undefined);
  }

  @Get('agent-commissions')
  agentCommissions(@Query('walletCardId') walletCardId?: string, @Query('agentId') agentId?: string) {
    return this.ledger.agentCommissions({
      walletCardId: walletCardId ? Number(walletCardId) : undefined,
      agentId: agentId ? Number(agentId) : undefined,
    });
  }

  @RequireRole('SUPERADMIN')
  @Post('entities/:entityId/periods/close')
  closePeriod(
    @Param('entityId') entityId: string,
    @Body(new ZodValidationPipe(closePeriodSchema)) dto: ClosePeriodDto,
    @CurrentUser() user: RequestSubject,
  ) {
    return this.ledger.closePeriod(Number(entityId), dto.period, String(user.subjectId));
  }
}
