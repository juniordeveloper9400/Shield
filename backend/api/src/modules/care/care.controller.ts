import { Controller, Get, Param, ParseIntPipe } from '@nestjs/common';
import { CareService } from './care.service';
import { Public } from '../../common/decorators/public.decorator';

@Controller('v1/public/care')
@Public()
export class CareController {
  constructor(private readonly care: CareService) {}

  @Get('lab-packages')
  labPackages() {
    return this.care.listLabPackages();
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
