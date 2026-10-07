import { Module } from '@nestjs/common';
import { LedgerService } from './ledger.service';
import { StaffLedgerController } from './staff-ledger.controller';

@Module({
  controllers: [StaffLedgerController],
  providers: [LedgerService],
})
export class LedgerModule {}
