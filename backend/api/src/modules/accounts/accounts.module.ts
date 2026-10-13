import { Module } from '@nestjs/common';
import { AccountsService } from './accounts.service';
import { StaffAccountsController } from './staff-accounts.controller';

@Module({
  controllers: [StaffAccountsController],
  providers: [AccountsService],
})
export class AccountsModule {}
