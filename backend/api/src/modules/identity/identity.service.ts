import { ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, eq, isNull } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { adminUser, memberAddress, patient, rewardPointTransaction, shieldStore, users } from '../../db/schema';
import { AuthService } from '../auth/auth.service';
import type { CreateAddressDto, CreatePatientDto, UpdateMemberProfileDto, UpdatePatientDto } from './dto';

/** Credited once, the first time a member completes registration. Mirrors the client's own display constant (`RewardsService.registrationBonus`). */
const REGISTRATION_BONUS_POINTS = 500;

/**
 * Every query here is scoped to the calling member's own id, resolved from
 * the verified session — never from a client-supplied id. This is the
 * concrete "own-resource" enforcement backend/docs/frd.md §1 calls for.
 */
@Injectable()
export class IdentityService {
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    private readonly auth: AuthService,
  ) {}

  async getMemberProfile(memberId: number) {
    const [member] = await this.db
      .select({
        id: users.id,
        uuid: users.uuid,
        phone: users.phone,
        name: users.name,
        email: users.email,
        gender: users.gender,
        dob: users.dob,
        address: users.address,
        place: users.place,
        pincode: users.pincode,
        state: users.state,
        homeStoreId: users.homeStoreId,
        // The branch's code whether or not the branch is still active — a
        // member's registration must read back the same after a branch is
        // switched off, and the apps' public store list only carries active ones.
        homeStoreCode: shieldStore.code,
        rewardPoints: users.rewardPoints,
        registrationCompletedAt: users.registrationCompletedAt,
      })
      .from(users)
      .leftJoin(shieldStore, eq(shieldStore.id, users.homeStoreId))
      .where(and(eq(users.id, memberId), isNull(users.deletedAt)))
      .limit(1);

    if (!member) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Member not found' } });
    return member;
  }

  /**
   * The branch a profile save names, by code or id — or undefined when it names
   * none. A branch must exist, and must be active to be *newly* chosen; a
   * member may always keep the branch they already have, so editing a
   * profile keeps working after that branch is switched off.
   */
  private async resolveHomeStore(memberId: number, dto: UpdateMemberProfileDto): Promise<number | undefined> {
    if (dto.homeStoreCode === undefined && dto.homeStoreId === undefined) return undefined;

    const [store] = await this.db
      .select({ id: shieldStore.id, isActive: shieldStore.isActive })
      .from(shieldStore)
      .where(dto.homeStoreCode !== undefined ? eq(shieldStore.code, dto.homeStoreCode) : eq(shieldStore.id, dto.homeStoreId!))
      .limit(1);
    if (!store) {
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'The home store is not a known store' } });
    }
    if (!store.isActive) {
      const [current] = await this.db
        .select({ homeStoreId: users.homeStoreId })
        .from(users)
        .where(eq(users.id, memberId))
        .limit(1);
      if (current?.homeStoreId !== store.id) {
        throw new ForbiddenException({
          error: {
            code: 'STORE_UNAVAILABLE',
            message: "That branch isn't taking new registrations right now. Choose another branch.",
          },
        });
      }
    }
    return store.id;
  }

  /**
   * Registration save / profile edit. `registrationCompletedAt` is set by
   * the server the first time this succeeds for a member (never by the
   * client) — and in the same transaction, that exact null → non-null
   * transition is what credits the one-time registration bonus, replacing
   * the client's own `isFirst` + separate ledger `once` guard with a single
   * atomic check here.
   */
  async updateProfile(memberId: number, dto: UpdateMemberProfileDto) {
    const homeStoreId = await this.resolveHomeStore(memberId, dto);
    // The store arrives as a code or an id; only the resolved id is written.
    const { homeStoreCode: _code, homeStoreId: _id, ...profile } = dto;
    void _code;
    void _id;

    return this.db.transaction(async (tx) => {
      const [before] = await tx
        .select({ registrationCompletedAt: users.registrationCompletedAt })
        .from(users)
        .where(and(eq(users.id, memberId), isNull(users.deletedAt)))
        .limit(1);
      if (!before) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Member not found' } });

      const isFirstCompletion = before.registrationCompletedAt === null;

      const [updated] = await tx
        .update(users)
        .set({
          ...profile,
          ...(homeStoreId !== undefined ? { homeStoreId } : {}),
          ...(isFirstCompletion ? { registrationCompletedAt: new Date() } : {}),
          updatedAt: new Date(),
        })
        .where(eq(users.id, memberId))
        .returning({
          id: users.id,
          uuid: users.uuid,
          phone: users.phone,
          name: users.name,
          email: users.email,
          gender: users.gender,
          dob: users.dob,
          address: users.address,
          place: users.place,
          pincode: users.pincode,
          state: users.state,
          homeStoreId: users.homeStoreId,
          rewardPoints: users.rewardPoints,
          registrationCompletedAt: users.registrationCompletedAt,
        });

      if (isFirstCompletion) {
        await tx.insert(rewardPointTransaction).values({
          memberId,
          points: REGISTRATION_BONUS_POINTS,
          reason: 'REGISTRATION',
          note: 'Registration bonus',
        });
        await tx
          .update(users)
          .set({ rewardPoints: updated.rewardPoints + REGISTRATION_BONUS_POINTS })
          .where(eq(users.id, memberId));
        updated.rewardPoints += REGISTRATION_BONUS_POINTS;
      }

      const [store] =
        updated.homeStoreId === null
          ? []
          : await tx.select({ code: shieldStore.code }).from(shieldStore).where(eq(shieldStore.id, updated.homeStoreId)).limit(1);
      return { ...updated, homeStoreCode: store?.code ?? null };
    });
  }

  /**
   * A member's own "delete my account" — soft: `deletedAt` is stamped
   * rather than the row removed, so every order/wallet/bill row with an FK
   * to `app.users(id)` keeps its history intact for accounting instead of
   * being wiped or orphaned. `phone` is kept — it's the unique key a later
   * re-registration on the same number reactivates against (see
   * `AuthService.registerMember`'s own doc) — but every other personal
   * field is cleared, since a member who asked to be deleted should not
   * have their name/DOB/address still sitting there just because the row
   * lives on for its order history. Matches
   * `lib/data/neon/member_repository.dart`'s `deleteAccount` exactly, the
   * Neon-direct version of this same operation it replaces.
   *
   * Deliberately more than the admin console's own user delete
   * (`shieldweb/src/api/users.ts`), which only stamps `deletedAt` — an
   * admin revoking access may need the full record intact (a suspension, a
   * dispute), where a member's own delete is a privacy request the fields
   * themselves should not survive.
   *
   * Also revokes every live session for this member — see the module's own
   * doc on why `AuthModule` is imported here.
   */
  async deleteAccount(memberId: number): Promise<void> {
    const [deleted] = await this.db
      .update(users)
      .set({
        name: 'Deleted user',
        email: null,
        gender: null,
        dob: null,
        address: null,
        place: null,
        pincode: null,
        state: null,
        firebaseUid: null,
        deletedAt: new Date(),
        updatedAt: new Date(),
      })
      .where(and(eq(users.id, memberId), isNull(users.deletedAt)))
      .returning({ id: users.id });
    if (!deleted) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Member not found' } });

    await this.auth.revokeAllSessions('MEMBER', String(memberId));
  }

  async listAddresses(memberId: number) {
    return this.db
      .select()
      .from(memberAddress)
      .where(and(eq(memberAddress.memberId, memberId), isNull(memberAddress.deletedAt)));
  }

  async createAddress(memberId: number, dto: CreateAddressDto) {
    if (dto.patientId) {
      const [owned] = await this.db
        .select({ id: patient.id })
        .from(patient)
        .where(and(eq(patient.id, dto.patientId), eq(patient.memberId, memberId), isNull(patient.deletedAt)))
        .limit(1);
      if (!owned) {
        throw new ForbiddenException({
          error: { code: 'FORBIDDEN', message: 'patientId does not belong to the authenticated member' },
        });
      }
    }

    const [created] = await this.db
      .insert(memberAddress)
      .values({ ...dto, memberId })
      .returning();
    return created;
  }

  async listPatients(memberId: number) {
    return this.db.select().from(patient).where(and(eq(patient.memberId, memberId), isNull(patient.deletedAt)));
  }

  async createPatient(memberId: number, dto: CreatePatientDto) {
    const [created] = await this.db.insert(patient).values({ ...dto, memberId }).returning();
    return created;
  }

  async updatePatient(memberId: number, patientId: number, dto: UpdatePatientDto) {
    const [updated] = await this.db
      .update(patient)
      .set(dto)
      .where(and(eq(patient.id, patientId), eq(patient.memberId, memberId), isNull(patient.deletedAt)))
      .returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Patient not found' } });
    return updated;
  }

  async softDeletePatient(memberId: number, patientId: number) {
    const [deleted] = await this.db
      .update(patient)
      .set({ deletedAt: new Date() })
      .where(and(eq(patient.id, patientId), eq(patient.memberId, memberId), isNull(patient.deletedAt)))
      .returning();
    if (!deleted) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Patient not found' } });
  }

  /**
   * Includes the store's `code` (e.g. 'SHD-MEL'), not just its numeric id —
   * shieldweb's scopeToStore() (src/config/permissions.ts) has always
   * compared by store code, so the console needs it directly rather than
   * making a second round trip.
   */
  async getStaffProfile(staffId: number) {
    const [staff] = await this.db
      .select({
        id: adminUser.id,
        uuid: adminUser.uuid,
        loginId: adminUser.loginId,
        name: adminUser.name,
        role: adminUser.role,
        storeId: adminUser.storeId,
        storeCode: shieldStore.code,
        isActive: adminUser.isActive,
      })
      .from(adminUser)
      .leftJoin(shieldStore, eq(adminUser.storeId, shieldStore.id))
      .where(eq(adminUser.id, staffId))
      .limit(1);

    if (!staff) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Staff account not found' } });
    return staff;
  }
}
