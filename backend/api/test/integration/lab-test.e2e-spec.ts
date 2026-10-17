process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-please-ignore-000000';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-please-ignore-00000';

import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { hash } from 'bcryptjs';
import { eq } from 'drizzle-orm';
import { AppModule } from '../../src/app.module';
import { DRIZZLE } from '../../src/db/client';
import { REDIS_CLIENT } from '../../src/cache/redis.client';
import { FIREBASE_VERIFIER } from '../../src/modules/auth/session.types';
import { adminUser, labCategory, labPackage, labTest } from '../../src/db/schema';
import { createTestDb, type TestDb } from './create-test-db';
import { createTestRedis } from './fake-redis';
import { FakeFirebaseVerifier } from './fake-firebase-verifier';

const BLANK_INPUT = {
  testType: 'TEST' as const,
  name: 'Blood Glucose Fasting',
  categoryId: '',
  showInApp: false,
  isMostCommon: false,
  shortName: '',
  calcCode: '',
  division: 'LAB',
  department: 'Biochemistry',
  method: '',
  unit: 'mg/dL',
  rate: 200,
  discountPercent: 0,
  amount: 200,
  labRate: 0,
  sample: 'Blood',
  volume: '',
  scheduledDays: '',
  cutOfTime: '',
  reportingTime: 'Same Day',
  technology: '',
  testMode: '',
  reportOnValue: 0,
  reportOnUnit: 'Minutes' as const,
  performAt: 'In House',
  internalNote: '',
  nablAccredited: false,
  sendSms: false,
  sampleTypeBarcode: false,
  freeTest: false,
  avoidIncentive: false,
  alphanumericCritical: false,
  commonTechnology: false,
  avoidResultEntry: false,
  hideHead: false,
  editTestRate: false,
  ref1: '',
  ref2: '',
  specification1: '',
  specification2: '',
  specification3: '',
  resultTemplate: '',
  isActive: true,
};

/**
 * The Test Master (app.lab_test) and the package builder's own write side
 * of app.lab_package — ported from shieldweb's own direct-SQL labTests.ts/
 * labPackages.ts/labTestSql.ts onto LabTestService.
 */
