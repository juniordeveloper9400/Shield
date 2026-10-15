import { Module } from '@nestjs/common';
import { CareService } from './care.service';
import { BookingService } from './booking.service';
import { LabTestService } from './lab-test.service';
import { CareController } from './care.controller';
import { MemberBookingController } from './member-booking.controller';
import { StaffBookingController } from './staff-booking.controller';
import { StaffCareController } from './staff-care.controller';
import { StaffLabTestController } from './staff-lab-test.controller';
import { StaffLabPackageController } from './staff-lab-package.controller';

@Module({
  controllers: [
    CareController,
    MemberBookingController,
    StaffBookingController,
    StaffCareController,
    StaffLabTestController,
    StaffLabPackageController,
  ],
  providers: [CareService, BookingService, LabTestService],
})
export class CareModule {}
