import { ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, asc, desc, eq, inArray, isNull } from 'drizzle-orm';
import { randomBytes } from 'node:crypto';
import { DRIZZLE, type Database } from '../../db/client';
import {
  memberAddress,
  order,
  orderTrackStep,
  patient,
  prescription,
  prescriptionImage,
  prescriptionMedicine,
  prescriptionOrder,
  users,
} from '../../db/schema';
import type { AdminRole } from '../auth/session.types';
import { assertLegalPrescriptionTransition, type PrescriptionStatus } from './prescription-status';
import type {
  AddMedicineLineDto,
  SetPrescriptionImageRotationDto,
  SubmitPrescriptionOrderDto,
  UpdateMedicineStatusDto,
  UpdatePrescriptionStatusDto,
  UploadPrescriptionDto,
} from './dto';

/** The same track-step graph the old direct-Neon `savePrescriptionOrder` seeded — see order_repository.dart's `_prescriptionStages`. */
const PRESCRIPTION_ORDER_STAGES = [
  'Prescription received',
  'Pharmacist review',
  'Order confirmed',
  'Dispatched',
  'Delivered',
];

/** Strips the pharmacist-only stock field — see db/schema/app-prescription.ts. */
function toMemberMedicine(line: typeof prescriptionMedicine.$inferSelect) {
  const { status: _status, ...rest } = line;
  return rest;
}

