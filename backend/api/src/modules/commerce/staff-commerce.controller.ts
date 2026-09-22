import { Body, Controller, Get, Param, ParseIntPipe, Patch, Put } from '@nestjs/common';
import { OrderService } from './order.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequireRole, RequireStaff } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { sendBillSchema, updateOrderStatusSchema, type SendBillDto, type UpdateOrderStatusDto } from './dto';
import type { RequestSubject } from '../auth/session.types';

/** Store-scoped for every role except SUPERADMIN — see order.service.ts. */
@Controller('v1/staff')
@RequireStaff()
export class StaffCommerceController {
  constructor(private readonly orders: OrderService) {}

  @Get('orders')
  list(@CurrentUser() user: RequestSubject) {
    return this.orders.listForStaff(user.role!, user.storeId ?? null);
  }

  @Patch('orders/:id/status')
  updateStatus(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(updateOrderStatusSchema)) dto: UpdateOrderStatusDto,
  ) {
    return this.orders.updateStatus(user.role!, user.storeId ?? null, id, dto);
  }

  @Put('orders/:id/bill')
  sendBill(
    @CurrentUser() user: RequestSubject,
    @Param('id', ParseIntPipe) id: number,
    @Body(new ZodValidationPipe(sendBillSchema)) dto: SendBillDto,
  ) {
    return this.orders.sendBill(user.role!, user.storeId ?? null, id, dto);
  }

  /**
   * Narrower than the rest of this controller — matches exactly who has the
   * 'bills'/'orders' module in shieldweb/src/config/permissions.ts
   * (superadmin/admin get every module, pharmacy is explicitly listed too;
   * lab/appointments/delivery are not), not the class-wide @RequireStaff().
   */
  @RequireRole('SUPERADMIN', 'ADMIN', 'PHARMACY')
  @Patch('orders/:id/collect-wallet')
  collectWithWallet(@CurrentUser() user: RequestSubject, @Param('id', ParseIntPipe) id: number) {
    return this.orders.collectBillWithWallet(user.role!, user.storeId ?? null, id);
  }
}
