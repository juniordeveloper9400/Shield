import { Body, Controller, Get, Param, ParseIntPipe, Patch } from '@nestjs/common';
import { WalletService } from './wallet.service';
import { RequireRole } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { rejectWalletCardSchema, type RejectWalletCardDto } from './dto';

/**
 * SUPERADMIN and ADMIN — matches shieldweb's canReviewActivations()
 * ("for the app managers — Super Admin and Admin") and its
 * ROLE_PERMISSIONS, where 'activations' isn't in the pharmacy/lab/
 * appointments module lists at all. A pharmacy/lab role must not be able
 * to approve wallet top-ups — matches the live schema's own comment on
 * app.wallet_card: "a Super Admin in the console approves it ... or
 * rejects it", broadened the same way canReviewActivations() already is.
 */
@Controller('v1/staff/wallet-cards')
@RequireRole('SUPERADMIN', 'ADMIN')
export class StaffWalletController {
  constructor(private readonly wallet: WalletService) {}

  @Get()
  listPending() {
    return this.wallet.listPendingCards();
  }

  @Patch(':id/approve')
  approve(@Param('id', ParseIntPipe) id: number) {
    return this.wallet.approveCard(id);
  }

  @Patch(':id/reject')
  reject(@Param('id', ParseIntPipe) id: number, @Body(new ZodValidationPipe(rejectWalletCardSchema)) dto: RejectWalletCardDto) {
    return this.wallet.rejectCard(id, dto.note);
  }

  /**
   * SUPERADMIN only, narrower than the rest of this controller — company
   * money, not something an ADMIN role reviewing activations needs to see.
   * See `commissionReserveEntry`'s own doc for what this actually is.
   */
  @Get('reserve')
  @RequireRole('SUPERADMIN')
  reserve() {
    return this.wallet.getCommissionReserve();
  }
}
