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

import { LabChargesService } from './lab-charges.service';
import { StaffLabChargesController } from './staff-lab-charges.controller';

@Module({
  controllers: [
    StaffLabChargesController,
    CareController,
    MemberBookingController,
    StaffBookingController,
    StaffCareController,
    StaffLabTestController,
    StaffLabPackageController,
  ],
  providers: [LabChargesService, CareService, BookingService, LabTestService],
})
export class CareModule {}
