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

  /**
   * The whole hierarchy flattened into one list — region down to ward, each
   * row carrying its own parentId and a lowercase level tag. Exists for
   * clients (the legacy `shield agent_invester/` app) that build a full
   * in-memory tree once rather than drilling down tier by tier; the
   * region..lsgd structure is ~1,200 rows, wards add ~21k more. Cached like
   * every other geo read here — this data is near-static.
   */
  listTree() {
    return this.cache.getOrSet('geo:tree', TTL, async () => {
      const [regions, states, districts, assemblies, lsgds, wards] = await Promise.all([
        this.db.select().from(region).orderBy(asc(region.sort)),
        this.db.select().from(state).orderBy(asc(state.sort)),
        this.db.select().from(district).orderBy(asc(district.sort)),
        this.db.select().from(assembly).orderBy(asc(assembly.sort)),
        this.db.select().from(lsgd).orderBy(asc(lsgd.sort)),
        this.db.select().from(ward).orderBy(asc(ward.sort)),
      ]);

      return [
        ...regions.map((r) => ({ id: r.id, parentId: null, level: 'region', name: r.name, code: r.code, prefixCode: r.prefixCode, type: '', sort: r.sort })),
        ...states.map((s) => ({ id: s.id, parentId: s.regionId, level: 'state', name: s.name, code: s.code, prefixCode: s.prefixCode, type: '', sort: s.sort })),
        ...districts.map((d) => ({
          id: d.id,
          parentId: d.stateId,
          level: 'district',
          name: d.name,
          code: d.code,
          prefixCode: d.prefixCode,
          type: '',
          sort: d.sort,
        })),
        ...assemblies.map((a) => ({
          id: a.id,
          parentId: a.districtId,
          level: 'assembly',
          name: a.name,
          code: a.code,
          prefixCode: a.prefixCode,
          type: '',
          sort: a.sort,
        })),
        ...lsgds.map((l) => ({
          id: l.id,
          parentId: l.assemblyId,
          level: 'lsgd',
          name: l.name,
          code: l.code,
          prefixCode: l.prefixCode,
          type: l.type,
          sort: l.sort,
        })),
        ...wards.map((w) => ({
          id: w.id,
          parentId: w.lsgdId,
          level: 'ward',
          name: w.name || (w.wardNumber ? `Ward ${w.wardNumber}` : '') || w.code || 'Ward',
          code: w.code,
          prefixCode: w.prefixCode,
          type: '',
          sort: w.sort,
        })),
      ];
    });
  }
}
