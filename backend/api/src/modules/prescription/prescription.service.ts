import { ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, desc, eq } from 'drizzle-orm';
import { randomUUID } from 'node:crypto';
import { DRIZZLE, type Database } from '../../db/client';
import { patient, prescription, prescriptionMedicine, users } from '../../db/schema';
import { OBJECT_STORAGE, type ObjectStorage } from '../../storage/object-storage';
import type { AdminRole } from '../auth/session.types';
import { assertLegalPrescriptionTransition, type PrescriptionStatus } from './prescription-status';
import type { AddMedicineLineDto, UpdateMedicineStatusDto, UpdatePrescriptionStatusDto, UploadPrescriptionDto } from './dto';

const SIGNED_URL_TTL_SECONDS = 5 * 60;

/** Strips the pharmacist-only stock field — see db/schema/app-prescription.ts. */
function toMemberMedicine(line: typeof prescriptionMedicine.$inferSelect) {
  const { status: _status, ...rest } = line;
  return rest;
}

@Injectable()
export class PrescriptionService {
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
  ) {}

  async upload(memberId: number, dto: UploadPrescriptionDto) {
    const [owned] = await this.db
      .select({ id: patient.id })
      .from(patient)
      .where(and(eq(patient.id, dto.patientId), eq(patient.memberId, memberId)))
      .limit(1);
    if (!owned) {
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'patientId does not belong to this member' } });
    }

    const [member] = await this.db.select({ homeStoreId: users.homeStoreId }).from(users).where(eq(users.id, memberId)).limit(1);

    const match = /^data:(image\/(?:png|jpe?g));base64,(.+)$/.exec(dto.image);
    if (!match) {
      throw new ForbiddenException({ error: { code: 'VALIDATION_ERROR', message: 'Malformed image data URI' } });
    }
    const [, contentType, base64] = match;
    const buffer = Buffer.from(base64, 'base64');
    const extension = contentType === 'image/png' ? 'png' : 'jpg';
    const storagePath = `prescriptions/${memberId}/${randomUUID()}.${extension}`;
    await this.storage.put(storagePath, buffer, contentType);

    const [created] = await this.db
      .insert(prescription)
      .values({
        memberId,
        patientId: dto.patientId,
        storeId: member?.homeStoreId ?? null,
        code: `RX-${Date.now().toString(36).toUpperCase()}`,
        fileName: dto.fileName,
        storagePath,
        doctor: dto.doctor,
        duration: dto.duration,
        customDays: dto.customDays,
      })
      .returning();

    return this.toMemberView(created);
  }

  async listForMember(memberId: number) {
    const rows = await this.db
      .select()
      .from(prescription)
      .where(eq(prescription.memberId, memberId))
      .orderBy(desc(prescription.createdAt));
    return Promise.all(rows.map((row) => this.toMemberView(row)));
  }

  async getForMember(memberId: number, id: number) {
    const found = await this.getOwnedByMemberOrThrow(id, memberId);
    const lines = await this.db.select().from(prescriptionMedicine).where(eq(prescriptionMedicine.prescriptionId, id));
    return { ...(await this.toMemberView(found)), medicines: lines.map(toMemberMedicine) };
  }

  async listForStaff(role: AdminRole, storeId: number | null) {
    const rows =
      role === 'SUPERADMIN'
        ? await this.db.select().from(prescription).orderBy(desc(prescription.createdAt))
        : storeId == null
          ? []
          : await this.db
              .select()
              .from(prescription)
              .where(eq(prescription.storeId, storeId))
              .orderBy(desc(prescription.createdAt));
    return Promise.all(rows.map((row) => this.toStaffView(row)));
  }

  async getForStaff(role: AdminRole, storeId: number | null, id: number) {
    const found = await this.getOwnedByStaffOrThrow(id, role, storeId);
    const lines = await this.db.select().from(prescriptionMedicine).where(eq(prescriptionMedicine.prescriptionId, id));
    return { ...(await this.toStaffView(found)), medicines: lines };
  }

  async addMedicineLine(role: AdminRole, storeId: number | null, prescriptionId: number, dto: AddMedicineLineDto) {
    await this.getOwnedByStaffOrThrow(prescriptionId, role, storeId);
    const [line] = await this.db.insert(prescriptionMedicine).values({ ...dto, prescriptionId }).returning();
    return line;
  }

  async updateMedicineStatus(
    role: AdminRole,
    storeId: number | null,
    prescriptionId: number,
    medicineId: number,
    dto: UpdateMedicineStatusDto,
  ) {
    await this.getOwnedByStaffOrThrow(prescriptionId, role, storeId);
    const [updated] = await this.db
      .update(prescriptionMedicine)
      .set({ status: dto.status })
      .where(and(eq(prescriptionMedicine.id, medicineId), eq(prescriptionMedicine.prescriptionId, prescriptionId)))
      .returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Medicine line not found' } });
    return updated;
  }

  async updateStatus(role: AdminRole, storeId: number | null, id: number, dto: UpdatePrescriptionStatusDto) {
    const found = await this.getOwnedByStaffOrThrow(id, role, storeId);
    assertLegalPrescriptionTransition(found.status as PrescriptionStatus, dto.status);

    const [updated] = await this.db
      .update(prescription)
      .set({ status: dto.status, reviewedAt: found.reviewedAt ?? new Date() })
      .where(eq(prescription.id, id))
      .returning();
    return this.toStaffView(updated);
  }

  // ---- internal ----------------------------------------------------------

  private async getOwnedByMemberOrThrow(id: number, memberId: number) {
    const [found] = await this.db
      .select()
      .from(prescription)
      .where(and(eq(prescription.id, id), eq(prescription.memberId, memberId)))
      .limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Prescription not found' } });
    return found;
  }

  private async getOwnedByStaffOrThrow(id: number, role: AdminRole, storeId: number | null) {
    const conditions = [eq(prescription.id, id)];
    if (role !== 'SUPERADMIN') {
      if (storeId == null) {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Staff account has no store assigned' } });
      }
      conditions.push(eq(prescription.storeId, storeId));
    }
    const [found] = await this.db
      .select()
      .from(prescription)
      .where(and(...conditions))
      .limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Prescription not found' } });
    return found;
  }

  private async signedImageUrl(storagePath: string | null): Promise<string | null> {
    if (!storagePath) return null;
    return this.storage.getSignedReadUrl(storagePath, SIGNED_URL_TTL_SECONDS);
  }

  private async toMemberView(row: typeof prescription.$inferSelect) {
    const { storagePath: _storagePath, image: _image, ...rest } = row;
    return { ...rest, imageUrl: await this.signedImageUrl(row.storagePath) };
  }

  private async toStaffView(row: typeof prescription.$inferSelect) {
    const { storagePath: _storagePath, image: _image, ...rest } = row;
    return { ...rest, imageUrl: await this.signedImageUrl(row.storagePath) };
  }
}
