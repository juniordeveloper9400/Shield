import { Module } from '@nestjs/common';
import { CartService } from './cart.service';
import { OrderService } from './order.service';
import { MemberCommerceController } from './member-commerce.controller';
import { StaffCommerceController } from './staff-commerce.controller';
import { IdempotencyService } from '../../common/idempotency/idempotency.service';

@Module({
  controllers: [MemberCommerceController, StaffCommerceController],
  providers: [CartService, OrderService, IdempotencyService],
})
export class CommerceModule {}
