import { ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { adminUser, shieldStore } from '../../db/schema';
import type { CreateStaffDto, UpdateStaffDto } from './dto';

/**
 * The only place app.admin_user rows get created now — replaces the static
 * credential list in shieldweb/src/config/admins.ts. A new staff account
 * has no firebase_uid until their first login links it by matching email —
 * see auth.service.ts exchangeStaffToken.
 */
@Injectable()
export class AdminService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  /** Includes the store's `code` (e.g. 'SHD-MEL'), not just its id — see identity.service.ts getStaffProfile for the same pattern. */
  async listStaff() {
    return this.db
      .select({
        id: adminUser.id,
        uuid: adminUser.uuid,
        email: adminUser.email,
        name: adminUser.name,
        role: adminUser.role,
        storeId: adminUser.storeId,
        storeCode: shieldStore.code,
        isActive: adminUser.isActive,
        lastLoginAt: adminUser.lastLoginAt,
        createdAt: adminUser.createdAt,
      })
      .from(adminUser)
      .leftJoin(shieldStore, eq(adminUser.storeId, shieldStore.id))
      .orderBy(adminUser.name);
  }

  async createStaff(dto: CreateStaffDto) {
    try {
      const [created] = await this.db.insert(adminUser).values(dto).returning();
      return created;
    } catch {
      throw new ConflictException({
        error: { code: 'CONFLICT', message: 'A staff account with this email already exists' },
      });
    }
  }

  async updateStaff(id: number, dto: UpdateStaffDto) {
    const [updated] = await this.db.update(adminUser).set(dto).where(eq(adminUser.id, id)).returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Staff account not found' } });
    return updated;
  }
}