@Injectable()
export class PrescriptionService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

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

    const images = dto.images ?? [];
    for (const image of images) {
      if (!/^data:image\/(?:png|jpe?g);base64,.+$/.test(image)) {
        throw new ForbiddenException({ error: { code: 'VALIDATION_ERROR', message: 'Malformed image data URI' } });
      }
    }

    return this.db.transaction(async (tx) => {
      const [created] = await tx
        .insert(prescription)
        .values({
          memberId,
          patientId: dto.patientId,
          storeId: member?.homeStoreId ?? null,
          code: `RX-${Date.now().toString(36).toUpperCase()}`,
          fileName: dto.fileName,
          doctor: dto.doctor,
          duration: dto.duration,
          customDays: dto.customDays,
          recurringFrom: dto.recurringFrom,
          recurringUntil: dto.recurringUntil,
        })
        .returning();

      const insertedImages =
        images.length > 0
          ? await tx
              .insert(prescriptionImage)
              .values(images.map((image, sort) => ({ prescriptionId: created.id, sort, image })))
              .returning()
          : [];

      return this.toMemberView(created, insertedImages);
    });
  }

  /**
   * Submits one or more uploaded prescriptions for fulfilment: one unpriced
   * `order` (kind `PRESCRIPTION`, `mrpTotal`/`paidTotal` both `0` — a
   * pharmacist prices it at the counter, this is not a checkout), the same
   * five-stage track-step graph the old direct-Neon `savePrescriptionOrder`
   * seeded, a `prescriptionOrder` link row per prescription, and each
   * prescription's own `status` moved to `ORDERED`. Mirrors
   * `OrderRepository.savePrescriptionOrder` + `PrescriptionRepository.
   * markOrdered` exactly — no pricing or payment logic invented.
   */
  async submitForOrder(memberId: number, dto: SubmitPrescriptionOrderDto) {
    const owned = await this.db
      .select({ id: prescription.id, status: prescription.status })
      .from(prescription)
      .where(and(inArray(prescription.id, dto.prescriptionIds), eq(prescription.memberId, memberId)));
    if (owned.length !== dto.prescriptionIds.length) {
      throw new ForbiddenException({
        error: { code: 'FORBIDDEN', message: 'One or more prescriptionIds do not belong to this member' },
      });
    }

    if (dto.addressId !== undefined) {
      const [ownedAddress] = await this.db
        .select({ id: memberAddress.id })
        .from(memberAddress)
        .where(and(eq(memberAddress.id, dto.addressId), eq(memberAddress.memberId, memberId), isNull(memberAddress.deletedAt)))
        .limit(1);
      if (!ownedAddress) {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'addressId does not belong to this member' } });
      }
    }

    const medicineCounts = await this.db
      .select({ prescriptionId: prescriptionMedicine.prescriptionId })
      .from(prescriptionMedicine)
      .where(inArray(prescriptionMedicine.prescriptionId, dto.prescriptionIds));
    const itemCount = medicineCounts.length > 0 ? medicineCounts.length : dto.prescriptionIds.length;

    const [member] = await this.db.select({ homeStoreId: users.homeStoreId }).from(users).where(eq(users.id, memberId)).limit(1);

    return this.db.transaction(async (tx) => {
      const [created] = await tx
        .insert(order)
        .values({
          memberId,
          code: `RX-${Date.now().toString(36).toUpperCase()}${randomBytes(2).toString('hex').toUpperCase()}`,
          kind: 'PRESCRIPTION',
          itemCount,
          mrpTotal: '0',
          paidTotal: '0',
          storeId: member?.homeStoreId ?? null,
          deliveryAddressId: dto.addressId,
          paymentMethodId: dto.paymentMethodId,
          fulfillmentType: dto.fulfillmentType,
          placedOn: new Date().toISOString().slice(0, 10),
        })
        .returning();

      await tx.insert(orderTrackStep).values(
        PRESCRIPTION_ORDER_STAGES.map((title, index) => ({
          orderId: created.id,
          sort: index,
          title,
          state: index === 0 ? ('DONE' as const) : index === 1 ? ('CURRENT' as const) : ('UPCOMING' as const),
          occurredAt: index === 0 ? new Date() : null,
        })),
      );

      await tx.insert(prescriptionOrder).values(
        dto.prescriptionIds.map((prescriptionId) => ({
          prescriptionId,
          orderId: created.id,
          storeId: member?.homeStoreId ?? null,
        })),
      );

      // Same "only if it hasn't already moved past AWAITING_REVIEW" guard as
      // the old `markOrdered` — a prescription already READ (pharmacist has
      // keyed in dosage) still moves to ORDERED, one already ORDERED is left
      // alone.
      const toAdvance = owned.filter((p) => p.status === 'AWAITING_REVIEW' || p.status === 'READ').map((p) => p.id);
      if (toAdvance.length > 0) {
        await tx.update(prescription).set({ status: 'ORDERED' }).where(inArray(prescription.id, toAdvance));
      }

      return created;
    });
  }

  async listForMember(memberId: number) {
    const rows = await this.db
      .select()
      .from(prescription)
      .where(and(eq(prescription.memberId, memberId), isNull(prescription.deletedAt)))
      .orderBy(desc(prescription.createdAt));
    const imagesByRx = await this.attachImages(rows.map((r) => r.id));
    return rows.map((row) => this.toMemberView(row, imagesByRx.get(row.id) ?? []));
  }

  async getForMember(memberId: number, id: number) {
    const found = await this.getOwnedByMemberOrThrow(id, memberId);
    const lines = await this.db.select().from(prescriptionMedicine).where(eq(prescriptionMedicine.prescriptionId, id));
    const images = await this.db
      .select()
      .from(prescriptionImage)
      .where(eq(prescriptionImage.prescriptionId, id))
      .orderBy(asc(prescriptionImage.sort));
    return { ...this.toMemberView(found, images), medicines: lines.map(toMemberMedicine) };
  }

  /** Soft-deletes one of the caller's own prescriptions — same pattern as
   *  IdentityService.softDeletePatient. The uploaded scan and any intake
   *  card the pharmacist already sent are left in place (deletedAt merely
   *  drops it from listForMember/getForMember going forward); a prescription
   *  already linked to an order stays fully intact for that order's own
   *  history. */
  async deleteForMember(memberId: number, id: number) {
    const [found] = await this.db
      .select({ id: prescription.id, deletedAt: prescription.deletedAt })
      .from(prescription)
      .where(and(eq(prescription.id, id), eq(prescription.memberId, memberId)))
      .limit(1);

    if (!found) {
      throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Prescription not found' } });
    }

    if (found.deletedAt == null) {
      await this.db
        .update(prescription)
        .set({ deletedAt: new Date() })
        .where(eq(prescription.id, id));
    }
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
    const imagesByRx = await this.attachImages(rows.map((r) => r.id));
    return rows.map((row) => this.toStaffView(row, imagesByRx.get(row.id) ?? []));
  }

  async getForStaff(role: AdminRole, storeId: number | null, id: number) {
    const found = await this.getOwnedByStaffOrThrow(id, role, storeId);
    const lines = await this.db.select().from(prescriptionMedicine).where(eq(prescriptionMedicine.prescriptionId, id));
    const images = await this.db
      .select()
      .from(prescriptionImage)
      .where(eq(prescriptionImage.prescriptionId, id))
      .orderBy(asc(prescriptionImage.sort));
    return { ...this.toStaffView(found, images), medicines: lines };
  }

  /**
   * Fixes one image's display rotation in place — a script photographed
   * sideways or upside down is common enough to need this, and a
   * multi-page prescription may need only one of its pages fixed, not all
   * of them, hence per-image rather than the old whole-prescription field.
   */
  async setImageRotation(
    role: AdminRole,
    storeId: number | null,
    prescriptionId: number,
    imageId: number,
    dto: SetPrescriptionImageRotationDto,
  ) {
    await this.getOwnedByStaffOrThrow(prescriptionId, role, storeId);
    const [updated] = await this.db
      .update(prescriptionImage)
      .set({ imageRotation: dto.rotation })
      .where(and(eq(prescriptionImage.id, imageId), eq(prescriptionImage.prescriptionId, prescriptionId)))
      .returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Image not found' } });
    return updated;
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
      .where(
        and(eq(prescription.id, id), eq(prescription.memberId, memberId), isNull(prescription.deletedAt)),
      )
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

  /** Batch-loads every image for a set of prescriptions, grouped by
   *  prescriptionId and ordered by sort — one query for a whole list rather
   *  than one per row. */
  private async attachImages(prescriptionIds: number[]) {
    const byRx = new Map<number, (typeof prescriptionImage.$inferSelect)[]>();
    if (prescriptionIds.length === 0) return byRx;
    const rows = await this.db
      .select()
      .from(prescriptionImage)
      .where(inArray(prescriptionImage.prescriptionId, prescriptionIds))
      .orderBy(asc(prescriptionImage.sort));
    for (const row of rows) {
      const bucket = byRx.get(row.prescriptionId);
      if (bucket) bucket.push(row);
      else byRx.set(row.prescriptionId, [row]);
    }
    return byRx;
  }

  private toMemberView(row: typeof prescription.$inferSelect, images: (typeof prescriptionImage.$inferSelect)[] = []) {
    const { storagePath: _storagePath, image: _image, imageRotation: _imageRotation, ...rest } = row;
    return { ...rest, images: images.map(toImageView) };
  }

  private toStaffView(row: typeof prescription.$inferSelect, images: (typeof prescriptionImage.$inferSelect)[] = []) {
    const { storagePath: _storagePath, image: _image, imageRotation: _imageRotation, ...rest } = row;
    return { ...rest, images: images.map(toImageView) };
  }
}

function toImageView(row: typeof prescriptionImage.$inferSelect) {
  return { id: row.id, image: row.image, rotation: row.imageRotation };
}
