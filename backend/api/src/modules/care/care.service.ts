import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { asc, eq, inArray, sql } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import {
  clinic,
  clinicDoctor,
  dietitian,
  labCategory,
  labPackage,
  labPackageExtraCategory,
  labProfile,
} from '../../db/schema';
import { CacheService } from '../../cache/cache.service';

const TTL = 300; // near-static reference data, same tier as catalogue's TTL.LONG

/** Public browse endpoints — same cache-aside pattern as catalogue.service.ts. */
@Injectable()
export class CareService {
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    private readonly cache: CacheService,
  ) {}

  /**
   * Every active package with its profiles attached — the client's package
   * card (both the "Top Packages" strip and the full list) reads the
   * breakdown straight off each card with nothing else to tap, so the list
   * itself has to carry it, not just {@link getLabPackage}'s single-package
   * detail.
   *
   * `extraCategoryIds` (migration 0067) is every category this package also
   * shows under, on top of its one primary `categoryId` — a test genuinely
   * relevant to more than one "Explore by health concern" tile (FSH/LH/SHBG
   * under both Men health and women health, say) without picking a side.
   */
  async listLabPackages() {
    return this.cache.getOrSet('care:lab-packages', TTL, async () => {
      const packages = await this.db
        .select()
        .from(labPackage)
        .where(eq(labPackage.isActive, true))
        .orderBy(asc(labPackage.sort));
      if (packages.length === 0) return [];

      const profiles = await this.db
        .select()
        .from(labProfile)
        .where(inArray(labProfile.labPackageId, packages.map((p) => p.id)))
        .orderBy(asc(labProfile.sort));
      const byPackage = new Map<number, typeof profiles>();
      for (const profile of profiles) {
        const bucket = byPackage.get(profile.labPackageId);
        if (bucket) bucket.push(profile);
        else byPackage.set(profile.labPackageId, [profile]);
      }

      const extras = await this.db
        .select()
        .from(labPackageExtraCategory)
        .where(inArray(labPackageExtraCategory.packageId, packages.map((p) => p.id)));
      const extraCategoriesByPackage = new Map<number, number[]>();
      for (const row of extras) {
        const bucket = extraCategoriesByPackage.get(row.packageId);
        if (bucket) bucket.push(row.categoryId);
        else extraCategoriesByPackage.set(row.packageId, [row.categoryId]);
      }

      return packages.map((pkg) => ({
        ...pkg,
        profiles: byPackage.get(pkg.id) ?? [],
        extraCategoryIds: extraCategoriesByPackage.get(pkg.id) ?? [],
      }));
    });
  }

  /**
   * "Explore by health concern" — every active category, each carrying how
   * many active packages currently sit under it (counted here, not a stored
   * column, so it can never drift from what {@link listLabPackages} itself
   * would show for that category) — a package counts toward a category it
   * reaches either as its primary `categoryId` or via
   * `app.lab_package_extra_category` (migration 0067), the same two places
   * {@link listLabPackages} itself reads.
   *
   * Three plain queries merged in JS rather than one grouped join — the join
   * count needs every selected category column repeated in a GROUP BY, and
   * this reads the same either way while staying easy to follow (the same
   * shape {@link listLabPackages} already merges its profiles in).
   */
  async listLabCategories() {
    return this.cache.getOrSet('care:lab-categories', TTL, async () => {
      const categories = await this.db
        .select()
        .from(labCategory)
        .where(eq(labCategory.isActive, true))
        .orderBy(asc(labCategory.sort), asc(labCategory.name));
      if (categories.length === 0) return [];

      const primaryCounts = await this.db
        .select({ categoryId: labPackage.categoryId, testCount: sql<number>`count(*)::int` })
        .from(labPackage)
        .where(eq(labPackage.isActive, true))
        .groupBy(labPackage.categoryId);

      const extraCounts = await this.db
        .select({
          categoryId: labPackageExtraCategory.categoryId,
          testCount: sql<number>`count(*)::int`,
        })
        .from(labPackageExtraCategory)
        .innerJoin(labPackage, eq(labPackage.id, labPackageExtraCategory.packageId))
        .where(eq(labPackage.isActive, true))
        .groupBy(labPackageExtraCategory.categoryId);

      const countByCategory = new Map<number | null, number>();
      for (const row of [...primaryCounts, ...extraCounts]) {
        countByCategory.set(row.categoryId, (countByCategory.get(row.categoryId) ?? 0) + row.testCount);
      }

      return categories.map((category) => ({
        ...category,
        testCount: countByCategory.get(category.id) ?? 0,
      }));
    });
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
