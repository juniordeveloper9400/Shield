import { Inject, Injectable } from '@nestjs/common';
import { asc, eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { assembly, district, lsgd, region, state, ward } from '../../db/schema';
import { CacheService } from '../../cache/cache.service';

// This is close to static (seeded from the Suvida LSG source, not
// user-writable) — see backend/docs/frd.md §8. Long TTL, no write path in
// this service to invalidate against.
const TTL = 3600;

@Injectable()
export class GeoService {
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    private readonly cache: CacheService,
  ) {}

  listRegions() {
    return this.cache.getOrSet('geo:regions', TTL, () => this.db.select().from(region).orderBy(asc(region.sort)));
  }

  listStates(regionId: string) {
    return this.cache.getOrSet(`geo:states:${regionId}`, TTL, () =>
      this.db.select().from(state).where(eq(state.regionId, regionId)).orderBy(asc(state.sort)),
    );
  }

  listDistricts(stateId: string) {
    return this.cache.getOrSet(`geo:districts:${stateId}`, TTL, () =>
      this.db.select().from(district).where(eq(district.stateId, stateId)).orderBy(asc(district.sort)),
    );
  }

  listAssemblies(districtId: string) {
    return this.cache.getOrSet(`geo:assemblies:${districtId}`, TTL, () =>
      this.db.select().from(assembly).where(eq(assembly.districtId, districtId)).orderBy(asc(assembly.sort)),
    );
  }

  listLsgds(assemblyId: string) {
    return this.cache.getOrSet(`geo:lsgds:${assemblyId}`, TTL, () =>
      this.db.select().from(lsgd).where(eq(lsgd.assemblyId, assemblyId)).orderBy(asc(lsgd.sort)),
    );
  }

  listWards(lsgdId: string) {
    return this.cache.getOrSet(`geo:wards:${lsgdId}`, TTL, () =>
      this.db.select().from(ward).where(eq(ward.lsgdId, lsgdId)).orderBy(asc(ward.sort)),
    );
  }
}
