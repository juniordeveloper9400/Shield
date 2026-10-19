import { BadRequestException, Inject, Injectable, NotFoundException } from '@nestjs/common';
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
  labTest,
} from '../../db/schema';
import { CacheService } from '../../cache/cache.service';
import type { CreateLabCategoryDto, UpdateLabCategoryDto } from './dto';

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

  /** A single test's full detail — the "Test Details" page opened by tapping
   *  an included test inside a package's "Included In The Package" list, or
   *  a standalone test's own card. `about`/`whyThisTest` are specification1/2
   *  renamed for this response only (the admin-facing column names stay as
   *  they are in Test Master). */
  async getLabTestDetail(id: number) {
    return this.cache.getOrSet(`care:lab-test:${id}`, TTL, async () => {
      const [found] = await this.db.select().from(labTest).where(eq(labTest.id, id)).limit(1);
      if (!found || !found.isActive) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Test not found' } });
      return {
        id: found.id,
        name: found.name,
        shortName: found.shortName,
        testType: found.testType,
        sample: found.sample,
        reportingTime: found.reportingTime,
        fasting: found.fasting,
        symptoms: found.symptoms,
        about: found.specification1,
        whyThisTest: found.specification2,
      };
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

  // ---- Lab categories (console: Lab Tests → Categories tab) --------------
  // Active or not, unlike listLabCategories above (members only ever see the
  // active ones) — and, unlike that method, no cache: an admin editing this
  // list needs to see their own write reflected immediately, and it's a
  // low-traffic console screen, not a per-request member read.

  async listLabCategoriesForStaff() {
    const categories = await this.db.select().from(labCategory).orderBy(asc(labCategory.sort), asc(labCategory.name));
    if (categories.length === 0) return [];

    const primaryCounts = await this.db
      .select({ categoryId: labPackage.categoryId, testCount: sql<number>`count(*)::int` })
      .from(labPackage)
      .where(eq(labPackage.isActive, true))
      .groupBy(labPackage.categoryId);
    const extraCounts = await this.db
      .select({ categoryId: labPackageExtraCategory.categoryId, testCount: sql<number>`count(*)::int` })
      .from(labPackageExtraCategory)
      .innerJoin(labPackage, eq(labPackage.id, labPackageExtraCategory.packageId))
      .where(eq(labPackage.isActive, true))
      .groupBy(labPackageExtraCategory.categoryId);

    const countByCategory = new Map<number | null, number>();
    for (const row of [...primaryCounts, ...extraCounts]) {
      countByCategory.set(row.categoryId, (countByCategory.get(row.categoryId) ?? 0) + row.testCount);
    }
    return categories.map((category) => ({ ...category, testCount: countByCategory.get(category.id) ?? 0 }));
  }

  /** Null when [dto]'s name is already taken (case-insensitively — the
   *  column has a `lower(name)` unique index, migration 0055). */
  async createLabCategory(dto: CreateLabCategoryDto) {
    const [existing] = await this.db.execute<{ id: number }>(
      sql`select id from app.lab_category where lower(name) = lower(${dto.name}) limit 1`,
    ).then((r) => r.rows);
    if (existing) return { category: null };

    try {
      const [created] = await this.db.insert(labCategory).values(dto).returning();
      await this.cache.invalidate('care:lab-categories');
      return { category: created };
    } catch {
      return { category: null };
    }
  }

  /** Same null-on-duplicate-name contract as {@link createLabCategory}. */
  async updateLabCategory(id: number, dto: UpdateLabCategoryDto) {
    const [existing] = await this.db.execute<{ id: number }>(
      sql`select id from app.lab_category where lower(name) = lower(${dto.name}) and id <> ${id} limit 1`,
    ).then((r) => r.rows);
    if (existing) return { category: null };

    try {
      const [updated] = await this.db.update(labCategory).set(dto).where(eq(labCategory.id, id)).returning();
      if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab category not found' } });
      await this.cache.invalidate('care:lab-categories');
      return { category: updated };
    } catch (err) {
      if (err instanceof NotFoundException) throw err;
      return { category: null };
    }
  }

  async setLabCategoryActive(id: number, isActive: boolean) {
    const [updated] = await this.db.update(labCategory).set({ isActive }).where(eq(labCategory.id, id)).returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab category not found' } });
    await this.cache.invalidate('care:lab-categories');
    return updated;
  }

  async setLabCategorySort(id: number, sort: number) {
    const [updated] = await this.db.update(labCategory).set({ sort }).where(eq(labCategory.id, id)).returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab category not found' } });
    await this.cache.invalidate('care:lab-categories');
    return updated;
  }

  /** Refused (400, with a plain-English reason) while a test or a package
   *  still carries this category — `category_id` is `ON DELETE SET NULL` on
   *  both, so the database itself would not block this; the console still
   *  asks the admin to clear it deliberately rather than silently
   *  uncategorising everything under it. `lab_test` has no Drizzle mirror
   *  yet (that module hasn't moved off direct SQL), hence the raw count. */
  async deleteLabCategory(id: number) {
    const [category] = await this.db.select().from(labCategory).where(eq(labCategory.id, id)).limit(1);
    if (!category) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab category not found' } });

    const [{ n }] = await this.db
      .execute<{ n: number }>(
        sql`select (
          (select count(*) from app.lab_test where category_id = ${id}) +
          (select count(*) from app.lab_package where category_id = ${id})
        )::int as n`,
      )
      .then((r) => r.rows);
    if (n > 0) {
      throw new BadRequestException({
        error: {
          code: 'CATEGORY_IN_USE',
          message: `"${category.name}" is still set on ${n} test${n === 1 ? '' : 's'}/package${n === 1 ? '' : 's'} — change their category before deleting it.`,
        },
      });
    }
    await this.db.delete(labCategory).where(eq(labCategory.id, id));
    await this.cache.invalidate('care:lab-categories');
  }
}
