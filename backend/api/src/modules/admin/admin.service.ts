import { ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { hash } from 'bcryptjs';
import { eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { adminUser, shieldStore } from '../../db/schema';
import type { CreateStaffDto, UpdateStaffDto } from './dto';

const BCRYPT_ROUNDS = 12;

/** Every response shape here (list + create + update) selects explicit columns — passwordHash must never reach a client, not even in a "just created it" response. */
const STAFF_COLUMNS = {
  id: adminUser.id,
  uuid: adminUser.uuid,
  email: adminUser.email,
  name: adminUser.name,
  role: adminUser.role,
  storeId: adminUser.storeId,
  isActive: adminUser.isActive,
  lastLoginAt: adminUser.lastLoginAt,
  createdAt: adminUser.createdAt,
} as const;

/**
 * The only place app.admin_user rows get created now — replaces the static
 * credential list in shieldweb/src/config/admins.ts. Staff log in with
 * email + password (see auth.service.ts loginStaff) — no Firebase account
 * needed for staff at all.
 */
@Injectable()
export class AdminService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  /** Includes the store's `code` (e.g. 'SHD-MEL'), not just its id — see identity.service.ts getStaffProfile for the same pattern. */
  async listStaff() {
    return this.db
      .select({ ...STAFF_COLUMNS, storeCode: shieldStore.code })
      .from(adminUser)
      .leftJoin(shieldStore, eq(adminUser.storeId, shieldStore.id))
      .orderBy(adminUser.name);
  }

  async createStaff(dto: CreateStaffDto) {
    const { password, ...rest } = dto;
    const passwordHash = await hash(password, BCRYPT_ROUNDS);

    try {
      const [created] = await this.db.insert(adminUser).values({ ...rest, passwordHash }).returning(STAFF_COLUMNS);
      return created;
    } catch {
      throw new ConflictException({
        error: { code: 'CONFLICT', message: 'A staff account with this email already exists' },
      });
    }
  }

  async updateStaff(id: number, dto: UpdateStaffDto) {
    const { password, ...rest } = dto;
    const values: typeof rest & { passwordHash?: string } = { ...rest };
    if (password) values.passwordHash = await hash(password, BCRYPT_ROUNDS);

    const [updated] = await this.db.update(adminUser).set(values).where(eq(adminUser.id, id)).returning(STAFF_COLUMNS);
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Staff account not found' } });
    return updated;
  }
}