describe('Lab Test Master & Package builder (e2e)', () => {
  let app: INestApplication;
  let db: TestDb;
  let firebase: FakeFirebaseVerifier;
  let superAdminToken: string;

  it('lists every test with its category and saves description/category edits to its member listing', async () => {
    const [kidney] = await db.insert(labCategory).values({ name: 'Kidney edit fixture' }).returning();
    const [general] = await db.insert(labCategory).values({ name: 'General edit fixture' }).returning();
    const created = await request(app.getHttpServer()).post('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ input: { ...BLANK_INPUT, name: 'Description fixture', categoryId: String(kidney.id), description: 'Initial description', showInApp: true }, groupItems: [], specialRates: [] }).expect(201);
    const id = created.body.id;
    await request(app.getHttpServer()).post(`/v1/staff/lab-tests/${id}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ input: { ...BLANK_INPUT, name: 'Updated description fixture', categoryId: String(general.id), description: 'Updated member description', showInApp: true }, groupItems: [], specialRates: [] }).expect(201);
    const listed = await request(app.getHttpServer()).get('/v1/staff/lab-tests').set('Authorization', `Bearer ${superAdminToken}`).expect(200);
    expect(listed.body.find((row: { id: number }) => String(row.id) === String(id))).toMatchObject({ categoryId: general.id, categoryName: general.name, description: 'Updated member description' });
    const [listing] = await db.select().from(labPackage).where(eq(labPackage.sourceTestId, id));
    expect(listing.about).toBe('Updated member description');
    expect(listing.categoryId).toBe(general.id);
  });
  let labToken: string;
  let pharmacyToken: string;

  beforeAll(async () => {
    db = createTestDb();
    firebase = new FakeFirebaseVerifier();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DRIZZLE)
      .useValue(db)
      .overrideProvider(REDIS_CLIENT)
      .useValue(createTestRedis())
      .overrideProvider(FIREBASE_VERIFIER)
      .useValue(firebase)
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();

    async function staffToken(loginId: string, role: 'SUPERADMIN' | 'LAB' | 'PHARMACY') {
      await db.insert(adminUser).values({
        loginId,
        name: `${role} Staff`,
        passwordHash: await hash('correct-horse-battery-staple', 4), // low cost factor — this is a test, not production
        role,
      });
      const res = await request(app.getHttpServer())
        .post('/v1/staff/auth/session')
        .send({ loginId, password: 'correct-horse-battery-staple' })
        .expect(200);
      return res.body.accessToken as string;
    }

    superAdminToken = await staffToken('labtest-superadmin@example.com', 'SUPERADMIN');
    labToken = await staffToken('labtest-lab@example.com', 'LAB');
    pharmacyToken = await staffToken('labtest-pharmacy@example.com', 'PHARMACY');
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects a PHARMACY role from the Test Master — not in its module list', async () => {
    await request(app.getHttpServer())
      .get('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${pharmacyToken}`)
      .expect(403);
  });

  it('creates a TEST, lists it, and reads it back with its lisCode assigned', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ input: BLANK_INPUT, groupItems: [], specialRates: [] })
      .expect(201);
    expect(created.body.id).toBeTruthy();
    expect(created.body.lisCode).toBeGreaterThan(0);

    const list = await request(app.getHttpServer())
      .get('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${labToken}`)
      .expect(200);
    expect(list.body).toEqual(
      expect.arrayContaining([expect.objectContaining({ name: 'Blood Glucose Fasting', itemCount: 0, source: 'ADMIN' })]),
    );

    const got = await request(app.getHttpServer())
      .get(`/v1/staff/lab-tests/${created.body.id}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    expect(got.body.department).toBe('Biochemistry');
    expect(got.body.groupItems).toEqual([]);
    expect(got.body.specialRates).toEqual([]);
  });

  it('refuses a duplicate name, case-insensitively, without a 500', async () => {
    await request(app.getHttpServer())
      .post('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ input: { ...BLANK_INPUT, name: 'DUPE TEST' }, groupItems: [], specialRates: [] })
      .expect(201);
    const dupe = await request(app.getHttpServer())
      .post('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ input: { ...BLANK_INPUT, name: 'dupe test' }, groupItems: [], specialRates: [] })
      .expect(409);
    expect(dupe.body.error.message).toMatch(/already exists/i);
  });

  it('switches a test on with "Show in the app", syncing a member-facing app.lab_package listing', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ input: { ...BLANK_INPUT, name: 'Listed Test', showInApp: true, isActive: true, amount: 150, rate: 200 }, groupItems: [], specialRates: [] })
      .expect(201);

    const [listing] = await db.select().from(labPackage).where(eq(labPackage.sourceTestId, created.body.id));
    expect(listing).toBeDefined();
    expect(listing.slug).toBe('listed-test');
    expect(Number(listing.price)).toBe(150);
    expect(Number(listing.mrp)).toBe(200);
    expect(listing.isActive).toBe(true);

    // Switching showInApp off turns the listing off, never deletes it.
    await request(app.getHttpServer())
      .post(`/v1/staff/lab-tests/${created.body.id}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ input: { ...BLANK_INPUT, name: 'Listed Test', showInApp: false, isActive: true }, groupItems: [], specialRates: [] })
      .expect(201);
    const [afterOff] = await db.select().from(labPackage).where(eq(labPackage.sourceTestId, created.body.id));
    expect(afterOff.isActive).toBe(false);
  });

  it('creates a GROUP test with members, updates them (upsert + drop no-longer-listed), and refuses converting it back to a plain TEST while still used elsewhere', async () => {
    const memberA = await request(app.getHttpServer())
      .post('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ input: { ...BLANK_INPUT, name: 'Member Test A' }, groupItems: [], specialRates: [] })
      .expect(201);
    const memberB = await request(app.getHttpServer())
      .post('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ input: { ...BLANK_INPUT, name: 'Member Test B' }, groupItems: [], specialRates: [] })
      .expect(201);

    const group = await request(app.getHttpServer())
      .post('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({
        input: { ...BLANK_INPUT, name: 'Combo Group', testType: 'GROUP' },
        groupItems: [{ testId: memberA.body.id, amount: 100, setOrder: 0, isSubhead: false }],
        specialRates: [{ refLab: 'Metropolis', rate: 450 }],
      })
      .expect(201);

    const read = await request(app.getHttpServer())
      .get(`/v1/staff/lab-tests/${group.body.id}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    expect(read.body.groupItems).toHaveLength(1);
    expect(read.body.groupItems[0].name).toBe('Member Test A');
    expect(read.body.specialRates).toHaveLength(1);
    expect(read.body.specialRates[0].refLab).toBe('Metropolis');
    expect(Number(read.body.specialRates[0].rate)).toBe(450);

    // Member A tries to become a plain TEST again — but memberA alone has
    // no group pointing at it yet in this sub-test's own fixture scope, so
    // first prove the real guard: the GROUP itself can't demote while it
    // still has a member — no, the guard is "a member can't leave TEST
    // while used inside a group" on the MEMBER's own id.
    await request(app.getHttpServer())
      .post(`/v1/staff/lab-tests/${memberA.body.id}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ input: { ...BLANK_INPUT, name: 'Member Test A', testType: 'GROUP' }, groupItems: [], specialRates: [] })
      .expect(403);

    // Swap the group's membership to Member B instead, and clear the rate.
    await request(app.getHttpServer())
      .post(`/v1/staff/lab-tests/${group.body.id}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({
        input: { ...BLANK_INPUT, name: 'Combo Group', testType: 'GROUP' },
        groupItems: [{ testId: memberB.body.id, amount: 120, setOrder: 0, isSubhead: false }],
        specialRates: [],
      })
      .expect(201);
    const readAfter = await request(app.getHttpServer())
      .get(`/v1/staff/lab-tests/${group.body.id}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    expect(readAfter.body.groupItems).toEqual([expect.objectContaining({ name: 'Member Test B' })]);
    expect(readAfter.body.specialRates).toEqual([]);
  });

  it('refuses deleting a test still used inside a group, then deletes one with nothing referencing it', async () => {
    const member = await request(app.getHttpServer())
      .post('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ input: { ...BLANK_INPUT, name: 'Delete Guard Member' }, groupItems: [], specialRates: [] })
      .expect(201);
    await request(app.getHttpServer())
      .post('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({
        input: { ...BLANK_INPUT, name: 'Delete Guard Group', testType: 'GROUP' },
        groupItems: [{ testId: member.body.id, amount: 100, setOrder: 0, isSubhead: false }],
        specialRates: [],
      })
      .expect(201);

    const refused = await request(app.getHttpServer())
      .delete(`/v1/staff/lab-tests/${member.body.id}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(403);
    expect(refused.body.error.message).toMatch(/Delete Guard Group/);

    const lone = await request(app.getHttpServer())
      .post('/v1/staff/lab-tests')
      .set('Authorization', `Bearer ${superAdminToken}`)
      .send({ input: { ...BLANK_INPUT, name: 'Lone Test' }, groupItems: [], specialRates: [] })
      .expect(201);
    await request(app.getHttpServer())
      .delete(`/v1/staff/lab-tests/${lone.body.id}`)
      .set('Authorization', `Bearer ${superAdminToken}`)
      .expect(200);
    const [row] = await db.select().from(labTest).where(eq(labTest.id, lone.body.id));
    expect(row).toBeUndefined();
  });

  describe('field options (Department/Method/Sample/… pick lists)', () => {
    it('saving a test with a new value adds it to that field\'s list, without needing it added first', async () => {
      await request(app.getHttpServer())
        .post('/v1/staff/lab-tests')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ input: { ...BLANK_INPUT, name: 'Field option fixture', department: 'Serology Fixture' }, groupItems: [], specialRates: [] })
        .expect(201);

      const options = await request(app.getHttpServer())
        .get('/v1/staff/lab-tests/field-options')
        .set('Authorization', `Bearer ${labToken}`)
        .expect(200);
      expect(options.body.department).toEqual(
        expect.arrayContaining([expect.objectContaining({ value: 'Serology Fixture' })]),
      );
      // Saving the exact same value again does not duplicate the entry.
      expect(options.body.department.filter((o: { value: string }) => o.value === 'Serology Fixture')).toHaveLength(1);
    });

    it('can add, rename and delete an entry directly — never touching a test that already used the old text', async () => {
      const added = await request(app.getHttpServer())
        .post('/v1/staff/lab-tests/field-options')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ fieldKey: 'sample', value: 'Swab Fixture' })
        .expect(201);
      expect(added.body.value).toBe('Swab Fixture');

      const test = await request(app.getHttpServer())
        .post('/v1/staff/lab-tests')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ input: { ...BLANK_INPUT, name: 'Sample option fixture', sample: 'Swab Fixture' }, groupItems: [], specialRates: [] })
        .expect(201);

      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-tests/field-options/${added.body.id}`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ value: 'Swab (renamed) Fixture' })
        .expect(200);

      await request(app.getHttpServer())
        .delete(`/v1/staff/lab-tests/field-options/${added.body.id}`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);

      const options = await request(app.getHttpServer())
        .get('/v1/staff/lab-tests/field-options')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);
      expect(options.body.sample).not.toEqual(
        expect.arrayContaining([expect.objectContaining({ value: 'Swab (renamed) Fixture' })]),
      );

      // The test that already carried the old value keeps it untouched.
      const got = await request(app.getHttpServer())
        .get(`/v1/staff/lab-tests/${test.body.id}`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);
      expect(got.body.sample).toBe('Swab Fixture');
    });

    it('rejects a PHARMACY role, same as the rest of the Test Master', async () => {
      await request(app.getHttpServer())
        .get('/v1/staff/lab-tests/field-options')
        .set('Authorization', `Bearer ${pharmacyToken}`)
        .expect(403);
    });
  });

  describe('package builder', () => {
    it('lists every active TEST/GROUP for the picker, never a PACKAGE', async () => {
      await request(app.getHttpServer())
        .post('/v1/staff/lab-tests')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ input: { ...BLANK_INPUT, name: 'Picker Test', testType: 'TEST' }, groupItems: [], specialRates: [] })
        .expect(201);
      await request(app.getHttpServer())
        .post('/v1/staff/lab-tests')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ input: { ...BLANK_INPUT, name: 'Picker Package', testType: 'PACKAGE' }, groupItems: [], specialRates: [] })
        .expect(201);

      const picker = await request(app.getHttpServer())
        .get('/v1/staff/lab-packages/test-picker')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);
      expect(picker.body).toEqual(expect.arrayContaining([expect.objectContaining({ name: 'Picker Test' })]));
      expect(picker.body.some((r: { name: string }) => r.name === 'Picker Package')).toBe(false);
    });

    it('creates a package from a GROUP and a plain TEST, computing the real test_count from the group\'s own member count', async () => {
      const groupMember = await request(app.getHttpServer())
        .post('/v1/staff/lab-tests')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ input: { ...BLANK_INPUT, name: 'CBC Member 1' }, groupItems: [], specialRates: [] })
        .expect(201);
      const groupMember2 = await request(app.getHttpServer())
        .post('/v1/staff/lab-tests')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ input: { ...BLANK_INPUT, name: 'CBC Member 2' }, groupItems: [], specialRates: [] })
        .expect(201);
      const group = await request(app.getHttpServer())
        .post('/v1/staff/lab-tests')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({
          input: { ...BLANK_INPUT, name: 'CBC Group', testType: 'GROUP' },
          groupItems: [
            { testId: groupMember.body.id, amount: 50, setOrder: 0, isSubhead: false },
            { testId: groupMember2.body.id, amount: 50, setOrder: 1, isSubhead: false },
          ],
          specialRates: [],
        })
        .expect(201);
      const plainTest = await request(app.getHttpServer())
        .post('/v1/staff/lab-tests')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ input: { ...BLANK_INPUT, name: 'Standalone Marker' }, groupItems: [], specialRates: [] })
        .expect(201);

      const created = await request(app.getHttpServer())
        .post('/v1/staff/lab-packages')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({
          name: 'Builder Package',
          categoryId: '',
          price: 500,
          mrp: 700,
          forWhom: 'Adults',
          sample: 'Blood',
          preparation: 'Fasting',
          reportIn: 'Next Day',
          about: 'A builder-made package',
          testIds: [group.body.id, plainTest.body.id],
        })
        .expect(201);

      const [row] = await db.select().from(labPackage).where(eq(labPackage.id, Number(created.body.id)));
      expect(row.testCount).toBe(3); // the group's own 2 members + the 1 plain test
      expect(row.profileCount).toBe(2); // one row per chosen test/group
      expect(Number(row.saved)).toBe(200);

      const testIds = await request(app.getHttpServer())
        .get(`/v1/staff/lab-packages/${created.body.id}/test-ids`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);
      expect(testIds.body.map(Number)).toEqual([group.body.id, plainTest.body.id].map(Number));
    });

    it('lists staff packages (excluding one-test listings), sets active, and updates price', async () => {
      const list = await request(app.getHttpServer())
        .get('/v1/staff/lab-packages')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);
      expect(list.body).toEqual(expect.arrayContaining([expect.objectContaining({ name: 'Builder Package' })]));
      expect(list.body.some((p: { name: string }) => p.name === 'Listed Test')).toBe(false);

      const target = list.body.find((p: { name: string }) => p.name === 'Builder Package');

      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-packages/${target.id}/active`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ isActive: false })
        .expect(200);
      const [afterActive] = await db.select().from(labPackage).where(eq(labPackage.id, target.id));
      expect(afterActive.isActive).toBe(false);

      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-packages/${target.id}/price`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ price: 450, mrp: 600 })
        .expect(200);
      const [afterPrice] = await db.select().from(labPackage).where(eq(labPackage.id, target.id));
      expect(Number(afterPrice.price)).toBe(450);
      expect(Number(afterPrice.saved)).toBe(150);
    });

    it('updates a package build: price-only edit (testsChanged false) leaves its tests untouched; testsChanged true replaces them', async () => {
      const t1 = await request(app.getHttpServer())
        .post('/v1/staff/lab-tests')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ input: { ...BLANK_INPUT, name: 'Update Build Test 1' }, groupItems: [], specialRates: [] })
        .expect(201);
      const t2 = await request(app.getHttpServer())
        .post('/v1/staff/lab-tests')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ input: { ...BLANK_INPUT, name: 'Update Build Test 2' }, groupItems: [], specialRates: [] })
        .expect(201);

      const created = await request(app.getHttpServer())
        .post('/v1/staff/lab-packages')
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ name: 'Mutable Package', categoryId: '', price: 100, mrp: 150, forWhom: '', sample: '', preparation: '', reportIn: '', about: '', testIds: [t1.body.id] })
        .expect(201);

      // Price-only: testsChanged false — test link must survive untouched.
      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-packages/${created.body.id}`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ input: { name: 'Mutable Package', categoryId: '', price: 110, mrp: 150, forWhom: '', sample: '', preparation: '', reportIn: '', about: '' }, testsChanged: false })
        .expect(200);
      const idsAfterPriceEdit = await request(app.getHttpServer())
        .get(`/v1/staff/lab-packages/${created.body.id}/test-ids`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);
      expect(idsAfterPriceEdit.body.map(Number)).toEqual([Number(t1.body.id)]);

      // Now actually change the tests.
      await request(app.getHttpServer())
        .patch(`/v1/staff/lab-packages/${created.body.id}`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({ input: { name: 'Mutable Package', categoryId: '', price: 110, mrp: 150, forWhom: '', sample: '', preparation: '', reportIn: '', about: '', testIds: [t2.body.id] }, testsChanged: true })
        .expect(200);
      const idsAfterTestsEdit = await request(app.getHttpServer())
        .get(`/v1/staff/lab-packages/${created.body.id}/test-ids`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);
      expect(idsAfterTestsEdit.body.map(Number)).toEqual([Number(t2.body.id)]);
    });
  });
});
