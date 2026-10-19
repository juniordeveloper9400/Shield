import { ConflictException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, asc, eq, inArray, notInArray, sql } from 'drizzle-orm';
import { alias } from 'drizzle-orm/pg-core';
import { DRIZZLE, type Database } from '../../db/client';
import { CacheService } from '../../cache/cache.service';
import {
  adminUser,
  labCategory,
  labPackage,
  labPackageTestItem,
  labProfile,
  labTest,
  labTestFieldOption,
  labTestGroupItem,
  labTestSpecialRate,
} from '../../db/schema';
import { LAB_TEST_FIELD_KEYS } from './dto';
import type {
  CreateLabPackageDto,
  LabTestFieldKey,
  LabTestInputDto,
  SaveLabTestDto,
  UpdateLabPackageBuildDto,
  UpdateLabPackagePriceDto,
} from './dto';

/** `"A", "B" and "C"` for an error sentence. */
function quotedList(names: string[]): string {
  const quoted = names.map((n) => `"${n}"`);
  return quoted.length <= 1 ? quoted.join('') : `${quoted.slice(0, -1).join(', ')} and ${quoted[quoted.length - 1]}`;
}

function slugify(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/** Node-postgres wraps the real driver error as `.cause` — see
 *  identity.service.ts's own `permanentlyDeleteMember` for the same shape. */
function pgErrorText(error: unknown): string {
  const e = error as { cause?: { message?: string }; message?: string };
  return e?.cause?.message ?? e?.message ?? '';
}

/**
 * The Test Master (app.lab_test, migration 0046) and the package builder's
 * own staff-written side of app.lab_package (migration 0055) — ported from
 * shieldweb's own direct-SQL labTests.ts/labPackages.ts/labTestSql.ts.
 * Member-facing package browsing (listLabPackages, cached) stays on
 * CareService; this service owns everything a Test Master / Lab Packages
 * page write reaches.
 */
@Injectable()
export class LabTestService {
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    private readonly cache: CacheService,
  ) {}

  /** Both apps' public package/category reads (`CareService.listLabPackages`
   *  / `listLabCategories`) are cached for 5 minutes — a write here that
   *  changes what either would return has to bust them itself, or a just
   *  -activated package / just-edited test sits invisible in the app for
   *  up to that long. The per-item reads (`getLabPackage`, and
   *  `getLabTestDetail` — the page that shows a test's About / Why this test
   *  / Symptoms) are keyed by id, so they are cleared by pattern. */
  private async invalidatePublicCatalogueCache(): Promise<void> {
    await this.cache.invalidate(
      'care:lab-packages',
      'care:lab-categories',
      'care:lab-package:*',
      'care:lab-test:*',
    );
  }

  // ---- Test Master --------------------------------------------------------

  /** Every saved test, group test and package — the list under the form.
   *  Best-effort re-syncs every active+listed test's own member-facing
   *  app.lab_package row first, same as the console's own direct-SQL
   *  version did on every list load. */
  async listLabTests() {
    await this.syncAllActiveLabTests().catch(() => {});
    const rows = await this.db
      .select({
        id: labTest.id,
        lisCode: labTest.lisCode,
        testType: labTest.testType,
        name: labTest.name,
        categoryId: labTest.categoryId,
        categoryName: labCategory.name,
        description: labTest.description,
        shortName: labTest.shortName,
        department: labTest.department,
        method: labTest.method,
        sample: labTest.sample,
        reportingTime: labTest.reportingTime,
        amount: labTest.amount,
        labRate: labTest.labRate,
        source: labTest.source,
        isActive: labTest.isActive,
        showInApp: labTest.showInApp,
        isMostCommon: labTest.isMostCommon,
      })
      .from(labTest)
      .leftJoin(labCategory, eq(labCategory.id, labTest.categoryId))
      .orderBy(asc(labTest.name));
    const countById = await this.groupItemCounts();
    return rows.map((r) => ({ ...r, itemCount: countById.get(r.id) ?? 0 }));
  }

  /** Member counts of every group test / package, batched — pg-mem can't
   *  handle a correlated scalar subquery mixed into a `.select({...})`
   *  alongside plain columns (it corrupts the whole row), so this is kept
   *  as its own query and merged onto the main rows in JS instead. */
  private async groupItemCounts(): Promise<Map<number, number>> {
    const counts = await this.db
      .select({ groupId: labTestGroupItem.groupId, count: sql<number>`count(*)::int` })
      .from(labTestGroupItem)
      .groupBy(labTestGroupItem.groupId);
    return new Map(counts.map((c) => [c.groupId, c.count]));
  }

  /** One test with everything on its tabs: group members and special rates. */
  async getLabTest(id: number) {
    const [row] = await this.db.select().from(labTest).where(eq(labTest.id, id)).limit(1);
    if (!row) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab test not found' } });

    const member = alias(labTest, 'member_test');
    const groupItems = await this.db
      .select({
        testId: labTestGroupItem.testId,
        amount: labTestGroupItem.amount,
        setOrder: labTestGroupItem.setOrder,
        isSubhead: labTestGroupItem.isSubhead,
        name: member.name,
        department: member.department,
        sample: member.sample,
      })
      .from(labTestGroupItem)
      .innerJoin(member, eq(member.id, labTestGroupItem.testId))
      .where(eq(labTestGroupItem.groupId, id))
      .orderBy(asc(labTestGroupItem.setOrder), asc(labTestGroupItem.id));

    const specialRates = await this.db
      .select({ refLab: labTestSpecialRate.refLab, rate: labTestSpecialRate.rate })
      .from(labTestSpecialRate)
      .where(eq(labTestSpecialRate.testId, id))
      .orderBy(asc(labTestSpecialRate.refLab));

    return { ...row, groupItems, specialRates };
  }

  /** Names of the group tests / packages that list [testId] as a member. */
  private async groupsUsing(testId: number): Promise<string[]> {
    const group = alias(labTest, 'owning_group');
    const rows = await this.db
      .selectDistinct({ name: group.name })
      .from(labTestGroupItem)
      .innerJoin(group, eq(group.id, labTestGroupItem.groupId))
      .where(eq(labTestGroupItem.testId, testId))
      .orderBy(asc(group.name))
      .limit(5);
    return rows.map((r) => r.name);
  }

  /** Creates ([id] null) or updates a test together with its group members
   *  and special rates, atomically — a transaction, not a single raw CTE
   *  statement (shieldweb's own `buildSaveStatement` reasoning for why this
   *  must be all-or-nothing still applies; a Postgres transaction gives the
   *  same guarantee). Returns its id and LIS code. */
  async saveLabTest(id: number | null, dto: SaveLabTestDto, staffId: number) {
    const input: LabTestInputDto = { ...dto.input, name: dto.input.name.trim() };
    // created_by/updated_by want the caller's real name — resolved from
    // their own staff row server-side rather than trusted from the
    // request, so this attribution can't be spoofed by whatever a client
    // happens to send.
    const [caller] = await this.db.select({ name: adminUser.name }).from(adminUser).where(eq(adminUser.id, staffId)).limit(1);
    const userName = caller?.name ?? `Staff #${staffId}`;

    if (id && input.testType !== 'TEST') {
      const usedIn = await this.groupsUsing(id);
      if (usedIn.length > 0) {
        throw new ForbiddenException({
          error: {
            code: 'FORBIDDEN',
            message: `"${input.name}" is used inside ${quotedList(usedIn)}, so it has to stay a single Test. Remove it from there first.`,
          },
        });
      }
    }

    const values = {
      testType: input.testType,
      name: input.name,
      categoryId: input.categoryId ? Number(input.categoryId) : null,
      showInApp: input.showInApp,
      isMostCommon: input.isMostCommon,
      shortName: input.shortName,
      calcCode: input.calcCode,
      division: input.division,
      department: input.department,
      method: input.method,
      unit: input.unit,
      rate: input.rate.toString(),
      discountPercent: input.discountPercent.toString(),
      amount: input.amount.toString(),
      labRate: input.labRate.toString(),
      sample: input.sample,
      volume: input.volume,
      scheduledDays: input.scheduledDays,
      cutOfTime: input.cutOfTime,
      reportingTime: input.reportingTime,
      technology: input.technology,
      testMode: input.testMode,
      reportOnValue: input.reportOnValue,
      reportOnUnit: input.reportOnUnit,
      performAt: input.performAt,
      description: input.description,
      internalNote: input.internalNote,
      nablAccredited: input.nablAccredited,
      sendSms: input.sendSms,
      sampleTypeBarcode: input.sampleTypeBarcode,
      freeTest: input.freeTest,
      avoidIncentive: input.avoidIncentive,
      alphanumericCritical: input.alphanumericCritical,
      commonTechnology: input.commonTechnology,
      avoidResultEntry: input.avoidResultEntry,
      hideHead: input.hideHead,
      editTestRate: input.editTestRate,
      ref1: input.ref1,
      ref2: input.ref2,
      specification1: input.specification1,
      specification2: input.specification2,
      specification3: input.specification3,
      fasting: input.fasting,
      symptoms: input.symptoms,
      resultTemplate: input.resultTemplate,
      isActive: input.isActive,
    };

    // Pre-checked rather than left to the unique index's own violation —
    // more portable across drivers/test doubles than matching the raw
    // error text, and gives a clean 409 before any write is attempted.
    const [clash] = await this.db
      .select({ id: labTest.id })
      .from(labTest)
      .where(id ? and(sql`lower(${labTest.name}) = lower(${input.name})`, sql`${labTest.id} != ${id}`) : sql`lower(${labTest.name}) = lower(${input.name})`)
      .limit(1);
    if (clash) {
      throw new ConflictException({ error: { code: 'CONFLICT', message: `A test named "${input.name}" already exists — names must be unique.` } });
    }

    // Saving an existing row claims it as source = 'ADMIN' — a bulk
    // RATE_LIST import (migration 0049) is raw reference data until
    // someone here actually opens and saves it; from that moment it has
    // staff edits on it. A new row gets 'ADMIN' via the column's own
    // DEFAULT (deliberately not set explicitly here either).
    let saved: { id: number; lisCode: number };
    try {
      saved = await this.db.transaction(async (tx) => {
        let row: { id: number; lisCode: number };
        if (id) {
          const [updated] = await tx
            .update(labTest)
            .set({ ...values, updatedBy: userName, source: 'ADMIN', updatedAt: new Date() })
            .where(eq(labTest.id, id))
            .returning({ id: labTest.id, lisCode: labTest.lisCode });
          if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'That test no longer exists — it may have been deleted. Press New to start again.' } });
          row = updated;
        } else {
          const [created] = await tx
            .insert(labTest)
            .values({ ...values, createdBy: userName, updatedBy: userName })
            .returning({ id: labTest.id, lisCode: labTest.lisCode });
          row = created;
        }

        const members = input.testType === 'TEST' ? [] : dto.groupItems;
        if (members.length > 0) {
          await tx
            .insert(labTestGroupItem)
            .values(members.map((m) => ({ groupId: row.id, testId: Number(m.testId), amount: m.amount.toString(), setOrder: m.setOrder, isSubhead: m.isSubhead })))
            .onConflictDoUpdate({
              target: [labTestGroupItem.groupId, labTestGroupItem.testId],
              set: { amount: sql`excluded.amount`, setOrder: sql`excluded.set_order`, isSubhead: sql`excluded.is_subhead` },
            });
          await tx.delete(labTestGroupItem).where(
            and(
              eq(labTestGroupItem.groupId, row.id),
              notInArray(labTestGroupItem.testId, members.map((m) => Number(m.testId))),
            ),
          );
        } else {
          await tx.delete(labTestGroupItem).where(eq(labTestGroupItem.groupId, row.id));
        }

        const rates = dto.specialRates.map((r) => ({ refLab: r.refLab.trim(), rate: r.rate }));
        if (rates.length > 0) {
          await tx
            .insert(labTestSpecialRate)
            .values(rates.map((r) => ({ testId: row.id, refLab: r.refLab, rate: r.rate.toString() })))
            .onConflictDoUpdate({
              target: [labTestSpecialRate.testId, labTestSpecialRate.refLab],
              set: { rate: sql`excluded.rate` },
            });
          await tx.delete(labTestSpecialRate).where(
            and(eq(labTestSpecialRate.testId, row.id), notInArray(labTestSpecialRate.refLab, rates.map((r) => r.refLab))),
          );
        } else {
          await tx.delete(labTestSpecialRate).where(eq(labTestSpecialRate.testId, row.id));
        }

        return row;
      });
    } catch (error) {
      if (error instanceof NotFoundException) throw error;
      if (pgErrorText(error).includes('lab_test_name_uidx')) {
        throw new ConflictException({ error: { code: 'CONFLICT', message: `A test named "${input.name}" already exists — names must be unique.` } });
      }
      throw error;
    }

    // Whatever was typed into a pick-list field is available to pick next
    // time too, even if nobody explicitly added it on the Field Options
    // list first — the same "nothing has to be registered before it's
    // used" freedom the field already had as a plain text input.
    await this.upsertFieldOptionsFromTest(values);

    try {
      await this.syncLabTestListing(saved.id);
    } catch (syncError) {
      const why = syncError instanceof Error ? syncError.message : 'unknown error';
      throw new ConflictException({
        error: { code: 'SYNC_FAILED', message: `"${input.name}" was saved, but its listing in the app could not be updated (${why}). Save it again to retry.` },
      });
    }
    await this.invalidatePublicCatalogueCache();
    return { id: String(saved.id), lisCode: saved.lisCode };
  }

  /** Deletes a test (and, through the cascade, its own group rows and
   *  special rates). Refused while another group test or package still
   *  lists it, or while it's part of a staff-built package, or has been
   *  booked by a member. */
  async deleteLabTest(id: number): Promise<void> {
    const [row] = await this.db.select({ name: labTest.name }).from(labTest).where(eq(labTest.id, id)).limit(1);
    if (!row) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab test not found' } });
    const name = row.name;

    const usedIn = await this.groupsUsing(id);
    if (usedIn.length > 0) {
      throw new ForbiddenException({
        error: { code: 'FORBIDDEN', message: `"${name}" is used inside ${quotedList(usedIn)}. Remove it from there before deleting it.` },
      });
    }
    try {
      const [deleted] = await this.db.delete(labTest).where(eq(labTest.id, id)).returning({ id: labTest.id });
      if (!deleted) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab test not found' } });
    } catch (error) {
      if (error instanceof NotFoundException) throw error;
      const text = pgErrorText(error);
      if (text.includes('lab_package_test_item')) {
        throw new ConflictException({
          error: { code: 'CONFLICT', message: `"${name}" is part of a package on Member packages. Remove it from that package first.` },
        });
      }
      if (text.includes('lab_booking')) {
        throw new ConflictException({
          error: {
            code: 'CONFLICT',
            message: `"${name}" has been booked by a member, so it cannot be deleted. Untick "Show in the app" (or mark it inactive) to take it off the app instead.`,
          },
        });
      }
      throw error;
    }
    await this.invalidatePublicCatalogueCache();
  }

  // ---- Field options (app.lab_test_field_option, migration 0101) ----------

  /** Every pick-list entry, grouped by field — what the Test Master's nine
   *  free-text fields (Department, Method, Sample, Volume, Scheduled Days,
   *  Cut of time, Reporting Time, Technology, Test Mode, Perform At) offer
   *  as suggestions. */
  async listLabTestFieldOptions(): Promise<Record<LabTestFieldKey, { id: string; value: string }[]>> {
    const rows = await this.db
      .select({ id: labTestFieldOption.id, fieldKey: labTestFieldOption.fieldKey, value: labTestFieldOption.value })
      .from(labTestFieldOption)
      .orderBy(asc(labTestFieldOption.value));
    const byKey = Object.fromEntries(
      LAB_TEST_FIELD_KEYS.map((key) => [key, [] as { id: string; value: string }[]]),
    ) as Record<LabTestFieldKey, { id: string; value: string }[]>;
    for (const row of rows) {
      const key = row.fieldKey as LabTestFieldKey;
      if (key in byKey) byKey[key].push({ id: String(row.id), value: row.value });
    }
    return byKey;
  }

  /** Adds one entry to a field's pick list — same values a test could
   *  already save with that field, just addable up front instead of only
   *  after a test first uses it. */
  async createLabTestFieldOption(fieldKey: LabTestFieldKey, value: string): Promise<{ id: string; value: string }> {
    const trimmed = value.trim();
    const [existing] = await this.db
      .select({ id: labTestFieldOption.id, value: labTestFieldOption.value })
      .from(labTestFieldOption)
      .where(and(eq(labTestFieldOption.fieldKey, fieldKey), sql`lower(${labTestFieldOption.value}) = lower(${trimmed})`))
      .limit(1);
    if (existing) return { id: String(existing.id), value: existing.value };
    const [created] = await this.db
      .insert(labTestFieldOption)
      .values({ fieldKey, value: trimmed })
      .returning({ id: labTestFieldOption.id, value: labTestFieldOption.value });
    return { id: String(created.id), value: created.value };
  }

  /** Renames a pick-list entry — a test that already carries the old text
   *  keeps it; only the list's own wording changes for the next test. */
  async updateLabTestFieldOption(id: number, value: string): Promise<void> {
    const [updated] = await this.db
      .update(labTestFieldOption)
      .set({ value: value.trim() })
      .where(eq(labTestFieldOption.id, id))
      .returning({ id: labTestFieldOption.id });
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'That entry no longer exists.' } });
  }

  /** Removes one pick-list entry. Never touches a test that already used
   *  the value — it just stops being offered as a suggestion. */
  async deleteLabTestFieldOption(id: number): Promise<void> {
    const [deleted] = await this.db.delete(labTestFieldOption).where(eq(labTestFieldOption.id, id)).returning({ id: labTestFieldOption.id });
    if (!deleted) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'That entry no longer exists.' } });
  }

  /** Upserts whatever a just-saved test's own pick-list fields carry — see
   *  `saveLabTest`'s own call. Best-effort per field: one odd value should
   *  never fail the test save that's already committed. */
  private async upsertFieldOptionsFromTest(values: Record<string, unknown>): Promise<void> {
    const rows = LAB_TEST_FIELD_KEYS.map((fieldKey) => ({ fieldKey, value: String(values[fieldKey] ?? '').trim() })).filter(
      (row) => row.value !== '',
    );
    if (rows.length === 0) return;
    try {
      await this.db.insert(labTestFieldOption).values(rows).onConflictDoNothing();
    } catch {
      // Never block a test save over its pick-list bookkeeping.
    }
  }

  // ---- Member-facing listing sync (migration 0056) -------------------------

  /** Every saved test, group test and package — re-synced best-effort. */
  private async syncAllActiveLabTests(): Promise<void> {
    const activeTests = await this.db.select({ id: labTest.id }).from(labTest).where(and(eq(labTest.isActive, true), eq(labTest.showInApp, true)));
    for (const row of activeTests) {
      await this.syncLabTestListing(row.id).catch(() => {});
    }
  }

  /**
   * Keeps the member-facing listing of one test in step with the test
   * itself — what "Top Profiles and Tests" in both apps reads. A test,
   * group test, or package that is active and switched on with "Show in
   * the app" gets (or keeps) one app.lab_package row of its own
   * (source_test_id set); anything else has its listing switched off
   * (never deleted, so a member's earlier booking keeps pointing at
   * something).
   */
  private async syncLabTestListing(testId: number): Promise<void> {
    const [t] = await this.db
      .select({
        id: labTest.id,
        testType: labTest.testType,
        name: labTest.name,
        shortName: labTest.shortName,
        description: labTest.description,
        specification1: labTest.specification1,
        specification2: labTest.specification2,
        symptoms: labTest.symptoms,
        rate: labTest.rate,
        amount: labTest.amount,
        categoryId: labTest.categoryId,
        sample: labTest.sample,
        reportingTime: labTest.reportingTime,
        isActive: labTest.isActive,
        showInApp: labTest.showInApp,
        isMostCommon: labTest.isMostCommon,
        fasting: labTest.fasting,
      })
      .from(labTest)
      .where(eq(labTest.id, testId))
      .limit(1);
    if (!t) return;

    const listed = t.showInApp && t.isActive;
    if (!listed) {
      await this.db.update(labPackage).set({ isActive: false }).where(eq(labPackage.sourceTestId, testId));
      return;
    }

    const [{ count: itemCount }] = await this.db
      .select({ count: sql<number>`count(*)::int` })
      .from(labTestGroupItem)
      .where(eq(labTestGroupItem.groupId, testId));
    const testCount = t.testType === 'GROUP' || t.testType === 'PACKAGE' ? Math.max(itemCount, 1) : 1;
    const price = Number(t.amount);
    const mrp = Math.max(Number(t.rate), price);

    const base = slugify(t.name) || `test-${testId}`;
    const takenResult = await this.db.execute<{ taken: boolean }>(sql`
      SELECT EXISTS(SELECT 1 FROM app.lab_package WHERE slug = ${base} AND (source_test_id IS NULL OR source_test_id != ${testId})) AS taken
    `);
    const slug = takenResult.rows[0]?.taken ? `${base}-${testId}` : base;

    const [saved] = await this.db
      .insert(labPackage)
      .values({
        slug,
        name: t.name,
        about: t.description.trim() || t.specification1,
        categoryId: t.categoryId,
        testCount,
        profileCount: 1,
        price: price.toString(),
        mrp: mrp.toString(),
        saved: Math.max(mrp - price, 0).toString(),
        reportIn: t.reportingTime,
        sample: t.sample,
        isActive: true,
        sourceTestId: testId,
        isMostCommon: t.isMostCommon,
        fasting: t.fasting,
        shortName: t.shortName,
        whyThisTest: t.specification2,
        symptoms: t.symptoms,
      })
      .onConflictDoUpdate({
        target: labPackage.sourceTestId,
        set: {
          slug,
          name: t.name,
          about: t.description.trim() || t.specification1,
          categoryId: t.categoryId,
          testCount,
          profileCount: 1,
          price: price.toString(),
          mrp: mrp.toString(),
          saved: Math.max(mrp - price, 0).toString(),
          reportIn: t.reportingTime,
          sample: t.sample,
          isActive: true,
          isMostCommon: t.isMostCommon,
          fasting: t.fasting,
          shortName: t.shortName,
          whyThisTest: t.specification2,
          symptoms: t.symptoms,
        },
      })
      .returning({ id: labPackage.id });
    const packageId = saved.id;

    const member = alias(labTest, 'member_test');
    const memberItems = await this.db
      .select({ id: member.id, name: member.name, shortName: member.shortName })
      .from(labTestGroupItem)
      .innerJoin(member, eq(member.id, labTestGroupItem.testId))
      .where(eq(labTestGroupItem.groupId, testId))
      .orderBy(asc(labTestGroupItem.setOrder), asc(labTestGroupItem.id));

    await this.db.delete(labProfile).where(eq(labProfile.labPackageId, packageId));
    if (memberItems.length > 0) {
      await this.db.insert(labProfile).values(
        memberItems.map((item, idx) => ({
          labPackageId: packageId,
          name: item.name,
          parameters: 1,
          sort: idx,
          testId: item.id,
          shortName: item.shortName,
        })),
      );
    } else {
      await this.db.insert(labProfile).values({ labPackageId: packageId, name: t.name, parameters: testCount, sort: 0 });
    }
  }

  // ---- Package builder (staff-written app.lab_package rows) ---------------

  /** The real packages members can book — not the one-test listings kept
   *  for tests switched on with "Show in the app" (source_test_id set);
   *  those follow their test and are edited on the Test Master. */
  async listLabPackagesForStaff() {
    return this.db
      .select()
      .from(labPackage)
      .where(sql`${labPackage.sourceTestId} IS NULL`)
      .orderBy(asc(labPackage.sort), asc(labPackage.name));
  }

  /** Deletes a package built in the old package builder (`source_test_id`
   *  null). Its profiles and test links go with it (cascade); a member's
   *  earlier bookings keep their own text copy. A test's own one-test
   *  listing is never deleted here — it follows its test. */
  async deleteLabPackage(id: number): Promise<void> {
    const [deleted] = await this.db
      .delete(labPackage)
      .where(and(eq(labPackage.id, id), sql`${labPackage.sourceTestId} IS NULL`))
      .returning({ id: labPackage.id });
    if (!deleted) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab package not found' } });
    await this.invalidatePublicCatalogueCache();
  }

  async setLabPackageActive(id: number, isActive: boolean) {
    const [updated] = await this.db.update(labPackage).set({ isActive }).where(eq(labPackage.id, id)).returning({ id: labPackage.id });
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab package not found' } });
    await this.invalidatePublicCatalogueCache();
  }

  async updateLabPackagePrice(id: number, dto: UpdateLabPackagePriceDto) {
    const [updated] = await this.db
      .update(labPackage)
      .set({ price: dto.price.toString(), mrp: dto.mrp.toString(), saved: Math.max(dto.mrp - dto.price, 0).toString() })
      .where(eq(labPackage.id, id))
      .returning({ id: labPackage.id });
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab package not found' } });
    await this.invalidatePublicCatalogueCache();
  }

  /** Every active test or group test the package builder can offer — never
   *  an existing package, so a package can't nest another package inside
   *  itself. */
  async listLabTestsForPicker() {
    const rows = await this.db
      .select({
        id: labTest.id,
        lisCode: labTest.lisCode,
        testType: labTest.testType,
        name: labTest.name,
        department: labTest.department,
        sample: labTest.sample,
        amount: labTest.amount,
      })
      .from(labTest)
      .where(and(sql`${labTest.testType} IN ('TEST', 'GROUP')`, eq(labTest.isActive, true)))
      .orderBy(asc(labTest.testType), asc(labTest.name));
    const countById = await this.groupItemCounts();
    return rows.map((r) => ({ ...r, itemCount: countById.get(r.id) ?? 0 }));
  }

  /** The real app.lab_test rows [packageId] was built from, oldest choice
   *  first — what the builder preloads its picker with when re-opened. */
  async getLabPackageTestIds(packageId: number): Promise<string[]> {
    const rows = await this.db
      .select({ testId: labPackageTestItem.testId })
      .from(labPackageTestItem)
      .where(eq(labPackageTestItem.packageId, packageId))
      .orderBy(asc(labPackageTestItem.sort));
    return rows.map((r) => String(r.testId));
  }

  /** A unique slug for a new package. Existing packages are re-read each
   *  attempt so two saves racing each other still can't both win the same
   *  slug — the same guard app.lab_package.slug's own UNIQUE enforces either way. */
  private async uniqueSlug(name: string): Promise<string> {
    const base = slugify(name) || 'package';
    for (let n = 1; n < 50; n++) {
      const candidate = n === 1 ? base : `${base}-${n}`;
      const [existing] = await this.db.select({ id: labPackage.id }).from(labPackage).where(eq(labPackage.slug, candidate)).limit(1);
      if (!existing) return candidate;
    }
    return `${base}-${Date.now()}`;
  }

  /** Writes [testIds] as both the real link (lab_package_test_item) and,
   *  derived from the same chosen tests, the free-text lab_profile rows the
   *  app's own package card renders. Replaces whatever the package held
   *  before. Returns the real total test count across everything chosen. */
  private async writePackageTests(packageId: number, testIds: string[]): Promise<{ testCount: number }> {
    await this.db.delete(labPackageTestItem).where(eq(labPackageTestItem.packageId, packageId));
    await this.db.delete(labProfile).where(eq(labProfile.labPackageId, packageId));
    if (testIds.length === 0) return { testCount: 0 };

    const ids = testIds.map((t) => Number(t));
    const tests = await this.db
      .select({ id: labTest.id, name: labTest.name, testType: labTest.testType, shortName: labTest.shortName })
      .from(labTest)
      .where(inArray(labTest.id, ids));
    const counts = await this.db
      .select({ groupId: labTestGroupItem.groupId, count: sql<number>`count(*)::int` })
      .from(labTestGroupItem)
      .where(inArray(labTestGroupItem.groupId, ids))
      .groupBy(labTestGroupItem.groupId);
    const countById = new Map(counts.map((c) => [c.groupId, c.count]));
    const byId = new Map(
      tests.map((t) => [
        String(t.id),
        { name: t.name, shortName: t.shortName, parameters: t.testType === 'GROUP' ? Math.max(countById.get(t.id) ?? 0, 1) : 1 },
      ]),
    );

    let testCount = 0;
    for (const [index, testId] of testIds.entries()) {
      const info = byId.get(testId) ?? { name: 'Test', shortName: '', parameters: 1 };
      testCount += info.parameters;
      await this.db.insert(labPackageTestItem).values({ packageId, testId: Number(testId), sort: index });
      await this.db.insert(labProfile).values({
        labPackageId: packageId,
        name: info.name,
        parameters: info.parameters,
        sort: index,
        testId: Number(testId),
        shortName: info.shortName,
      });
    }
    return { testCount };
  }

  /** Creates a new member-bookable package from the builder. Returns the
   *  new package's id. */
  async createLabPackage(dto: CreateLabPackageDto): Promise<{ id: string }> {
    const slug = await this.uniqueSlug(dto.name);
    const saved = Math.max(dto.mrp - dto.price, 0);
    const [created] = await this.db
      .insert(labPackage)
      .values({
        slug,
        name: dto.name.trim(),
        categoryId: dto.categoryId ? Number(dto.categoryId) : null,
        testCount: 0,
        profileCount: dto.testIds.length,
        price: dto.price.toString(),
        mrp: dto.mrp.toString(),
        saved: saved.toString(),
        forWhom: dto.forWhom,
        sample: dto.sample,
        preparation: dto.preparation,
        fasting: dto.fasting,
        reportIn: dto.reportIn,
        about: dto.about,
      })
      .returning({ id: labPackage.id });
    const id = created.id;
    const { testCount } = await this.writePackageTests(id, dto.testIds);
    await this.db.update(labPackage).set({ testCount }).where(eq(labPackage.id, id));
    await this.invalidatePublicCatalogueCache();
    return { id: String(id) };
  }

  /** Updates an existing builder-made (or seeded) package's fields.
   *  test_count/profile_count and the underlying rows are only touched
   *  when [dto.testsChanged] — a package seeded before migration 0055 has
   *  no real test link yet, so writing those columns unconditionally would
   *  zero out a seeded package's real count the moment an admin only
   *  changed its price. */
  async updateLabPackageBuild(id: number, dto: UpdateLabPackageBuildDto): Promise<void> {
    const input = dto.input;
    const saved = Math.max(input.mrp - input.price, 0);
    const [updated] = await this.db
      .update(labPackage)
      .set({
        name: input.name.trim(),
        categoryId: input.categoryId ? Number(input.categoryId) : null,
        price: input.price.toString(),
        mrp: input.mrp.toString(),
        saved: saved.toString(),
        forWhom: input.forWhom,
        sample: input.sample,
        preparation: input.preparation,
        fasting: input.fasting,
        reportIn: input.reportIn,
        about: input.about,
      })
      .where(eq(labPackage.id, id))
      .returning({ id: labPackage.id });
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab package not found' } });

    if (dto.testsChanged) {
      const { testCount } = await this.writePackageTests(id, input.testIds);
      await this.db.update(labPackage).set({ testCount, profileCount: input.testIds.length }).where(eq(labPackage.id, id));
    }
    await this.invalidatePublicCatalogueCache();
  }
}
