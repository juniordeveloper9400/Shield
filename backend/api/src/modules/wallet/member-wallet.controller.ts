import { Body, Controller, Get, Post } from '@nestjs/common';
import { WalletService } from './wallet.service';
import { RewardsService } from './rewards.service';
import { ReferralService } from './referral.service';
import { IdempotencyService } from '../../common/idempotency/idempotency.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IdempotencyKey } from '../../common/decorators/idempotency-key.decorator';
import { RequireMember } from '../../common/decorators/require-role.decorator';
import { FinancialThrottle } from '../../common/throttle';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  createReferralSchema,
  redeemPointsSchema,
  submitWalletCardSchema,
  type CreateReferralDto,
  type RedeemPointsDto,
  type SubmitWalletCardDto,
} from './dto';
import type { RequestSubject } from '../auth/session.types';

@Controller('v1/member')
@RequireMember()
export class MemberWalletController {
  constructor(
    private readonly wallet: WalletService,
    private readonly rewards: RewardsService,
    private readonly referrals: ReferralService,
    private readonly idempotency: IdempotencyService,
  ) {}

  @Get('wallet')
  getWallet(@CurrentUser() user: RequestSubject) {
    return this.wallet.getOrCreateWallet(Number(user.subjectId));
  }

  @Get('wallet/entries')
  listEntries(@CurrentUser() user: RequestSubject) {
    return this.wallet.listEntries(Number(user.subjectId));
  }

  @FinancialThrottle()
  @Post('wallet/cards')
  submitCard(
    @CurrentUser() user: RequestSubject,
    @Body(new ZodValidationPipe(submitWalletCardSchema)) dto: SubmitWalletCardDto,
  ) {
    return this.wallet.submitCard(Number(user.subjectId), dto);
  }

  @Get('wallet/cards')
  listCards(@CurrentUser() user: RequestSubject) {
    return this.wallet.listCardsForMember(Number(user.subjectId));
  }

  @Get('rewards/transactions')
  listRewardTransactions(@CurrentUser() user: RequestSubject) {
    return this.rewards.listTransactions(Number(user.subjectId));
  }

  /** Idempotent — a retried redeem never double-credits. See rewards.service.ts. */
  @FinancialThrottle()
  @Post('rewards/redeem')
  redeem(
    @CurrentUser() user: RequestSubject,
    @IdempotencyKey() key: string,
    @Body(new ZodValidationPipe(redeemPointsSchema)) dto: RedeemPointsDto,
  ) {
    return this.idempotency.run(user.sessionId, 'POST /v1/member/rewards/redeem', key, () =>
      this.rewards.redeem(Number(user.subjectId), dto),
    );
  }

  @Get('referrals')
  listReferrals(@CurrentUser() user: RequestSubject) {
    return this.referrals.listForMember(Number(user.subjectId));
  }

  @Post('referrals')
  createReferral(
    @CurrentUser() user: RequestSubject,
    @Body(new ZodValidationPipe(createReferralSchema)) dto: CreateReferralDto,
  ) {
    return this.referrals.create(Number(user.subjectId), dto);
  }
}
