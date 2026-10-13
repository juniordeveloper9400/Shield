import { Controller, Get, Param, ParseIntPipe, Query } from '@nestjs/common';
import { AccountsService } from './accounts.service';
import { RequireRole } from '../../common/decorators/require-role.decorator';

/**
 * Read-only money-flow reporting for the console's Accounts page —
 * SUPERADMIN and ADMIN only, matching shieldweb's own `ROLE_PERMISSIONS`
 * (the 'accounts' module key is in `APP_MODULES`, which only those two
 * roles get — see `shieldweb/src/config/permissions.ts`), the same bar as
 * StaffLedgerController.
 */
@Controller('v1/staff/accounts')
@RequireRole('SUPERADMIN', 'ADMIN')
export class StaffAccountsController {
  constructor(private readonly accounts: AccountsService) {}

  @Get('money-flow-summary')
  moneyFlowSummary() {
    return this.accounts.getMoneyFlowSummary();
  }

  @Get('money-flow-entries')
  moneyFlowEntries(@Query('limit') limit?: string) {
    return this.accounts.listMoneyFlowEntries(limit ? Number(limit) : undefined);
  }

  @Get('member-transactions/:memberId')
  memberTransactions(@Param('memberId', ParseIntPipe) memberId: number, @Query('limit') limit?: string) {
    return this.accounts.listMemberTransactions(memberId, limit ? Number(limit) : undefined);
  }

  @Get('monthly-money-flow')
  monthlyMoneyFlow(@Query('months') months?: string) {
    return this.accounts.getMonthlyMoneyFlow(months ? Number(months) : undefined);
  }

  @Get('member-summaries')
  memberSummaries() {
    return this.accounts.listMemberMoneyFlowSummaries();
  }
}
