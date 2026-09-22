import { ConflictException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, asc, desc, eq, getTableColumns, inArray, sql } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { appointment, dietitian, labBooking, labBookingPatient, labBookingReport, labPackage, patient, shieldStore, users } from '../../db/schema';
import { assertLegalAppointmentTransition, assertLegalLabBookingTransition, type AppointmentStatus, type LabBookingStatus } from './care-status';
import type { BookAppointmentDto, BookLabTestDto, UpdateAppointmentStatusDto, UpdateLabBookingStatusDto } from './dto';

/** Every branch open for lab collection right now — the picker at checkout
 *  offers exactly this list, and it is also what {@link BookingService
 *  .bookLabTest} checks a client-supplied [dto.storeId] against. */
async function listLabStores(db: Database) {
  return db
    .select({
      id: shieldStore.id,
      code: shieldStore.code,
      name: shieldStore.name,
      area: shieldStore.area,
      city: shieldStore.city,
      pincode: shieldStore.pincode,
    })
    .from(shieldStore)
    .where(and(eq(shieldStore.isActive, true), eq(shieldStore.offersLabCollection, true)))
    .orderBy(asc(shieldStore.sort), asc(shieldStore.name));
}

@Injectable()
export class BookingService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  // ---- Lab bookings --------------------------------------------------------

  async bookLabTest(memberId: number, dto: BookLabTestDto) {
    const ownedPatientIds = dto.patients.map((p) => p.patientId).filter((id): id is number => id !== undefined);
    if (ownedPatientIds.length > 0) {
      const owned = await this.db
        .select({ id: patient.id })
        .from(patient)
        .where(and(inArray(patient.id, ownedPatientIds), eq(patient.memberId, memberId)));
      if (owned.length !== new Set(ownedPatientIds).size) {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'One or more patients do not belong to this member' } });
      }
    }

    // Price comes from the live lab_package row, never the client — same
    // rule as cart pricing in commerce/cart.service.ts.
    const [pkg] = await this.db.select().from(labPackage).where(eq(labPackage.id, dto.labPackageId)).limit(1);
    if (!pkg || !pkg.isActive) {
      throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab package not available' } });
    }

    const unitPrice = Number(pkg.price);
    const totalPrice = unitPrice * dto.patients.length;

    // Which branch this books into: whatever the client sent, checked against
    // the branches actually open for lab right now (the same list the picker
    // itself was built from — a stale or tampered id is never trusted blind);
    // falling back to the member's own home branch when none was sent, the
    // same default a standard order's checkout uses.
    const labStores = await listLabStores(this.db);
    const labStoreIds = new Set(labStores.map((s) => s.id));
    let storeId: number | null = null;
    if (dto.storeId !== undefined) {
      if (!labStoreIds.has(dto.storeId)) {
        throw new ForbiddenException({
          error: { code: 'FORBIDDEN', message: 'That branch is not open for lab bookings.' },
        });
      }
      storeId = dto.storeId;
    } else {
      const [member] = await this.db.select({ homeStoreId: users.homeStoreId }).from(users).where(eq(users.id, memberId)).limit(1);
      if (member?.homeStoreId != null && labStoreIds.has(member.homeStoreId)) {
        storeId = member.homeStoreId;
      }
    }

    return this.db.transaction(async (tx) => {
      const [created] = await tx
        .insert(labBooking)
        .values({
          memberId,
          labPackageId: pkg.id,
          patientsCount: dto.patients.length,
          unitPrice: unitPrice.toString(),
          totalPrice: totalPrice.toString(),
          addressId: dto.addressId,
          storeId: storeId ?? undefined,
          scheduledFor: dto.scheduledFor ? new Date(dto.scheduledFor) : undefined,
        })
        .returning();

      await tx.insert(labBookingPatient).values(
        dto.patients.map((p) => ({ labBookingId: created.id, patientId: p.patientId, name: p.name, age: p.age })),
      );

      return created;
    });
  }

  /**
   * The member's own bookings, newest first — the booking's own columns plus
   * the package's name and how many report pages the lab has attached. The
   * pages themselves are never in a list: they are big, and fetched on demand
   * from [getLabReportForMember].
   */
  async listLabBookingsForMember(memberId: number) {
    const rows = await this.db
      .select({ ...getTableColumns(labBooking), packageName: labPackage.name })
      .from(labBooking)
      .leftJoin(labPackage, eq(labPackage.id, labBooking.labPackageId))
      .where(eq(labBooking.memberId, memberId))
      .orderBy(desc(labBooking.createdAt));
    if (rows.length === 0) return [];

    const counts = await this.db
      .select({ labBookingId: labBookingReport.labBookingId, n: sql<number>`count(*)::int` })
      .from(labBookingReport)
      .where(inArray(labBookingReport.labBookingId, rows.map((r) => r.id)))
      .groupBy(labBookingReport.labBookingId);
    const pagesById = new Map(counts.map((c) => [c.labBookingId, c.n]));
    return rows.map((r) => ({ ...r, reportPages: pagesById.get(r.id) ?? 0 }));
  }

  async getLabBookingForMember(memberId: number, id: number) {
    const found = await this.getLabBookingOwnedOrThrow(id, memberId);
    const patients = await this.db.select().from(labBookingPatient).where(eq(labBookingPatient.labBookingId, id));
    const [pkg] = await this.db.select({ name: labPackage.name }).from(labPackage).where(eq(labPackage.id, found.labPackageId)).limit(1);
    const [pages] = await this.db
      .select({ n: sql<number>`count(*)::int` })
      .from(labBookingReport)
      .where(eq(labBookingReport.labBookingId, id));
    return { ...found, patients, packageName: pkg?.name ?? null, reportPages: pages?.n ?? 0 };
  }

  /**
   * The report the lab attached to one of the member's own bookings, page by
   * page in order. A booking with no report yet answers an empty list rather
   * than an error, so the app can simply show "not ready".
   */
  async getLabReportForMember(memberId: number, id: number) {
    await this.getLabBookingOwnedOrThrow(id, memberId);
    const pages = await this.db
      .select({ id: labBookingReport.id, name: labBookingReport.name, image: labBookingReport.image })
      .from(labBookingReport)
      .where(eq(labBookingReport.labBookingId, id))
      .orderBy(asc(labBookingReport.sort), asc(labBookingReport.id));
    return { pages };
  }

  /** Every branch, newest booking first — the "Branch" column and filter on
   *  the console's Lab Orders screen. No role-based scoping: unlike Pharmacy
   *  (one branch each), there is one Lab Admin account working every branch's
   *  bookings, the same as before this had a branch at all. */
  async listLabBookingsForStaff() {
    return this.db
      .select({ ...getTableColumns(labBooking), storeCode: shieldStore.code, storeName: shieldStore.name })
      .from(labBooking)
      .leftJoin(shieldStore, eq(shieldStore.id, labBooking.storeId))
      .orderBy(desc(labBooking.createdAt));
  }

  /** Public — the branch picker a member sees before confirming a lab booking. */
  async listLabStoresPublic() {
    return listLabStores(this.db);
  }

  async updateLabBookingStatus(id: number, dto: UpdateLabBookingStatusDto) {
    const [found] = await this.db.select().from(labBooking).where(eq(labBooking.id, id)).limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab booking not found' } });
    assertLegalLabBookingTransition(found.status as LabBookingStatus, dto.status);

    // "Report ready" tells the member their report is waiting — it must be.
    if (dto.status === 'REPORT_READY' && found.status !== 'REPORT_READY') {
      const [pages] = await this.db
        .select({ n: sql<number>`count(*)::int` })
        .from(labBookingReport)
        .where(eq(labBookingReport.labBookingId, id));
      if (!pages || pages.n === 0) {
        throw new ConflictException({
          error: { code: 'REPORT_REQUIRED', message: 'Attach the lab report before marking the booking Report ready' },
        });
      }
    }

    const [updated] = await this.db.update(labBooking).set({ status: dto.status }).where(eq(labBooking.id, id)).returning();
    return updated;
  }

  private async getLabBookingOwnedOrThrow(id: number, memberId: number) {
    const [found] = await this.db
      .select()
      .from(labBooking)
      .where(and(eq(labBooking.id, id), eq(labBooking.memberId, memberId)))
      .limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab booking not found' } });
    return found;
  }

  // ---- Appointments --------------------------------------------------------

  async bookAppointment(memberId: number, dto: BookAppointmentDto) {
    if (dto.patientId) {
      const [owned] = await this.db
        .select({ id: patient.id })
        .from(patient)
        .where(and(eq(patient.id, dto.patientId), eq(patient.memberId, memberId)))
        .limit(1);
      if (!owned) throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'patientId does not belong to this member' } });
    }

    // Only a dietitian's fee is numeric in the live schema (clinic_doctor.fee
    // is free-text) — so fee is only auto-populated for DIETITIAN bookings.
    // Not a gap I'm papering over: it's what the schema actually supports.
    let fee: string | undefined;
    if (dto.kind === 'DIETITIAN' && dto.dietitianId) {
      const [found] = await this.db.select().from(dietitian).where(eq(dietitian.id, dto.dietitianId)).limit(1);
      if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Dietitian not found' } });
      fee = found.fee;
    }

    const [created] = await this.db
      .insert(appointment)
      .values({
        memberId,
        kind: dto.kind,
        clinicId: dto.clinicId,
        dietitianId: dto.dietitianId,
        patientId: dto.patientId,
        doctorName: dto.doctorName,
        fee,
        scheduledFor: dto.scheduledFor ? new Date(dto.scheduledFor) : undefined,
        remarks: dto.remarks,
      })
      .returning();
    return created;
  }

  async listAppointmentsForMember(memberId: number) {
    return this.db.select().from(appointment).where(eq(appointment.memberId, memberId)).orderBy(desc(appointment.createdAt));
  }

  async getAppointmentForMember(memberId: number, id: number) {
    const [found] = await this.db
      .select()
      .from(appointment)
      .where(and(eq(appointment.id, id), eq(appointment.memberId, memberId)))
      .limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Appointment not found' } });
    return found;
  }

  /** No branch scoping — appointment has no store_id in the live schema either. */
  async listAppointmentsForStaff() {
    return this.db.select().from(appointment).orderBy(desc(appointment.createdAt));
  }

  async updateAppointmentStatus(id: number, dto: UpdateAppointmentStatusDto) {
    const [found] = await this.db.select().from(appointment).where(eq(appointment.id, id)).limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Appointment not found' } });
    assertLegalAppointmentTransition(found.status as AppointmentStatus, dto.status);

    const [updated] = await this.db.update(appointment).set({ status: dto.status }).where(eq(appointment.id, id)).returning();
    return updated;
  }
}
