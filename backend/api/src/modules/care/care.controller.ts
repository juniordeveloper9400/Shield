import { Controller, Get, Param, ParseIntPipe } from '@nestjs/common';
import { CareService } from './care.service';
import { BookingService } from './booking.service';
import { Public } from '../../common/decorators/public.decorator';

@Controller('v1/public/care')
@Public()
export class CareController {
  constructor(
    private readonly care: CareService,
    private readonly bookings: BookingService,
  ) {}

  @Get('lab-packages')
  labPackages() {
    return this.care.listLabPackages();
  }

  @Get('lab-categories')
  labCategories() {
    return this.care.listLabCategories();
  }

  /** The branch picker a member sees before confirming a lab booking
   *  (migration 0057) — every branch open for lab collection right now. */
  @Get('lab-stores')
  labStores() {
    return this.bookings.listLabStoresPublic();
  }

  @Get('lab-packages/:id')
  labPackage(@Param('id', ParseIntPipe) id: number) {
    return this.care.getLabPackage(id);
  }

  @Get('clinics')
  clinics() {
    return this.care.listClinics();
  }

  @Get('clinics/:id')
  clinic(@Param('id', ParseIntPipe) id: number) {
    return this.care.getClinic(id);
  }

  @Get('dietitians')
  dietitians() {
    return this.care.listDietitians();
  }
}
