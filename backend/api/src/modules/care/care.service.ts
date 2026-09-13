import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { asc, eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { clinic, clinicDoctor, dietitian, labPackage, labProfile } from '../../db/schema';
import { CacheService } from '../../cache/cache.service';

const TTL = 300; // near-static reference data, same tier as catalogue's TTL.LONG

/** Public browse endpoints — same cache-aside pattern as catalogue.service.ts. */
@Injectable()
export class CareService {
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    private readonly cache: CacheService,
  ) {}

  async listLabPackages() {
    return this.cache.getOrSet('care:lab-packages', TTL, () =>
      this.db.select().from(labPackage).where(eq(labPackage.isActive, true)).orderBy(asc(labPackage.sort)),
    );
  }

  async getLabPackage(id: number) {
    return this.cache.getOrSet(`care:lab-package:${id}`, TTL, async () => {
      const [pkg] = await this.db.select().from(labPackage).where(eq(labPackage.id, id)).limit(1);
      if (!pkg) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab package not found' } });
      const profiles = await this.db.select().from(labProfile).where(eq(labProfile.labPackageId, id)).orderBy(asc(labProfile.sort));
      return { ...pkg, profiles };
    });
  }

  async listClinics() {
    return this.cache.getOrSet('care:clinics', TTL, () =>
      this.db.select().from(clinic).where(eq(clinic.isActive, true)).orderBy(asc(clinic.sort)),
    );
  }

  async getClinic(id: number) {
    return this.cache.getOrSet(`care:clinic:${id}`, TTL, async () => {
      const [found] = await this.db.select().from(clinic).where(eq(clinic.id, id)).limit(1);
      if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Clinic not found' } });
      const doctors = await this.db.select().from(clinicDoctor).where(eq(clinicDoctor.clinicId, id)).orderBy(asc(clinicDoctor.sort));
      return { ...found, doctors };
    });
  }

  async listDietitians() {
    return this.cache.getOrSet('care:dietitians', TTL, () =>
      this.db.select().from(dietitian).where(eq(dietitian.isActive, true)).orderBy(asc(dietitian.sort)),
    );
  }
}
