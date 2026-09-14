import { Controller, Get, Header, Param } from '@nestjs/common';
import { GeoService } from './geo.service';
import { Public } from '../../common/decorators/public.decorator';

/**
 * Every route here is public, takes no per-caller input that changes the
 * answer (or, for the drill-down routes, is keyed only by the id in the
 * path), and reads from tables (`app.region` … `app.ward`) an admin edits
 * rarely — so every response is cacheable at Vercel's edge. Without this,
 * every hit (including `tree`, which flattens ~22k rows into a single
 * multi-megabyte JSON response) fell through to the function and the
 * database on every single call — the "My Team" screen's dominant cost, far
 * more than the client's own JSON parsing. `@Header` is per-method, not
 * class-level, in this Nest version, hence the repetition below. `s-maxage`
 * is what Vercel's CDN honours for edge caching; `max-age=0` still forces a
 * browser to revalidate so a stale local disk cache is never trusted on its
 * own; the short `stale-while-revalidate` window keeps a cache miss from
 * ever blocking a request on a full DB round trip once one caller has
 * warmed it.
 */
const GEO_CACHE_CONTROL = 'public, max-age=0, s-maxage=300, stale-while-revalidate=60';

@Controller('v1/public/geo')
@Public()
export class GeoController {
  constructor(private readonly geo: GeoService) {}

  @Get('regions')
  @Header('Cache-Control', GEO_CACHE_CONTROL)
  regions() {
    return this.geo.listRegions();
  }

  @Get('tree')
  @Header('Cache-Control', GEO_CACHE_CONTROL)
  tree() {
    return this.geo.listTree();
  }

  @Get('regions/:id/states')
  @Header('Cache-Control', GEO_CACHE_CONTROL)
  states(@Param('id') id: string) {
    return this.geo.listStates(id);
  }

  @Get('states/:id/districts')
  @Header('Cache-Control', GEO_CACHE_CONTROL)
  districts(@Param('id') id: string) {
    return this.geo.listDistricts(id);
  }

  @Get('districts/:id/assemblies')
  @Header('Cache-Control', GEO_CACHE_CONTROL)
  assemblies(@Param('id') id: string) {
    return this.geo.listAssemblies(id);
  }

  @Get('assemblies/:id/lsgds')
  @Header('Cache-Control', GEO_CACHE_CONTROL)
  lsgds(@Param('id') id: string) {
    return this.geo.listLsgds(id);
  }

  @Get('lsgds/:id/wards')
  @Header('Cache-Control', GEO_CACHE_CONTROL)
  wards(@Param('id') id: string) {
    return this.geo.listWards(id);
  }
}
