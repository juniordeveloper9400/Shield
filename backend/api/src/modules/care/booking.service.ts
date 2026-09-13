import { ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, desc, eq, inArray } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { appointment, dietitian, labBooking, labBookingPatient, labPackage, patient } from '../../db/schema';
import { assertLegalAppointmentTransition, assertLegalLabBookingTransition, type AppointmentStatus, type LabBookingStatus } from './care-status';
import type { BookAppointmentDto, BookLabTestDto, UpdateAppointmentStatusDto, UpdateLabBookingStatusDto } from './dto';

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
          scheduledFor: dto.scheduledFor ? new Date(dto.scheduledFor) : undefined,
        })
        .returning();

      await tx.insert(labBookingPatient).values(
        dto.patients.map((p) => ({ labBookingId: created.id, patientId: p.patientId, name: p.name, age: p.age })),
      );

      return created;
    });
  }

  async listLabBookingsForMember(memberId: number) {
    return this.db.select().from(labBooking).where(eq(labBooking.memberId, memberId)).orderBy(desc(labBooking.createdAt));
  }

  async getLabBookingForMember(memberId: number, id: number) {
    const found = await this.getLabBookingOwnedOrThrow(id, memberId);
    const patients = await this.db.select().from(labBookingPatient).where(eq(labBookingPatient.labBookingId, id));
    return { ...found, patients };
  }

  /** No branch scoping — lab_booking has no store_id in the live schema. Any staff role may manage it. */
  async listLabBookingsForStaff() {
    return this.db.select().from(labBooking).orderBy(desc(labBooking.createdAt));
  }

  async updateLabBookingStatus(id: number, dto: UpdateLabBookingStatusDto) {
    const [found] = await this.db.select().from(labBooking).where(eq(labBooking.id, id)).limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab booking not found' } });
    assertLegalLabBookingTransition(found.status as LabBookingStatus, dto.status);

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
