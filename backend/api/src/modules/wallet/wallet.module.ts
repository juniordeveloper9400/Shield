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
  // CommerceModule's OrderService needs ReferralService too — a paid order
  // is the other place a referral's status can cross into TRANSACTED, so
  // the same referral-level points check has to run from there as well.
  exports: [ReferralService],
})
export class WalletModule {}
