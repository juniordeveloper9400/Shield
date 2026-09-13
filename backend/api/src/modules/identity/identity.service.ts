import { ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, eq, isNull } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { adminUser, memberAddress, patient, shieldStore, users } from '../../db/schema';
import type { CreateAddressDto, CreatePatientDto } from './dto';

/**
 * Every query here is scoped to the calling member's own id, resolved from
 * the verified session — never from a client-supplied id. This is the
 * concrete "own-resource" enforcement backend/docs/frd.md §1 calls for.
 */
@Injectable()
export class IdentityService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

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
        homeStoreId: users.homeStoreId,
        rewardPoints: users.rewardPoints,
        registrationCompletedAt: users.registrationCompletedAt,
      })
      .from(users)
      .where(and(eq(users.id, memberId), isNull(users.deletedAt)))
      .limit(1);

    if (!member) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Member not found' } });
    return member;
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
        email: adminUser.email,
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
