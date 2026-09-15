import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { CartService } from './cart.service';
import { OrderService } from './order.service';
import { IdempotencyService } from '../../common/idempotency/idempotency.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { IdempotencyKey } from '../../common/decorators/idempotency-key.decorator';
import { RequireMember } from '../../common/decorators/require-role.decorator';
import { FinancialThrottle } from '../../common/throttle';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import {
  addCartLineSchema,
  checkoutSchema,
  submitOrderReceiptSchema,
  updateCartLineSchema,
  type AddCartLineDto,
  type CheckoutDto,
  type SubmitOrderReceiptDto,
  type UpdateCartLineDto,
} from './dto';
import type { RequestSubject } from '../auth/session.types';

@Controller('v1/member')
@RequireMember()
export class MemberCommerceController {
  constructor(
    private readonly cart: CartService,
    private readonly orders: OrderService,
    private readonly idempotency: IdempotencyService,
  ) {}

  @Get('cart')
  getCart(@CurrentUser() user: RequestSubject) {
    return this.cart.getCart(Number(user.subjectId));
  }

  @Post('cart/lines')
  addLine(@CurrentUser() user: RequestSubject, @Body(new ZodValidationPipe(addCartLineSchema)) dto: AddCartLineDto) {
    return this.cart.addLine(Number(user.subjectId), dto);
  }

  @Patch('cart/lines/:id')
  updateLine(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateCartLineSchema)) dto: UpdateCartLineDto,
  ) {
    return this.cart.updateLineQty(Number(user.subjectId), id, dto);
  }

  @Delete('cart/lines/:id')
  removeLine(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.cart.removeLine(Number(user.subjectId), id);
  }

  /** Idempotent — a retried checkout with the same Idempotency-Key never creates a second order. */
  @FinancialThrottle()
  @Post('orders')
  checkout(
    @CurrentUser() user: RequestSubject,
    @IdempotencyKey() key: string,
    @Body(new ZodValidationPipe(checkoutSchema)) dto: CheckoutDto,
  ) {
    return this.idempotency.run(user.sessionId, 'POST /v1/member/orders', key, () =>
      this.orders.checkout(Number(user.subjectId), dto),
    );
  }

  @Get('orders')
  listOrders(@CurrentUser() user: RequestSubject) {
    return this.orders.listForMember(Number(user.subjectId));
  }

  @Get('orders/:id')
  getOrder(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.orders.getForMember(Number(user.subjectId), id);
  }

  @Get('orders/:id/bill')
  getBill(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.orders.getBillForMember(Number(user.subjectId), id);
  }

  @Post('orders/:id/receipt')
  submitReceipt(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(submitOrderReceiptSchema)) dto: SubmitOrderReceiptDto,
  ) {
    return this.orders.submitReceipt(Number(user.subjectId), id, dto);
  }

  // A priced bill is no longer settled by the member tapping "Pay now"
  // themselves — a member-triggered POST /v1/member/orders/:id/pay route
  // used to sit here and call OrderService.payBillWithWallet directly. Now
  // staff collect a bill off the wallet from the admin console only, gated
  // on an OTP the member reads out at hand-off (shieldweb's
  // src/api/billPayments.ts) — a route a member's own session could call at
  // will defeated that gate entirely, so it's gone rather than left dead and
  // reachable. See order.service.ts's debitWalletForOrder doc.
}
