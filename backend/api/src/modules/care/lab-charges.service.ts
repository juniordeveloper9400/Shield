import { ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { asc, eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { labCharge } from '../../db/schema';
import type { LabChargeInput } from './lab-charges.dto';

type ChargeView = { id: number; name: string; kind: string; isActive: boolean } &
  Partial<Record<'amount' | 'firstKm' | 'firstAmount' | 'secondKm' | 'secondAmount' | 'extraPerKm', number>>;

@Injectable()
export class LabChargesService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  async list(): Promise<ChargeView[]> {
    return (await this.db.select().from(labCharge).orderBy(asc(labCharge.id)))
      .map(row => ({ ...row.config, id: row.id, name: row.name, kind: row.kind, isActive: row.isActive }));
  }

  async save(id: number | null, input: LabChargeInput) {
    const { name, kind, isActive, ...config } = input;
    try {
      const values = { name, kind, isActive, config };
      const [row] = id == null
        ? await this.db.insert(labCharge).values(values).returning()
        : await this.db.update(labCharge).set(values).where(eq(labCharge.id, id)).returning();
      if (!row) throw new NotFoundException('Charge not found');
      return { ...row.config, id: row.id, name: row.name, kind: row.kind, isActive: row.isActive };
    } catch (error) {
      const e = error as { code?: string; cause?: { code?: string } };
      if (e.code === '23505' || e.cause?.code === '23505') {
        throw new ConflictException('Only one active charge of each type is allowed. Deactivate the existing charge first.');
      }
      throw error;
    }
  }

  async remove(id: number) {
    const [row] = await this.db.delete(labCharge).where(eq(labCharge.id, id)).returning({ id: labCharge.id });
    if (!row) throw new NotFoundException('Charge not found');
    return { deleted: true };
  }

  async preview(distanceKm: number) {
    const active = (await this.list()).filter(row => row.isActive);
    const tech = active.find(row => row.kind === 'TECHNICIAN');
    const rule = active.find(row => row.kind === 'DISTANCE');
    const technician = Number(tech?.amount ?? 0);
    const distance = !rule ? 0 : distanceKm <= Number(rule.firstKm) ? Number(rule.firstAmount)
      : distanceKm <= Number(rule.secondKm) ? Number(rule.secondAmount)
      // Normalize below-millimetre floating-point noise before rounding a started km.
      : Number(rule.secondAmount) + Math.ceil(Math.round((distanceKm - Number(rule.secondKm)) * 1e6) / 1e6) * Number(rule.extraPerKm);
    return { technician, distance: Math.round(distance * 100) / 100,
      total: Math.round((technician + distance) * 100) / 100, distanceKm, estimateOnly: true };
  }
}
