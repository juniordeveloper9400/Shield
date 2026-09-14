import { Controller, Get, Param } from '@nestjs/common';
import { GeoService } from './geo.service';
import { Public } from '../../common/decorators/public.decorator';

@Controller('v1/public/geo')
@Public()
export class GeoController {
  constructor(private readonly geo: GeoService) {}

  @Get('regions')
  regions() {
    return this.geo.listRegions();
  }

  @Get('tree')
  tree() {
    return this.geo.listTree();
  }

  @Get('regions/:id/states')
  states(@Param('id') id: string) {
    return this.geo.listStates(id);
  }

  @Get('states/:id/districts')
  districts(@Param('id') id: string) {
    return this.geo.listDistricts(id);
  }

  @Get('districts/:id/assemblies')
  assemblies(@Param('id') id: string) {
    return this.geo.listAssemblies(id);
  }

  @Get('assemblies/:id/lsgds')
  lsgds(@Param('id') id: string) {
    return this.geo.listLsgds(id);
  }

  @Get('lsgds/:id/wards')
  wards(@Param('id') id: string) {
    return this.geo.listWards(id);
  }
}
