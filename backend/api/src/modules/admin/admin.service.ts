import { BadRequestException, ConflictException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { hash } from 'bcryptjs';
import { eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { adminUser, shieldStore } from '../../db/schema';
import type { AdminRole } from '../auth/session.types';
import type { CreateStaffDto, UpdateStaffDto } from './dto';

const BCRYPT_ROUNDS = 12;

/** Roles that need the branch to actually run that side of the business —
 *  mirrors shieldweb's AdminsPage.tsx PHARMACY_CAPABLE_ROLES/LAB_CAPABLE_ROLES,
 *  checked again here so the rule holds even against a caller that skips
 *  the console's own UI. */
const PHARMACY_CAPABLE_ROLES: AdminRole[] = ['PHARMACY', 'DELIVERY'];
const LAB_CAPABLE_ROLES: AdminRole[] = ['LAB_TECHNICIAN'];

/** Every response shape here (list + create + update) selects explicit columns — passwordHash must never reach a client, not even in a "just created it" response. */
const STAFF_COLUMNS = {
  id: adminUser.id,
  uuid: adminUser.uuid,
  loginId: adminUser.loginId,
  name: adminUser.name,
  role: adminUser.role,
  storeId: adminUser.storeId,
  modules: adminUser.modules,
  isActive: adminUser.isActive,
  lastLoginAt: adminUser.lastLoginAt,
  createdAt: adminUser.createdAt,
} as const;

/**
 * The only place app.admin_user rows get created now — replaces the static
 * credential list in shieldweb/src/config/admins.ts. Staff log in with a
 * login id + password (see auth.service.ts loginStaff) — no Firebase
 * account needed for staff at all, and no email format required.
 */
@Injectable()
export class AdminService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  /** Includes the store's `code` (e.g. 'SHD-MEL'), not just its id — see identity.service.ts getStaffProfile for the same pattern. Narrowed to one branch's own logins when `storeId` is given — the Stores page's own per-branch "Staff logins" table. */
  async listStaff(storeId?: number) {
    return this.db
      .select({ ...STAFF_COLUMNS, storeCode: shieldStore.code })
      .from(adminUser)
      .leftJoin(shieldStore, eq(adminUser.storeId, shieldStore.id))
      .where(storeId !== undefined ? eq(adminUser.storeId, storeId) : undefined)
      .orderBy(adminUser.name);
  }

  /** An ADMIN caller may open store-bound/operational logins only — console-
   *  wide access (another SUPERADMIN or ADMIN account) stays SUPERADMIN-only,
   *  so ADMIN can staff a branch without being able to mint its own peers. */
  private assertRoleGrantAllowed(callerRole: AdminRole | undefined, grantedRole: AdminRole) {
    if (callerRole === 'ADMIN' && (grantedRole === 'SUPERADMIN' || grantedRole === 'ADMIN')) {
      throw new ForbiddenException({
        error: { code: 'FORBIDDEN', message: 'Only a Super Admin can create or change a Super Admin/Admin account' },
      });
    }
  }

  /** Throws when [role] doesn't fit [storeId]'s branch — e.g. a Lab
   *  Technician at a branch set up as a Standalone Pharmacy. A no-op for a
   *  role this check doesn't apply to, or when [storeId] is unset. */
  private async assertRoleFitsStore(role: AdminRole, storeId: number | null | undefined) {
    if (storeId == null) return;
    if (!PHARMACY_CAPABLE_ROLES.includes(role) && !LAB_CAPABLE_ROLES.includes(role)) return;
    const [store] = await this.db.select({ storeType: shieldStore.storeType }).from(shieldStore).where(eq(shieldStore.id, storeId)).limit(1);
    if (!store) return; // Not found at all — the FK/NotFoundException elsewhere is the real signal.
    if (PHARMACY_CAPABLE_ROLES.includes(role) && store.storeType === 'LAB') {
      throw new BadRequestException({
        error: { code: 'BAD_REQUEST', message: 'This role needs a branch that handles pharmacy orders — that branch is set up as a Standalone Lab.' },
      });
    }
    if (LAB_CAPABLE_ROLES.includes(role) && store.storeType === 'PHARMACY') {
      throw new BadRequestException({
        error: { code: 'BAD_REQUEST', message: 'This role needs a branch that takes lab bookings — that branch is set up as a Standalone Pharmacy.' },
      });
    }
  }

  async createStaff(dto: CreateStaffDto, callerRole: AdminRole | undefined) {
    this.assertRoleGrantAllowed(callerRole, dto.role);
    await this.assertRoleFitsStore(dto.role, dto.storeId);
    const { password, ...rest } = dto;
    const passwordHash = await hash(password, BCRYPT_ROUNDS);

    try {
      const [created] = await this.db.insert(adminUser).values({ ...rest, passwordHash }).returning(STAFF_COLUMNS);
      return created;
    } catch {
      throw new ConflictException({
        error: { code: 'CONFLICT', message: 'A staff account with this login id already exists' },
      });
    }
  }

  async updateStaff(id: number, dto: UpdateStaffDto, callerRole: AdminRole | undefined) {
    if (dto.role) this.assertRoleGrantAllowed(callerRole, dto.role);
    // Fetched once, reused for both the ADMIN-escalation check below and the
    // role/store-type check — whichever of role/storeId isn't in this patch
    // still comes from what's already on record, same merge-before-check
    // pattern CatalogueService.updateProduct uses for discountLabel.
    const [existing] = await this.db.select({ role: adminUser.role, storeId: adminUser.storeId }).from(adminUser).where(eq(adminUser.id, id));
    if (callerRole === 'ADMIN' && existing && (existing.role === 'SUPERADMIN' || existing.role === 'ADMIN')) {
      throw new ForbiddenException({
        error: { code: 'FORBIDDEN', message: 'Only a Super Admin can change a Super Admin/Admin account' },
      });
    }
    const effectiveRole = dto.role ?? existing?.role;
    if (effectiveRole && (dto.role || dto.storeId !== undefined)) {
      await this.assertRoleFitsStore(effectiveRole, dto.storeId !== undefined ? dto.storeId : existing?.storeId);
    }
    const { password, ...rest } = dto;
    const values: typeof rest & { passwordHash?: string } = { ...rest };
    if (password) values.passwordHash = await hash(password, BCRYPT_ROUNDS);

    const [updated] = await this.db.update(adminUser).set(values).where(eq(adminUser.id, id)).returning(STAFF_COLUMNS);
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Staff account not found' } });
    return updated;
  }
}
