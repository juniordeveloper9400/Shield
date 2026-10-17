import { BadRequestException, ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, asc, eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { labCharge } from '../../db/schema';
import type { LabChargeInput } from './lab-charges.dto';

type ChargeView = { id: number; name: string; kind: string; isActive: boolean } &
  Partial<Record<'amount' | 'distanceKm' | 'rateId' | 'firstKm' | 'firstAmount' | 'secondKm' | 'secondAmount' | 'extraPerKm', number>>;

function distanceAmount(distanceKm: number, rule: Record<string, number>): number {
  const amount = distanceKm <= rule.firstKm ? rule.firstAmount : distanceKm <= rule.secondKm ? rule.secondAmount
    : rule.secondAmount + Math.ceil(Math.round((distanceKm - rule.secondKm) * 1e6) / 1e6) * rule.extraPerKm;
  return Math.round(amount * 100) / 100;
}

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
      return await this.db.transaction(async tx => {
      let savedConfig: Record<string, number> = config;
      if (input.kind === 'KM') {
        const [rule] = await tx.select().from(labCharge)
          .where(and(eq(labCharge.kind, 'DISTANCE'), eq(labCharge.isActive, true))).for('share');
        if (!rule) throw new BadRequestException('Add or activate the home collection distance rate note before creating a km charge.');
        savedConfig = { ...rule.config, distanceKm: input.distanceKm, amount: distanceAmount(input.distanceKm, rule.config), rateId: rule.id };
      }
      const values = { name, kind, isActive, config: savedConfig };
      const [row] = id == null
        ? await tx.insert(labCharge).values(values).returning()
        : await tx.update(labCharge).set(values).where(eq(labCharge.id, id)).returning();
      if (!row) throw new NotFoundException('Charge not found');
      return { ...row.config, id: row.id, name: row.name, kind: row.kind, isActive: row.isActive };
      });
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
    const distance = !rule ? 0 : distanceAmount(distanceKm, rule as unknown as Record<string, number>);
    return { technician, distance: Math.round(distance * 100) / 100,
      total: Math.round((technician + distance) * 100) / 100, distanceKm, estimateOnly: true };
  }
}
