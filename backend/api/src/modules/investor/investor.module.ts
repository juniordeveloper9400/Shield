import { Module } from '@nestjs/common';
import { InvestorService } from './investor.service';
import { MemberInvestorController } from './member-investor.controller';
import { StaffInvestorController } from './staff-investor.controller';

@Module({
  controllers: [MemberInvestorController, StaffInvestorController],
  providers: [InvestorService],
})
export class InvestorModule {}
