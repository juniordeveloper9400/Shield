import { Module } from '@nestjs/common';
import { WalletService } from './wallet.service';
import { RewardsService } from './rewards.service';
import { ReferralService } from './referral.service';
import { MemberWalletController } from './member-wallet.controller';
import { StaffWalletController } from './staff-wallet.controller';
import { IdempotencyService } from '../../common/idempotency/idempotency.service';

@Module({
  controllers: [MemberWalletController, StaffWalletController],
  providers: [WalletService, RewardsService, ReferralService, IdempotencyService],
})
export class WalletModule {}
