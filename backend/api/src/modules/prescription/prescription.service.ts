import { ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, asc, desc, eq, inArray, isNotNull, isNull, sql } from 'drizzle-orm';
import { randomBytes } from 'node:crypto';
import { DRIZZLE, type Database } from '../../db/client';
import {
  bill,
  medicineDurationEnum,
  memberAddress,
  order,
  orderTrackStep,
  patient,
  prescription,
  prescriptionImage,
  prescriptionMedicine,
  prescriptionOrder,
  shieldStore,
  users,
} from '../../db/schema';
import type { AdminRole } from '../auth/session.types';
import { cancelOrderForMember } from '../commerce/member-withdrawal';
import { assertLegalPrescriptionTransition, type PrescriptionStatus } from './prescription-status';
import type {
  AddMedicineLineDto,
  CreateOrderForPrescriptionDto,
  SaveIntakeDto,
  SetPrescriptionImageRotationDto,
  SubmitPrescriptionOrderDto,
  UpdateMedicineStatusDto,
  UpdatePrescriptionBranchDto,
  UpdatePrescriptionDetailsDto,
  UpdatePrescriptionFulfillmentDto,
  UpdatePrescriptionPatientDto,
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
    const ids = rows.map((r) => r.id);
    const imagesByRx = await this.attachImages(ids);
    const ordersByRx = await this.latestOrders(ids);
    return rows.map((row) => ({
      ...this.toMemberView(row, imagesByRx.get(row.id) ?? []),
      order: ordersByRx.get(row.id) ?? null,
    }));
  }

  async getForMember(memberId: number, id: number) {
    const found = await this.getOwnedByMemberOrThrow(id, memberId);
    const lines = await this.db.select().from(prescriptionMedicine).where(eq(prescriptionMedicine.prescriptionId, id));
    const images = await this.db
      .select()
      .from(prescriptionImage)
      .where(eq(prescriptionImage.prescriptionId, id))
      .orderBy(asc(prescriptionImage.sort));
    const linkedOrder = (await this.latestOrders([id])).get(id) ?? null;
    return { ...this.toMemberView(found, images), medicines: lines.map(toMemberMedicine), order: linkedOrder };
  }

  /**
   * The order each prescription was most recently placed into — what the
   * member's "Your prescriptions" card shows as its order-tracking status.
   * A prescription can sit in several orders (a reorder places a fresh one for
   * the same uploaded script), so the newest link wins; null for one that was
   * never ordered.
   *
   * Carries just what the app needs to work out the tracking stage
   * (Pending → Processed → Billing → Completed, or Cancelled): the order's
   * status, when staff first contacted the member or saved its review, and
   * whether it's been converted to a bill — the same signals `Purchase.stage`
   * reads off the orders list. `billed` means "converted to bill", the same
   * milestone shieldweb's `orderLifecycleStatus` counts as reaching
   * "Billing" — not whether a priced `app.bill` row exists yet, which can
   * (and usually does) land later, as its own separate step.
   */
  private async latestOrders(prescriptionIds: number[]) {
    const byRx = new Map<
      number,
      {
        id: number;
        code: string;
        status: string;
        storeId: number | null;
        fulfillmentType: string;
        storeContactedAt: Date | null;
        reviewedAt: Date | null;
        convertedToBillAt: Date | null;
        billed: boolean;
      }
    >();
    if (prescriptionIds.length === 0) return byRx;

    const rows = await this.db
      .select({
        prescriptionId: prescriptionOrder.prescriptionId,
        id: order.id,
        code: order.code,
        status: order.status,
        storeId: order.storeId,
        fulfillmentType: order.fulfillmentType,
        storeContactedAt: order.storeContactedAt,
        reviewedAt: order.reviewedAt,
        convertedToBillAt: order.convertedToBillAt,
      })
      .from(prescriptionOrder)
      .innerJoin(order, eq(order.id, prescriptionOrder.orderId))
      .where(inArray(prescriptionOrder.prescriptionId, prescriptionIds))
      .orderBy(desc(prescriptionOrder.submittedAt), desc(prescriptionOrder.id));

    for (const row of rows) {
      if (byRx.has(row.prescriptionId)) continue; // rows arrive newest first
      byRx.set(row.prescriptionId, {
        id: row.id,
        code: row.code,
        status: row.status,
        storeId: row.storeId,
        fulfillmentType: row.fulfillmentType,
        storeContactedAt: row.storeContactedAt,
        reviewedAt: row.reviewedAt,
        convertedToBillAt: row.convertedToBillAt,
        billed: row.convertedToBillAt !== null,
      });
    }
    return byRx;
  }

  /** The id of the single most recent order this prescription was ever
   *  submitted with (any status) — same "latest prescription_order row
   *  with an order_id" rule {@link latestOrders} itself uses, but as one
   *  scalar rather than that method's richer per-order summary; used
   *  where only the id is needed (billing a prescription order, stamping
   *  reviewedAt on save). */
  private async latestOrderId(prescriptionId: number): Promise<number | null> {
    const [row] = await this.db
      .select({ orderId: prescriptionOrder.orderId })
      .from(prescriptionOrder)
      .where(and(eq(prescriptionOrder.prescriptionId, prescriptionId), isNotNull(prescriptionOrder.orderId)))
      .orderBy(desc(prescriptionOrder.id))
      .limit(1);
    return row?.orderId ?? null;
  }

  /** Soft-deletes one of the caller's own prescriptions — same pattern as
   *  IdentityService.softDeletePatient. The uploaded scan and any intake
   *  card the pharmacist already sent are left in place (deletedAt merely
   *  drops it from listForMember/getForMember going forward).
   *
   *  Only while the store has not touched it: once any order it was submitted
   *  with has been reviewed, contacted, billed, paid, delivered…, the delete
   *  is refused (409 ORDER_LOCKED) and the store removes it from the admin
   *  console. An order placed with it that is still untouched is cancelled in
   *  the same step, so withdrawing the script never leaves a live order for
   *  a script the member no longer has. */
  async deleteForMember(memberId: number, id: number) {
    const [found] = await this.db
      .select({ id: prescription.id, deletedAt: prescription.deletedAt })
      .from(prescription)
      .where(and(eq(prescription.id, id), eq(prescription.memberId, memberId)))
      .limit(1);

    if (!found) {
      throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Prescription not found' } });
    }

    if (found.deletedAt != null) return;

    await this.db.transaction(async (tx) => {
      const linked = await tx
        .select({ orderId: prescriptionOrder.orderId })
        .from(prescriptionOrder)
        .where(eq(prescriptionOrder.prescriptionId, id));
      const orderIds = [...new Set(linked.map((l) => l.orderId).filter((v): v is number => v !== null))];
      // Throws 409 ORDER_LOCKED for the first order the store has touched.
      for (const orderId of orderIds) await cancelOrderForMember(tx, orderId);
      await tx.update(prescription).set({ deletedAt: new Date() }).where(eq(prescription.id, id));
    });
  }

  /**
   * Every prescription this role may see, newest first, carrying the
   * member/patient names, the branch it resolves to (its own pin, else its
   * latest order's own store, else the member's home branch), and its
   * latest order's own milestones and bill — the console's own shape, not
   * the raw `app.prescription` columns the old {@link toStaffView} used to
   * return alone.
   *
   * Scoping by that same effective-branch chain is computed in JS (see
   * {@link toStaffViews}) rather than as a SQL condition — a correlated
   * subquery one row deep (this prescription's own *latest* order) reaching
   * back into the outer query isn't exotic SQL in real Postgres, but it is
   * one more thing than pg-mem's test double can execute; this also means
   * every candidate prescription gets the same enrichment work regardless
   * of role, so there is only one code path to keep correct.
   */
  async listForStaff(role: AdminRole, storeId: number | null) {
    const unscoped = role === 'SUPERADMIN' || role === 'ADMIN';
    if (!unscoped && storeId == null) return [];
    const rows = await this.db.select().from(prescription).where(isNull(prescription.deletedAt)).orderBy(desc(prescription.createdAt));
    const views = await this.toStaffViews(rows);
    return unscoped ? views : views.filter((v) => v.effectiveStoreId === storeId);
  }

  async getForStaff(role: AdminRole, storeId: number | null, id: number) {
    const found = await this.getOwnedByStaffOrThrow(id, role, storeId);
    const lines = await this.db.select().from(prescriptionMedicine).where(eq(prescriptionMedicine.prescriptionId, id)).orderBy(asc(prescriptionMedicine.sort));
    const [view] = await this.toStaffViews([found]);
    return { ...view, medicines: lines };
  }

  /**
   * Fixes one image's display rotation in place — a script photographed
   * sideways or upside down is common enough to need this, and a
   * multi-page prescription may need only one of its pages fixed, not all
   * of them, hence per-image rather than the old whole-prescription field.
   * [imageId] is a real `prescription_image` row's id, or `legacy-<id>` for
   * the pre-migration-0040 photo that lives on `app.prescription.image`
   * itself instead (see {@link toStaffViews}'s own doc).
   */
  async setImageRotation(role: AdminRole, storeId: number | null, prescriptionId: number, imageId: string, dto: SetPrescriptionImageRotationDto) {
    await this.getOwnedByStaffOrThrow(prescriptionId, role, storeId);

    const legacyMatch = /^legacy-(\d+)$/.exec(imageId);
    if (legacyMatch) {
      const [updated] = await this.db
        .update(prescription)
        .set({ imageRotation: dto.rotation })
        .where(eq(prescription.id, prescriptionId))
        .returning();
      if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Image not found' } });
      return { id: imageId, image: updated.image, rotation: updated.imageRotation };
    }

    const [updated] = await this.db
      .update(prescriptionImage)
      .set({ imageRotation: dto.rotation })
      .where(and(eq(prescriptionImage.id, Number(imageId)), eq(prescriptionImage.prescriptionId, prescriptionId)))
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
    return (await this.toStaffViews([updated]))[0];
  }

  /**
   * Replaces a prescription's intake card with the lines the pharmacist
   * entered and moves it to READ — the member app picks the card up on its
   * next read. Also stamps the linked order's own reviewedAt, the same
   * milestone a standard order's own review/convert-to-bill steps stamp, so
   * a prescription order reaches "Processed" the moment the pharmacist has
   * actually read the script, not only once something else happens to
   * touch it. Blank rows (no name) are dropped; an empty list clears the
   * card and leaves the prescription's own status untouched.
   */
  async savePrescriptionIntake(role: AdminRole, storeId: number | null, id: number, dto: SaveIntakeDto) {
    const found = await this.getOwnedByStaffOrThrow(id, role, storeId);
    const rows = dto.medicines.map((m) => ({ ...m, name: m.name.trim() })).filter((m) => m.name.length > 0);

    await this.db.delete(prescriptionMedicine).where(eq(prescriptionMedicine.prescriptionId, id));
    if (rows.length > 0) {
      await this.db.insert(prescriptionMedicine).values(
        rows.map((m, index) => {
          const digits = (m.intake.match(/\d/g) ?? []).slice(0, 3).map(Number);
          while (digits.length < 3) digits.push(0);
          return {
            prescriptionId: id,
            sort: index,
            name: m.name,
            pack: m.pack.trim(),
            doseMorning: digits[0],
            doseAfternoon: digits[1],
            doseNight: digits[2],
            totalUnits: Math.max(0, Math.round(m.totalUnits) || 0),
            routeTime: m.routeTime.trim(),
            status: (m.status.toUpperCase() || 'AVAILABLE') as (typeof prescriptionMedicine.$inferInsert)['status'],
          };
        }),
      );

      await this.db
        .update(prescription)
        .set({ status: 'READ', reviewedAt: found.reviewedAt ?? new Date() })
        .where(eq(prescription.id, id));

      const orderId = await this.latestOrderId(id);
      if (orderId !== null) {
        await this.db
          .update(order)
          .set({ reviewedAt: sql`COALESCE(${order.reviewedAt}, now())` })
          .where(and(eq(order.id, orderId), sql`${order.status} <> 'CANCELLED'`));
      }
    }
  }

  /**
   * Corrects what the member sent up front — the doctor's name (blank until
   * a reviewer reads it off the script) and how long the course runs.
   * [customDays] above 0 is what the member app actually displays; 0 clears
   * it back to [durationToken].
   */
  async updatePrescriptionDetails(role: AdminRole, storeId: number | null, id: number, dto: UpdatePrescriptionDetailsDto) {
    await this.getOwnedByStaffOrThrow(id, role, storeId);
    const token = dto.durationToken.trim().toUpperCase();
    if (token && !medicineDurationEnum.enumValues.includes(token as (typeof medicineDurationEnum.enumValues)[number])) {
      throw new ForbiddenException({ error: { code: 'VALIDATION', message: `Unknown duration "${dto.durationToken}"` } });
    }
    await this.db
      .update(prescription)
      .set({
        doctor: dto.doctor.trim(),
        duration: token ? (token as (typeof medicineDurationEnum.enumValues)[number]) : null,
        customDays: Math.max(0, Math.round(dto.customDays) || 0),
        updatedAt: new Date(),
      })
      .where(eq(prescription.id, id));
  }

  /**
   * Pins (or clears, passing null) the branch this prescription is filled
   * at — overriding the pickup-order/home-branch fallback {@link toStaffViews}
   * otherwise falls back to for display.
   */
  async updatePrescriptionBranch(role: AdminRole, storeId: number | null, id: number, dto: UpdatePrescriptionBranchDto) {
    await this.getOwnedByStaffOrThrow(id, role, storeId);
    await this.db.update(prescription).set({ storeId: dto.storeId, updatedAt: new Date() }).where(eq(prescription.id, id));
  }

  /**
   * Admin removal of a prescription — the same soft delete the member's own
   * delete does, but not subject to that caller's own order-locked guard
   * (see {@link deleteForMember}'s own doc): the store may remove a script at
   * any stage. Its order, if any, is left untouched — cancel that
   * separately. Returns false when it was already gone.
   */
  async deleteForStaff(role: AdminRole, storeId: number | null, id: number): Promise<boolean> {
    await this.getOwnedByStaffOrThrow(id, role, storeId);
    const [updated] = await this.db
      .update(prescription)
      .set({ deletedAt: new Date(), updatedAt: new Date() })
      .where(and(eq(prescription.id, id), isNull(prescription.deletedAt)))
      .returning({ id: prescription.id });
    return updated !== undefined;
  }

  /**
   * Sets how this prescription's order reaches the member — the reviewer's
   * override of the member's own checkout choice. Only an order still being
   * processed can change; once it is out for delivery, delivered or
   * cancelled, how it reached the member is a fact, not a plan. Returns
   * false when there was no such order to change.
   */
  async updatePrescriptionFulfillment(role: AdminRole, storeId: number | null, id: number, dto: UpdatePrescriptionFulfillmentDto): Promise<boolean> {
    await this.getOwnedByStaffOrThrow(id, role, storeId);
    const orderId = await this.latestOrderId(id);
    if (orderId === null) return false;
    const [updated] = await this.db
      .update(order)
      .set({ fulfillmentType: dto.fulfillmentType })
      .where(and(eq(order.id, orderId), eq(order.status, 'PROCESSING')))
      .returning({ id: order.id });
    return updated !== undefined;
  }

  /**
   * Re-points this prescription at a different saved patient of the same
   * member — for when the wrong family member was picked at upload, or the
   * right one hadn't been added yet. [patientId] is re-checked against the
   * prescription's own memberId here (the picker that feeds this already
   * only offers that member's own patients, but the server verifies it
   * rather than trusting the client's own scoping).
   */
  async updatePrescriptionPatient(role: AdminRole, storeId: number | null, id: number, dto: UpdatePrescriptionPatientDto) {
    const found = await this.getOwnedByStaffOrThrow(id, role, storeId);
    const [owned] = await this.db.select({ id: patient.id }).from(patient).where(and(eq(patient.id, dto.patientId), eq(patient.memberId, found.memberId))).limit(1);
    if (!owned) throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'patientId does not belong to this prescription\'s member' } });
    await this.db.update(prescription).set({ patientId: dto.patientId, updatedAt: new Date() }).where(eq(prescription.id, id));
  }

  /**
   * The medicines on whichever prescription [orderId] was billed against —
   * the bill editor's source for offering a prescription order's real
   * intake list as bill-line candidates instead of a blank form. Scoped the
   * same way every other staff prescription read is, through the
   * prescription this order is linked to. Null when [orderId] has no
   * linked prescription at all (a standard order, or a gap); an empty array
   * when it does but nothing was ever added to its intake card.
   */
  async getPrescriptionMedicinesForOrder(role: AdminRole, storeId: number | null, orderId: number) {
    const [link] = await this.db
      .select({ prescriptionId: prescriptionOrder.prescriptionId })
      .from(prescriptionOrder)
      .where(eq(prescriptionOrder.orderId, orderId))
      .orderBy(desc(prescriptionOrder.id))
      .limit(1);
    if (!link) return null;
    await this.getOwnedByStaffOrThrow(link.prescriptionId, role, storeId);
    return this.db
      .select()
      .from(prescriptionMedicine)
      .where(eq(prescriptionMedicine.prescriptionId, link.prescriptionId))
      .orderBy(asc(prescriptionMedicine.sort));
  }

  /**
   * Admin recovery only — not the normal path. Every prescription is meant
   * to already carry the order the member's own checkout created alongside
   * it; this exists for the rare one that somehow doesn't, so "Convert to
   * bill" has something to convert instead of refusing outright. Uses
   * exactly the fields already confirmed on the Details step — the member,
   * the pinned branch, the fulfilment type shown — rather than inventing
   * anything a reviewer hasn't already set.
   */
  async createOrderForPrescription(role: AdminRole, storeId: number | null, id: number, dto: CreateOrderForPrescriptionDto) {
    const found = await this.getOwnedByStaffOrThrow(id, role, storeId);
    return this.db.transaction(async (tx) => {
      const [created] = await tx
        .insert(order)
        .values({
          memberId: found.memberId,
          code: `SH-TMP-${randomBytes(4).toString('hex')}`,
          kind: 'PRESCRIPTION',
          status: 'PROCESSING',
          storeId: found.storeId,
          fulfillmentType: dto.fulfillmentType,
          itemCount: 1,
          placedOn: new Date().toISOString().slice(0, 10),
        })
        .returning();
      // A real, stable code now that the row's own id exists to build it
      // from — the placeholder above only ever has to satisfy the NOT NULL
      // UNIQUE constraint for the instant between these two statements.
      await tx.update(order).set({ code: `SH-${created.id}` }).where(eq(order.id, created.id));
      await tx.insert(prescriptionOrder).values({ prescriptionId: id, orderId: created.id, storeId: found.storeId, status: 'SUBMITTED' });
      return { id: created.id };
    });
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
    const [found] = await this.db.select().from(prescription).where(eq(prescription.id, id)).limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Prescription not found' } });
    if (role !== 'SUPERADMIN' && role !== 'ADMIN') {
      if (storeId == null) {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Staff account has no store assigned' } });
      }
      const [view] = await this.toStaffViews([found]);
      if (view.effectiveStoreId !== storeId) {
        throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Prescription not found' } });
      }
    }
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

  /**
   * The console's own shape for a batch of prescription rows: member/
   * patient names, the branch it resolves to, and its latest order's own
   * milestones and bill — everything `src/api/prescriptions.ts`'s old
   * direct-SQL `fetchPrescriptions` joined in, moved server-side.
   */
  private async toStaffViews(rows: (typeof prescription.$inferSelect)[]) {
    if (rows.length === 0) return [];
    const ids = rows.map((r) => r.id);
    const memberIds = [...new Set(rows.map((r) => r.memberId))];
    const patientIds = [...new Set(rows.map((r) => r.patientId))];
    const assignedStoreIds = [...new Set(rows.map((r) => r.storeId).filter((v): v is number => v != null))];

    const [memberRows, patientRows, imagesByRx, ordersByRx] = await Promise.all([
      this.db.select({ id: users.id, name: users.name, phone: users.phone, homeStoreId: users.homeStoreId }).from(users).where(inArray(users.id, memberIds)),
      this.db.select({ id: patient.id, name: patient.name }).from(patient).where(inArray(patient.id, patientIds)),
      this.attachImages(ids),
      this.latestOrders(ids),
    ]);
    const memberById = new Map(memberRows.map((m) => [m.id, m]));
    const patientById = new Map(patientRows.map((p) => [p.id, p]));

    const orderIds = [...new Set([...ordersByRx.values()].map((o) => o.id))];
    const billRows = orderIds.length
      ? await this.db.select({ orderId: bill.orderId, amount: bill.amount, status: bill.status }).from(bill).where(inArray(bill.orderId, orderIds))
      : [];
    const billByOrderId = new Map(billRows.map((b) => [b.orderId, b]));

    const allStoreIds = new Set(assignedStoreIds);
    for (const o of ordersByRx.values()) if (o.storeId != null) allStoreIds.add(o.storeId);
    for (const m of memberRows) if (m.homeStoreId != null) allStoreIds.add(m.homeStoreId);
    const storeRows = allStoreIds.size
      ? await this.db.select({ id: shieldStore.id, code: shieldStore.code, name: shieldStore.name }).from(shieldStore).where(inArray(shieldStore.id, [...allStoreIds]))
      : [];
    const storeById = new Map(storeRows.map((s) => [s.id, s]));

    return rows.map((row) => {
      const { storagePath: _storagePath, image: _image, imageRotation: _imageRotation, ...rest } = row;
      const member = memberById.get(row.memberId);
      const linkedOrder = ordersByRx.get(row.id) ?? null;
      const linkedBill = linkedOrder ? billByOrderId.get(linkedOrder.id) : undefined;
      const effectiveStoreId = row.storeId ?? linkedOrder?.storeId ?? member?.homeStoreId ?? null;
      const effectiveStore = effectiveStoreId != null ? storeById.get(effectiveStoreId) : undefined;

      let images = (imagesByRx.get(row.id) ?? []).map(toImageView);
      // Scripts uploaded before migration 0040 carry their one photo
      // directly on app.prescription.image/image_rotation instead of a
      // prescription_image row — surfaced here under a legacy-<id> id (see
      // setImageRotation's own doc) so it isn't invisible in the console.
      if (images.length === 0 && row.image) {
        images = [{ id: `legacy-${row.id}`, image: row.image, rotation: row.imageRotation }];
      }

      return {
        ...rest,
        memberName: member?.name ?? '—',
        memberPhone: member?.phone ?? '',
        patientName: patientById.get(row.patientId)?.name ?? '—',
        // Internal-only — listForStaff/getOwnedByStaffOrThrow filter on
        // this; not documented as part of the response contract.
        effectiveStoreId,
        storeCode: effectiveStore?.code ?? '',
        storeName: effectiveStore?.name ?? '—',
        images,
        linkedOrderId: linkedOrder?.id ?? null,
        orderFulfillmentType: linkedOrder?.fulfillmentType ?? 'HOME_DELIVERY',
        orderStatus: linkedOrder?.status ?? null,
        orderReviewedAt: linkedOrder?.reviewedAt ?? null,
        orderStoreContactedAt: linkedOrder?.storeContactedAt ?? null,
        orderConvertedToBillAt: linkedOrder?.convertedToBillAt ?? null,
        billAmount: linkedBill?.amount ?? '0',
        billStatus: linkedBill?.status ?? 'PENDING',
      };
    });
  }
}

function toImageView(row: typeof prescriptionImage.$inferSelect) {
  return { id: String(row.id), image: row.image, rotation: row.imageRotation };
}
