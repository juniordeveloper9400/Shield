import { Module } from '@nestjs/common';
import { CareService } from './care.service';
import { BookingService } from './booking.service';
import { CareController } from './care.controller';
import { MemberBookingController } from './member-booking.controller';
import { StaffBookingController } from './staff-booking.controller';
import { StaffCareController } from './staff-care.controller';

@Module({
  controllers: [CareController, MemberBookingController, StaffBookingController, StaffCareController],
  providers: [CareService, BookingService],
})
export class CareModule {}
