import { BadRequestException, ConflictException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, asc, desc, eq, getTableColumns, inArray, sql } from 'drizzle-orm';
import { alias } from 'drizzle-orm/pg-core';
import { DRIZZLE, type Database } from '../../db/client';
import {
  adminUser,
  appointment,
  chartOfAccount,
  clinic,
  dietitian,
  journalEntry,
  journalLine,
  labBill,
  labBillLine,
  labBooking,
  labBookingPatient,
  labBookingReport,
  labPackage,
  memberAddress,
  patient,
  postingRule,
  shieldStore,
  users,
  wallet,
  walletCard,
  walletEntry,
} from '../../db/schema';
import { randomUUID } from 'node:crypto';
import type { AdminRole } from '../auth/session.types';
import { availablePlanAllowance, redeemableAllowance, redeemedThisMonth, toIsoDate } from '../wallet/wallet-month';
import { assertLegalAppointmentTransition, assertLegalLabBookingTransition, type AppointmentStatus, type LabBookingStatus } from './care-status';
import type {
  AddLabReportPagesDto,
  AssignLabStaffDto,
  BookAppointmentDto,
  BookLabTestDto,
  ReceiveLabBillPaymentDto,
  SendLabBillDto,
  UpdateAppointmentStatusDto,
  UpdateLabBookingDetailsDto,
  UpdateLabBookingStatusDto,
} from './dto';

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
      // Lets a client rank this live list by real distance the same way the
      // app's own bundled StoreDirectory already can — see LabStore's own
      // doc on why this list is fetched live instead of reusing that one.
      latitude: shieldStore.latitude,
      longitude: shieldStore.longitude,
    })
    .from(shieldStore)
    .where(and(eq(shieldStore.isActive, true), eq(shieldStore.offersLabCollection, true)))
    .orderBy(asc(shieldStore.sort), asc(shieldStore.name));
}

function ageFromDob(dob: string | null): number | null {
  if (!dob) return null;
  const born = new Date(dob);
  const today = new Date();
  let age = today.getUTCFullYear() - born.getUTCFullYear();
  if (today.getUTCMonth() < born.getUTCMonth() || (today.getUTCMonth() === born.getUTCMonth() && today.getUTCDate() < born.getUTCDate())) age--;
  return age;
}

function parseBillMeta(note: string | null | undefined) {
  if (!note) return { cleanNote: '', fuelCharge: 0, techFee: 0, isVerified: false };
  const match = note.match(/\[BILL_VERIFIED:\s*fuel=(\d+(?:\.\d+)?),\s*tech=(\d+(?:\.\d+)?)\]/);
  if (match) {
    const fuel = parseFloat(match[1]) || 0;
    const tech = parseFloat(match[2]) || 0;
    const cleanNote = note.replace(/\[BILL_VERIFIED:\s*fuel=\d+(?:\.\d+)?,\s*tech=\d+(?:\.\d+)?\]\s*/, '').trim();
    return { cleanNote, fuelCharge: fuel, techFee: tech, isVerified: true };
  }
  return { cleanNote: note, fuelCharge: 0, techFee: 0, isVerified: false };
}

/**
 * Where a lab order is as the member reads it: Requested → Verified → Billed →
 * Completed (or Cancelled). Worked out from what the admin has actually done,
 * not stored: verifying the bill on Lab Orders makes it Verified, converting
 * it to a bill (an app.lab_bill row) makes it Billed, and collecting the
 * payment — or the lab marking the report ready — makes it Completed.
 */
export function memberLabStage(input: {
  status: string;
  isVerified: boolean;
  billExists: boolean;
  billStatus: string | null;
}): 'REQUESTED' | 'VERIFIED' | 'BILLED' | 'COMPLETED' | 'CANCELLED' {
  if (input.status === 'CANCELLED') return 'CANCELLED';
  if (input.status === 'REPORT_READY' || input.billStatus === 'PAID') return 'COMPLETED';
  if (input.billExists) return 'BILLED';
  if (input.isVerified) return 'VERIFIED';
  return 'REQUESTED';
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

    // Every address id this request references — the booking's own plus
    // each patient's own — must belong to this member; a home-collection
    // visit is a real person going to a real address, so this is never
    // trusted blind the way bare text would be.
    const ownedAddressIds = [dto.addressId, ...dto.patients.map((p) => p.addressId)].filter(
      (id): id is number => id !== undefined && id !== null,
    );
    if (ownedAddressIds.length > 0) {
      const owned = await this.db
        .select({ id: memberAddress.id })
        .from(memberAddress)
        .where(and(inArray(memberAddress.id, ownedAddressIds), eq(memberAddress.memberId, memberId)));
      if (owned.length !== new Set(ownedAddressIds).size) {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'One or more addresses do not belong to this member' } });
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
          fulfillmentType: dto.fulfillmentType,
          scheduledFor: dto.scheduledFor ? new Date(dto.scheduledFor) : undefined,
          healthPassApplied: dto.healthPassApplied,
          healthPassTier: dto.healthPassApplied ? dto.healthPassTier : undefined,
        })
        .returning();

      await tx.insert(labBookingPatient).values(
        dto.patients.map((p) => ({
          labBookingId: created.id,
          patientId: p.patientId,
          name: p.name,
          age: p.age,
          addressId: p.addressId,
        })),
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
      .select({
        ...getTableColumns(labBooking),
        packageName: labPackage.name,
        storeName: shieldStore.name,
        collectorName: adminUser.name,
        billId: labBill.id,
        billStatus: labBill.status,
        // The counter's bill number is small and shown on the list; the bill
        // picture is not (it is a large data URI) — only whether one exists is
        // sent here, and the picture itself is fetched when the order is opened.
        billNumber: labBill.billNumber,
        hasBillImage: sql<boolean>`coalesce(${labBill.image} <> '', false)`,
        house: memberAddress.house,
        area: memberAddress.area,
        landmark: memberAddress.landmark,
        city: memberAddress.city,
        state: memberAddress.state,
        pincode: memberAddress.pincode,
      })
      .from(labBooking)
      .leftJoin(labPackage, eq(labPackage.id, labBooking.labPackageId))
      .leftJoin(shieldStore, eq(shieldStore.id, labBooking.storeId))
      .leftJoin(adminUser, eq(adminUser.id, labBooking.assignedStaffId))
      .leftJoin(memberAddress, eq(memberAddress.id, labBooking.addressId))
      .leftJoin(labBill, eq(labBill.labBookingId, labBooking.id))
      .where(eq(labBooking.memberId, memberId))
      .orderBy(desc(labBooking.createdAt));
    if (rows.length === 0) return [];

    const ids = rows.map((r) => r.id);
    const counts = await this.db
      .select({ labBookingId: labBookingReport.labBookingId, n: sql<number>`count(*)::int` })
      .from(labBookingReport)
      .where(inArray(labBookingReport.labBookingId, ids))
      .groupBy(labBookingReport.labBookingId);
    const pagesById = new Map(counts.map((c) => [c.labBookingId, c.n]));

    // Who the booking is for — names (and ages where known) for the order
    // summary; the full patient record stays a staff-only read.
    const patientRows = await this.db
      .select({
        labBookingId: labBookingPatient.labBookingId,
        ownName: labBookingPatient.name,
        ownAge: labBookingPatient.age,
        patientName: patient.name,
      })
      .from(labBookingPatient)
      .leftJoin(patient, eq(patient.id, labBookingPatient.patientId))
      .where(inArray(labBookingPatient.labBookingId, ids))
      .orderBy(asc(labBookingPatient.id));
    const patientsById = new Map<number, { name: string; age: number | null }[]>();
    for (const p of patientRows) {
      const bucket = patientsById.get(p.labBookingId) ?? [];
      bucket.push({ name: p.ownName?.trim() || p.patientName || 'Patient', age: p.ownAge ?? null });
      patientsById.set(p.labBookingId, bucket);
    }

    return rows.map((r) => {
      const { house, area, landmark, city, state, pincode, billId, billStatus, ...rest } = r;
      const meta = parseBillMeta(r.note);
      return {
        ...rest,
        note: meta.cleanNote,
        fuelCharge: meta.fuelCharge,
        techFee: meta.techFee,
        isVerified: meta.isVerified,
        stage: memberLabStage({ status: r.status, isVerified: meta.isVerified, billExists: billId != null, billStatus }),
        reportPages: pagesById.get(r.id) ?? 0,
        // The collection address an admin may have corrected wins over the
        // member's own saved one, same precedence the console uses.
        address:
          r.addressOverride?.trim() ||
          [house, area, landmark, city, state, pincode].map((part) => (part ?? '').trim()).filter(Boolean).join(', '),
        patientList: patientsById.get(r.id) ?? [],
      };
    });
  }

  async getLabBookingForMember(memberId: number, id: number) {
    const found = await this.getLabBookingOwnedOrThrow(id, memberId);
    const patients = await this.db.select().from(labBookingPatient).where(eq(labBookingPatient.labBookingId, id));
    const [pkg] = await this.db.select({ name: labPackage.name }).from(labPackage).where(eq(labPackage.id, found.labPackageId)).limit(1);
    const [pages] = await this.db
      .select({ n: sql<number>`count(*)::int` })
      .from(labBookingReport)
      .where(eq(labBookingReport.labBookingId, id));
    const meta = parseBillMeta(found.note);
    const [bill] = await this.db
      .select({ id: labBill.id, status: labBill.status, image: labBill.image, billNumber: labBill.billNumber })
      .from(labBill)
      .where(eq(labBill.labBookingId, id))
      .limit(1);
    return {
      ...found,
      note: meta.cleanNote,
      fuelCharge: meta.fuelCharge,
      techFee: meta.techFee,
      isVerified: meta.isVerified,
      stage: memberLabStage({ status: found.status, isVerified: meta.isVerified, billExists: !!bill, billStatus: bill?.status ?? null }),
      // What the admin attached on Lab Bills: the paper bill's number and photo.
      billNumber: bill?.billNumber ?? '',
      billImage: bill?.image ?? '',
      patients,
      packageName: pkg?.name ?? null,
      reportPages: pages?.n ?? 0,
    };
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

  /**
   * Newest booking first, full detail — the "Branch" column and filter on
   * the console's Lab Orders screen.
   *
   * SUPERADMIN, ADMIN and LAB see every branch's bookings: there is one Lab
   * Admin account working every branch, by design, not one each — that
   * doesn't change here. LAB_TECHNICIAN is the new, genuinely store-scoped
   * shape: a store's own lab technician login sees only their own branch's
   * bookings, same as PHARMACY/DELIVERY are already scoped for orders (see
   * order.service.ts's listForStaff, which this mirrors) — empty when their
   * account has no store assigned rather than erroring, the same as that
   * method's own `storeId == null` case.
   */
  async listLabBookingsForStaff(role: AdminRole, storeId: number | null) {
    const unscoped = role === 'SUPERADMIN' || role === 'ADMIN' || role === 'LAB';
    if (!unscoped && storeId == null) return [];

    const rows = await this.db
      .select({
        ...getTableColumns(labBooking),
        memberName: users.name,
        memberPhone: users.phone,
        packageName: labPackage.name,
        storeCode: shieldStore.code,
        storeName: shieldStore.name,
        assignedStaffName: adminUser.name,
        addressPhone: memberAddress.phone,
        house: memberAddress.house,
        area: memberAddress.area,
        landmark: memberAddress.landmark,
        city: memberAddress.city,
        state: memberAddress.state,
        pincode: memberAddress.pincode,
        billImage: labBill.image,
        billNumber: labBill.billNumber,
        billGpayCollected: labBill.gpayCollected,
        billAmount: labBill.amount,
        billDiscount: labBill.discountAmount,
        billStatus: labBill.status,
        billWalletCollected: labBill.walletCollected,
        billCashCollected: labBill.cashCollected,
      })
      .from(labBooking)
      .leftJoin(users, eq(users.id, labBooking.memberId))
      .leftJoin(labPackage, eq(labPackage.id, labBooking.labPackageId))
      .leftJoin(shieldStore, eq(shieldStore.id, labBooking.storeId))
      .leftJoin(adminUser, eq(adminUser.id, labBooking.assignedStaffId))
      .leftJoin(memberAddress, eq(memberAddress.id, labBooking.addressId))
      .leftJoin(labBill, eq(labBill.labBookingId, labBooking.id))
      .where(unscoped ? undefined : eq(labBooking.storeId, storeId!))
      .orderBy(desc(labBooking.createdAt));
    if (rows.length === 0) return [];

    const ids = rows.map((r) => r.id);

    // name/age fallback computed here rather than in SQL (coalesce/nullif/
    // trim over the raw columns) — simpler, and avoids pg-mem's very
    // limited native-function set in tests; the real Postgres difference
    // this replaces was cosmetic (whitespace-only names), not a behavior
    // this needs SQL for.
    const patientAddress = alias(memberAddress, 'patient_address');
    const patientRows = await this.db
      .select({
        id: labBookingPatient.id,
        labBookingId: labBookingPatient.labBookingId,
        patientId: labBookingPatient.patientId,
        ownName: labBookingPatient.name,
        ownAge: labBookingPatient.age,
        patientName: patient.name,
        patientDob: patient.dob,
        savedPhone: patient.phone,
        savedGender: patient.gender,
        savedRelation: patient.relation,
        savedAbhaId: patient.abhaId,
        details: labBookingPatient.details,
        addressId: labBookingPatient.addressId,
        addressOverride: labBookingPatient.addressOverride,
        addrHouse: patientAddress.house,
        addrArea: patientAddress.area,
        addrLandmark: patientAddress.landmark,
        addrCity: patientAddress.city,
        addrState: patientAddress.state,
        addrPincode: patientAddress.pincode,
      })
      .from(labBookingPatient)
      .leftJoin(patient, eq(patient.id, labBookingPatient.patientId))
      .leftJoin(patientAddress, eq(patientAddress.id, labBookingPatient.addressId))
      .where(inArray(labBookingPatient.labBookingId, ids))
      .orderBy(asc(labBookingPatient.id));
    const bookingAddressById = new Map(rows.map((r) => [r.id, r]));
    const patientsByBooking = new Map<
      number,
      { id: number; patientId: number | null; name: string; age: number | null; addressId: number | null; addressOverride: string | null; address: string; phone: string; dob: string; gender: string; relation: string; abhaId: string }[]
    >();
    for (const p of patientRows) {
      const bucket = patientsByBooking.get(p.labBookingId) ?? [];
      const ownFormatted = [p.addrHouse, p.addrArea, p.addrLandmark, p.addrCity, p.addrState, p.addrPincode]
        .map((part) => (part ?? '').trim())
        .filter(Boolean)
        .join(', ');
      // This patient's own address if set (override text first, then its
      // own saved address), else the booking's own shared address — same
      // "override wins, then the real row, then nothing" precedence the
      // booking level already uses.
      const booking = bookingAddressById.get(p.labBookingId);
      const bookingAddress = booking
        ? booking.addressOverride?.trim() ||
          [booking.house, booking.area, booking.landmark, booking.city, booking.state, booking.pincode]
            .map((part) => (part ?? '').trim())
            .filter(Boolean)
            .join(', ')
        : '';
      bucket.push({
        id: p.id,
        patientId: p.patientId,
        name: p.ownName?.trim() || p.patientName || 'Patient',
        age: p.ownAge ?? ageFromDob(p.details?.dob !== undefined ? p.details.dob || null : p.patientDob),
        phone: p.details?.phone ?? p.savedPhone ?? '',
        dob: p.details?.dob ?? p.patientDob ?? '',
        gender: p.details?.gender ?? p.savedGender ?? '',
        relation: p.details?.relation ?? p.savedRelation ?? '',
        abhaId: p.details?.abhaId ?? p.savedAbhaId ?? '',
        addressId: p.addressId,
        addressOverride: p.addressOverride,
        address: p.addressOverride?.trim() || ownFormatted || bookingAddress,
      });
      patientsByBooking.set(p.labBookingId, bucket);
    }

    const reportCounts = await this.db
      .select({ labBookingId: labBookingReport.labBookingId, n: sql<number>`count(*)::int` })
      .from(labBookingReport)
      .where(inArray(labBookingReport.labBookingId, ids))
      .groupBy(labBookingReport.labBookingId);
    const reportCountByBooking = new Map(reportCounts.map((r) => [r.labBookingId, r.n]));

    return rows.map((r) => {
      const { house, area, landmark, city, state, pincode, ...rest } = r;
      const meta = parseBillMeta(r.note);
      return {
        ...rest,
        note: meta.cleanNote,
        fuelCharge: meta.fuelCharge,
        techFee: meta.techFee,
        isVerified: meta.isVerified,
        contactName: r.contactName ?? r.memberName ?? '',
        contactPhone: r.contactPhone ?? r.memberPhone ?? '',
        addressPhone: r.addressPhoneOverride ?? r.addressPhone ?? '',
        code: `LB-${String(r.id).padStart(4, '0')}`,
        // An admin's address override (see updateLabBookingDetails) always
        // wins over the member's own saved address — that's the whole
        // point of it.
        address:
          r.addressOverride?.trim() ||
          [house, area, landmark, city, state, pincode].map((p) => (p ?? '').trim()).filter(Boolean).join(', '),
        patients: patientsByBooking.get(r.id) ?? [],
        reportPages: reportCountByBooking.get(r.id) ?? 0,
        // No app.lab_bill row yet (bill not sent) left-joins to all-null —
        // reads the same as a freshly-sent, unpaid bill rather than a
        // separate "no bill at all" state the console doesn't distinguish.
        billNumber: r.billNumber ?? '',
        billStatus: r.billStatus ?? 'PENDING',
        billAmount: r.billAmount ?? '0',
        billDiscount: r.billDiscount ?? '0',
        billWalletCollected: r.billWalletCollected ?? '0',
        billCashCollected: r.billCashCollected ?? '0',
        billGpayCollected: r.billGpayCollected ?? '0',
      };
    });
  }

  /** Public — the branch picker a member sees before confirming a lab booking. */
  async listLabStoresPublic() {
    return listLabStores(this.db);
  }

  async updateLabBookingStatus(role: AdminRole, storeId: number | null, id: number, dto: UpdateLabBookingStatusDto) {
    const found = await this.getLabBookingOwnedByStaffOrThrow(id, role, storeId);
    assertLegalLabBookingTransition(found.status as LabBookingStatus, dto.status);

    // A home-collection booking needs someone assigned to actually go
    // collect the sample before it can be confirmed — a store-visit one
    // has nobody to send, so this never applies to it.
    if (dto.status === 'CONFIRMED' && found.fulfillmentType === 'HOME_COLLECTION' && found.assignedStaffId == null) {
      throw new ConflictException({
        error: { code: 'STAFF_REQUIRED', message: 'Assign a staff member before confirming this home-collection booking' },
      });
    }

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

  /** The booking's own member's wallet balance, read-only — same shape as
   *  the order-side equivalent, joined through `app.lab_booking` instead.
   *  Lets the bill panel show what collecting would actually draw before
   *  committing to anything. */
  /**
   * The four Health Pass figures the lab-booking bill modal shows staff
   * before they send the collection OTP — same shape and same pure
   * functions `OrderService.getWalletPreview` uses, so a lab bill
   * collection never disagrees with what this preview showed. `0` across
   * the board for a member with no wallet row at all, same as
   * `collectLabBillWithWallet` treats one.
   */
  async getWalletBalanceForLabBooking(role: AdminRole, storeId: number | null, bookingId: number) {
    const found = await this.getLabBookingOwnedByStaffOrThrow(bookingId, role, storeId);
    const [theWallet] = await this.db.select().from(wallet).where(eq(wallet.memberId, found.memberId)).limit(1);
    if (!theWallet) {
      return { balance: 0, availableAllowance: 0, monthlyRedeemable: 0, redeemedThisMonth: 0 };
    }

    const balance = Number(theWallet.balance);
    const { cards, entries } = await this.walletMonthInputs(this.db, theWallet.id);
    const now = new Date();

    return {
      balance,
      availableAllowance: cards.length === 0 ? balance : availablePlanAllowance(cards, entries, now, balance),
      monthlyRedeemable: redeemableAllowance(cards, entries, now),
      redeemedThisMonth: redeemedThisMonth(entries, now),
    };
  }

  /**
   * What a Health Pass plan's home-collection charge costs the member, per
   * tier — Silver and Gold are flat rates that never change; Platinum is
   * free for its first [PLATINUM_HOMECARE_FREE_VISITS] lifetime visits,
   * tracked on `wallet.platinum_homecare_used` (migration 0111), and falls
   * through to the ordinary fuel/technician-charge flow once that runs out.
   * See privilege_tier.dart's own `benefits` getter — this is the backend's
   * copy of the same rates quoted there.
   */
  static readonly PLATINUM_HOMECARE_FREE_VISITS = 6;

  /**
   * [healthPassTier] on a booking is the member's own card name as
   * privilege_tier.dart prints it — "Silver Shield", "Gold Shield",
   * "Platinum Shield" — not the bare tier word, so this matches by
   * substring rather than equality. Returns null for anything that does
   * not contain one of the three.
   */
  private healthPassTierKind(tier: string): 'silver' | 'gold' | 'platinum' | null {
    const lower = tier.toLowerCase();
    if (lower.includes('silver')) return 'silver';
    if (lower.includes('gold')) return 'gold';
    if (lower.includes('platinum')) return 'platinum';
    return null;
  }

  private healthPassHomeCareRate(kind: 'silver' | 'gold' | 'platinum'): number {
    switch (kind) {
      case 'silver':
        return 50;
      case 'gold':
        return 20;
      case 'platinum':
        return 0;
    }
  }

  /**
   * The fixed home-collection charge the lab order editor preloads (and
   * locks fuel/technician fields against) when the member applied their
   * Health Pass coupon at checkout — `locked: false` means there is nothing
   * to preload, either because no coupon was applied, the tier is
   * unrecognised, or (Platinum only) the member's free visits have run out,
   * and the editor falls back to its normal fuel/technician-charge inputs.
   */
  async getHealthPassChargeForLabBooking(role: AdminRole, storeId: number | null, bookingId: number) {
    const found = await this.getLabBookingOwnedByStaffOrThrow(bookingId, role, storeId);
    if (!found.healthPassApplied || !found.healthPassTier) {
      return { applied: false, tier: null, locked: false, fixedCharge: 0, platinumUsed: null, platinumRemaining: null, platinumTotal: null };
    }
    const kind = this.healthPassTierKind(found.healthPassTier);
    if (kind === null) {
      return { applied: true, tier: found.healthPassTier, locked: false, fixedCharge: 0, platinumUsed: null, platinumRemaining: null, platinumTotal: null };
    }
    if (kind !== 'platinum') {
      return { applied: true, tier: kind, locked: true, fixedCharge: this.healthPassHomeCareRate(kind), platinumUsed: null, platinumRemaining: null, platinumTotal: null };
    }
    const [theWallet] = await this.db.select().from(wallet).where(eq(wallet.memberId, found.memberId)).limit(1);
    const used = theWallet ? theWallet.platinumHomecareUsed : 0;
    const total = BookingService.PLATINUM_HOMECARE_FREE_VISITS;
    const remaining = Math.max(0, total - used);
    return {
      applied: true,
      tier: kind,
      locked: remaining > 0,
      fixedCharge: 0,
      platinumUsed: used,
      platinumRemaining: remaining,
      platinumTotal: total,
    };
  }

  /** Correct this booking only; saved member/patient/address records remain unchanged. */
  async updateLabBookingDetails(role: AdminRole, storeId: number | null, bookingId: number, dto: UpdateLabBookingDetailsDto) {
    await this.getLabBookingOwnedByStaffOrThrow(bookingId, role, storeId);
    return this.db.transaction(async (tx) => {
      const [found] = await tx.select().from(labBooking).where(eq(labBooking.id, bookingId)).limit(1).for('update');
      if (!found || (role !== 'ADMIN' && role !== 'SUPERADMIN' && role !== 'LAB' && found.storeId !== storeId)) {
        throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab booking not found' } });
      }
      const fullEditor = role === 'ADMIN' || role === 'SUPERADMIN' || role === 'LAB';
      const advancedEdit = ['contactName', 'contactPhone', 'addressPhone', 'labPackageId', 'fulfillmentType', 'assignedStaffId', 'unitPrice'].some((key) => key in dto);
      if (advancedEdit && !fullEditor) {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Only a lab administrator can edit these order fields.' } });
      }
      if (found.status === 'CANCELLED' && !fullEditor) return found;

      let nextStoreId: number | undefined;
      if (dto.storeId !== undefined && dto.storeId !== found.storeId) {
        const labStores = await listLabStores(tx);
        if (!labStores.some((s) => s.id === dto.storeId)) {
          throw new BadRequestException({ error: { code: 'BAD_REQUEST', message: 'That branch is not open for lab bookings.' } });
        }
        nextStoreId = dto.storeId;
      }

      const nextPackageId = dto.labPackageId ?? found.labPackageId;
      let nextUnitPrice = Number(found.unitPrice);
      let nextPackageName: string | undefined;
      if (dto.labPackageId !== undefined && dto.labPackageId !== found.labPackageId) {
        const [pkg] = await tx.select().from(labPackage).where(eq(labPackage.id, nextPackageId)).limit(1);
        if (!pkg?.isActive) throw new BadRequestException({ error: { code: 'BAD_REQUEST', message: 'Choose an active lab test or package.' } });
        const reports = await this.db.select({ id: labBookingReport.id }).from(labBookingReport).where(eq(labBookingReport.labBookingId, bookingId)).limit(1);
        if (reports.length) throw new ConflictException({ error: { code: 'REPORT_ATTACHED', message: 'Remove the existing test report before changing the test.' } });
        nextUnitPrice = Number(pkg.price);
        nextPackageName = pkg.name;
      }
      if (dto.unitPrice !== undefined) nextUnitPrice = dto.unitPrice;
      const nextCount = dto.patients?.length ?? found.patientsCount;
      const nextFixCharge = dto.fixCharge !== undefined ? dto.fixCharge : Number(found.fixCharge ?? 0);
      const priceChanged =
        nextUnitPrice !== Number(found.unitPrice) ||
        nextCount !== found.patientsCount ||
        nextPackageId !== found.labPackageId ||
        nextFixCharge !== Number(found.fixCharge ?? 0);
      const nextFulfillment = dto.fulfillmentType ?? found.fulfillmentType;
      let nextStaff = dto.assignedStaffId !== undefined ? dto.assignedStaffId : found.assignedStaffId;
      if (nextFulfillment === 'STORE_VISIT') nextStaff = null;
      if (nextStaff != null && (nextStaff !== found.assignedStaffId || nextStoreId !== undefined || nextFulfillment !== found.fulfillmentType)) {
        const [staff] = await tx.select().from(adminUser).where(eq(adminUser.id, nextStaff)).limit(1);
        if (!staff?.isActive || staff.role !== 'LAB_TECHNICIAN' || staff.storeId !== (nextStoreId ?? found.storeId)) {
          throw new BadRequestException({ error: { code: 'BAD_REQUEST', message: 'Choose an active lab technician from the selected branch.' } });
        }
      }
      if (nextFulfillment === 'HOME_COLLECTION' && !nextStaff && found.status !== 'REQUESTED' && found.status !== 'CANCELLED') {
        throw new ConflictException({ error: { code: 'STAFF_REQUIRED', message: 'Assign a technician for this home-collection booking.' } });
      }

      const [bill] = await tx.select().from(labBill).where(eq(labBill.labBookingId, bookingId)).limit(1).for('update');
      if (priceChanged && bill?.status === 'PAID') {
        throw new ConflictException({ error: { code: 'BILL_PAID', message: 'This bill has been collected. Correct charges through billing before changing the test, price or patient count.' } });
      }
      const previousPatients = await tx.select().from(labBookingPatient).where(eq(labBookingPatient.labBookingId, bookingId));
      if (dto.patients) {
        const ownedPatientIds = dto.patients.map((p) => p.patientId).filter((pid): pid is number => pid !== undefined);
        if (ownedPatientIds.length > 0) {
          const owned = await tx
            .select({ id: patient.id })
            .from(patient)
            .where(and(inArray(patient.id, ownedPatientIds), eq(patient.memberId, found.memberId)));
          if (owned.length !== new Set(ownedPatientIds).size) {
            throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'One or more patients do not belong to this member' } });
          }
        }
        const ownedAddressIds = dto.patients.map((p) => p.addressId).filter((aid): aid is number => aid !== undefined && aid !== null);
        if (ownedAddressIds.length > 0) {
          const owned = await tx
            .select({ id: memberAddress.id })
            .from(memberAddress)
            .where(and(inArray(memberAddress.id, ownedAddressIds), eq(memberAddress.memberId, found.memberId)));
          if (owned.length !== new Set(ownedAddressIds).size) {
            throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'One or more addresses do not belong to this member' } });
          }
        }
        await tx.delete(labBookingPatient).where(eq(labBookingPatient.labBookingId, bookingId));
        await tx.insert(labBookingPatient).values(
          dto.patients.map((p) => {
            const previous = p.bookingPatientId !== undefined
              ? previousPatients.find((old) => old.id === p.bookingPatientId)
              : p.patientId !== undefined ? previousPatients.find((old) => old.patientId === p.patientId) : undefined;
            if (p.bookingPatientId !== undefined && !previous) {
              throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'That patient row does not belong to this booking.' } });
            }
            const details = { ...previous?.details };
            for (const key of ['phone', 'dob', 'gender', 'relation', 'abhaId'] as const) {
              if (p[key] !== undefined) details[key] = p[key]!;
            }
            return {
              labBookingId: bookingId,
              patientId: p.patientId ?? previous?.patientId,
              name: p.name ?? previous?.name,
              age: p.dob ? ageFromDob(p.dob) : p.age ?? previous?.age,
              details: Object.keys(details).length ? details : null,
              addressId: p.addressId !== undefined ? p.addressId : previous?.addressId,
              addressOverride: p.addressOverride !== undefined ? p.addressOverride?.trim() || null : previous?.addressOverride,
            };
          }),
        );
      }

      await tx
        .update(labBooking)
        .set({
          note: dto.note,
          scheduledFor: found.status === 'REPORT_READY' && !fullEditor ? found.scheduledFor : dto.scheduledFor ? new Date(dto.scheduledFor) : null,
          contactName: dto.contactName,
          contactPhone: dto.contactPhone,
          addressPhoneOverride: dto.addressPhone,
          fulfillmentType: nextFulfillment,
          assignedStaffId: nextStaff,
          labPackageId: nextPackageId,
          unitPrice: nextUnitPrice.toFixed(2),
          fixCharge: nextFixCharge.toFixed(2),
          patientsCount: nextCount,
          totalPrice: (nextUnitPrice * nextCount + nextFixCharge).toFixed(2),
          ...(nextStoreId !== undefined ? { storeId: nextStoreId } : {}),
          ...(dto.address !== undefined ? { addressOverride: dto.address.trim() || null } : {}),

          updatedAt: new Date(),
        })
        .where(eq(labBooking.id, bookingId));
      if (priceChanged && bill) {
        const nextTotal = nextUnitPrice * nextCount + nextFixCharge;
        const amount = Math.max(nextTotal - Number(bill.discountAmount), 0).toFixed(2);
        await tx.update(labBill).set({ amount, updatedAt: new Date() }).where(eq(labBill.id, bill.id));
        await tx.update(labBillLine).set({ unitPrice: nextUnitPrice.toFixed(2), qty: nextCount, ...(nextPackageName ? { name: nextPackageName } : {}) }).where(eq(labBillLine.labBillId, bill.id));
      }

      // One of Platinum's 6 lifetime complimentary home-care visits is
      // spent the moment the lab order editor's "Verify Bill" button first
      // marks this booking verified — the transition this note's own
      // [BILL_VERIFIED: ...] tag carries, not every later edit: a plain
      // field correction after verifying (contact phone, schedule, …)
      // reaches here too and must never charge a second visit for the same
      // booking. Re-verifying after changing the charges themselves
      // (`verifiedChargesChanged` client-side) also skips this, since
      // `wasVerified` is already true by then.
      const wasVerified = parseBillMeta(found.note).isVerified;
      const willBeVerified = parseBillMeta(dto.note).isVerified;
      if (!wasVerified && willBeVerified && found.healthPassApplied && found.healthPassTier && this.healthPassTierKind(found.healthPassTier) === 'platinum') {
        const [theWallet] = await tx.select().from(wallet).where(eq(wallet.memberId, found.memberId)).limit(1).for('update');
        if (theWallet && theWallet.platinumHomecareUsed < BookingService.PLATINUM_HOMECARE_FREE_VISITS) {
          await tx
            .update(wallet)
            .set({ platinumHomecareUsed: theWallet.platinumHomecareUsed + 1, updatedAt: new Date() })
            .where(eq(wallet.id, theWallet.id));
        }
      }
    });
  }

  /** LAB_TECHNICIAN-role staff at one branch (or every branch when
   *  [storeCode] is omitted — a Super Admin/Admin/Lab Admin's assignment
   *  picker, which isn't store-bound) — who a home-collection booking's
   *  sample can be assigned to. Same shape as commerce's listDeliveryBoys. */
  async listLabStaff(storeCode?: string) {
    const conditions = [eq(adminUser.role, 'LAB_TECHNICIAN' as AdminRole), eq(adminUser.isActive, true)];
    return this.db
      .select({ id: adminUser.id, name: adminUser.name, storeCode: shieldStore.code })
      .from(adminUser)
      .innerJoin(shieldStore, eq(shieldStore.id, adminUser.storeId))
      .where(storeCode ? and(...conditions, eq(shieldStore.code, storeCode)) : and(...conditions))
      .orderBy(adminUser.name);
  }

  /**
   * Assigns (or clears, passing null) who collects a home-collection
   * booking's sample — store-scoped like every other lab-booking write
   * here. A LAB_TECHNICIAN caller may only claim it for themselves or
   * release it, never hand it to someone else, the same restriction
   * commerce's assignDeliveryBoy applies to a DELIVERY caller.
   */
  async assignLabStaff(role: AdminRole, storeId: number | null, callerId: number, bookingId: number, dto: AssignLabStaffDto) {
    await this.getLabBookingOwnedByStaffOrThrow(bookingId, role, storeId);
    if (role === 'LAB_TECHNICIAN' && dto.staffId !== null && dto.staffId !== callerId) {
      throw new ForbiddenException({
        error: { code: 'FORBIDDEN', message: 'A lab technician login may only claim a booking for itself' },
      });
    }
    await this.db.update(labBooking).set({ assignedStaffId: dto.staffId, updatedAt: new Date() }).where(eq(labBooking.id, bookingId));
    return { ok: true as const };
  }

  /** The pages of one booking's report, in order. */
  async listLabReportPages(role: AdminRole, storeId: number | null, bookingId: number) {
    await this.getLabBookingOwnedByStaffOrThrow(bookingId, role, storeId);
    return this.db
      .select({ id: labBookingReport.id, name: labBookingReport.name, image: labBookingReport.image })
      .from(labBookingReport)
      .where(eq(labBookingReport.labBookingId, bookingId))
      .orderBy(asc(labBookingReport.sort), asc(labBookingReport.id));
  }

  /** Attaches [dto.pages] (already resized to JPEG data URIs) after the ones
   *  already there, and stamps when the report was last touched. */
  async addLabReportPages(role: AdminRole, storeId: number | null, bookingId: number, dto: AddLabReportPagesDto) {
    await this.getLabBookingOwnedByStaffOrThrow(bookingId, role, storeId);
    const [last] = await this.db
      .select({ sort: labBookingReport.sort })
      .from(labBookingReport)
      .where(eq(labBookingReport.labBookingId, bookingId))
      .orderBy(desc(labBookingReport.sort))
      .limit(1);
    let sort = (last?.sort ?? -1) + 1;
    for (const page of dto.pages) {
      await this.db.insert(labBookingReport).values({ labBookingId: bookingId, name: page.name, image: page.image, sort: sort++ });
    }
    await this.db.update(labBooking).set({ reportUploadedAt: new Date(), updatedAt: new Date() }).where(eq(labBooking.id, bookingId));
  }

  /** Removes one report page. A booking already marked Report ready keeps
   *  its last page — refused rather than leaving the member with a "ready"
   *  report that is empty. */
  async removeLabReportPage(role: AdminRole, storeId: number | null, bookingId: number, pageId: number) {
    const found = await this.getLabBookingOwnedByStaffOrThrow(bookingId, role, storeId);
    const [{ n }] = await this.db
      .select({ n: sql<number>`count(*)::int` })
      .from(labBookingReport)
      .where(eq(labBookingReport.labBookingId, bookingId));
    if (found.status === 'CANCELLED' || (found.status === 'REPORT_READY' && n <= 1)) {
      throw new ConflictException({
        error: { code: 'CONFLICT', message: 'That page could not be removed — a Report ready booking keeps at least one page.' },
      });
    }
    const [deleted] = await this.db
      .delete(labBookingReport)
      .where(and(eq(labBookingReport.id, pageId), eq(labBookingReport.labBookingId, bookingId)))
      .returning();
    if (!deleted) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Report page not found' } });

    const [remaining] = await this.db
      .select({ n: sql<number>`count(*)::int` })
      .from(labBookingReport)
      .where(eq(labBookingReport.labBookingId, bookingId));
    await this.db
      .update(labBooking)
      .set({ reportUploadedAt: remaining.n > 0 ? new Date() : null, updatedAt: new Date() })
      .where(eq(labBooking.id, bookingId));
  }

  /**
   * Prices a booking's bill — same "Convert to bill" step a prescription
   * order gets, but with nothing for staff to pick: a lab booking's price is
   * already fixed at booking time (lab_package.price × patients), so the one
   * line item is built here from the booking's own row, not typed in by
   * hand. `dto.discountAmount` is the only real input; `amount` (what's
   * actually owed, and what {@link collectLabBillWithWallet} reads) is the
   * booking's total net of it. Upserts app.lab_bill the same one-row-per-
   * booking way app.bill is upserted per order (lab_booking_id is UNIQUE),
   * and replaces its one lab_bill_line row so re-sending after the booking's
   * own price ever changes doesn't leave a stale line behind.
   */
  async sendLabBill(role: AdminRole, storeId: number | null, bookingId: number, dto: SendLabBillDto) {
    const found = await this.getLabBookingOwnedByStaffOrThrow(bookingId, role, storeId);
    return this.db.transaction(async (tx) => {
      const [found] = await tx.select().from(labBooking).where(eq(labBooking.id, bookingId)).limit(1).for('update');
      const [pkg] = await tx.select({ name: labPackage.name }).from(labPackage).where(eq(labPackage.id, found.labPackageId)).limit(1);
      const amount = Math.max(Number(found.totalPrice) - dto.discountAmount, 0);
      const [existing] = await tx.select().from(labBill).where(eq(labBill.labBookingId, bookingId)).limit(1).for('update');
      if (existing?.status === 'PAID') throw new ConflictException({ error: { code: 'BILL_PAID', message: 'A collected bill cannot be repriced.' } });
      // A blank value keeps whatever is already on record, so converting to a
      // bill from Lab Orders (no picture or number yet) and filling them in on
      // Lab Bills later both work. They are enforced when payment is collected.
      const image = dto.image || existing?.image || '';
      const billNumber = dto.billNumber.trim() || existing?.billNumber || null;
      let billId: number;
      if (existing) {
        await tx
          .update(labBill)
          .set({
            image,
            billNumber,
            amount: amount.toString(),
            discountAmount: dto.discountAmount.toString(),
            sentAt: new Date(),
            updatedAt: new Date(),
          })
          .where(eq(labBill.id, existing.id));
        billId = existing.id;
        await tx.delete(labBillLine).where(eq(labBillLine.labBillId, billId));
      } else {
        const [created] = await tx
          .insert(labBill)
          .values({
            labBookingId: bookingId,
            image,
            billNumber,
            amount: amount.toString(),
            discountAmount: dto.discountAmount.toString(),
          })
          .returning({ id: labBill.id });
        billId = created.id;
      }
      await tx.insert(labBillLine).values({
        labBillId: billId,
        name: pkg?.name ?? 'Lab package',
        unitPrice: found.unitPrice,
        qty: found.patientsCount,
      });
      if (Number(found.fixCharge || 0) > 0) {
        await tx.insert(labBillLine).values({
          labBillId: billId,
          name: 'Fixed charge / Collection fee',
          unitPrice: Number(found.fixCharge).toFixed(2),
          qty: 1,
        });
      }

      const [result] = await tx.select().from(labBill).where(eq(labBill.id, billId)).limit(1);
      return result;
    });
  }

  /**
   * Settles a sent-and-priced lab bill — mirrors
   * order.service.ts's collectBillWithWallet exactly (see that method's own
   * doc, including its trust-boundary note: OTP verification happens
   * client-side in shieldweb before this is ever called). Draws on the
   * member's wallet first, up to what it actually holds, and treats the rest
   * as collected in cash in the same action.
   */
  /**
   * Posts a store's cash/wallet receipt against a lab bill to the ledger
   * (migrations 0074–0076), mirroring OrderService.postOrderCollection —
   * same `app.posting_rule` mapping, same tolerance: never blocks the real
   * collection, since this is new, still-unreviewed infrastructure riding
   * alongside working code that moves real money.
   */
  private async postLabBillCollection(
    tx: Database,
    params: { bookingId: number; storeId: number | null; memberId: number; cash: number; wallet: number },
  ) {
    try {
      if (!params.storeId) return;
      const [store] = await tx.select({ entityId: shieldStore.entityId }).from(shieldStore).where(eq(shieldStore.id, params.storeId));
      if (!store?.entityId) return;

      const mapped = await tx
        .select({ lineRole: postingRule.lineRole, accountId: chartOfAccount.id })
        .from(postingRule)
        .innerJoin(chartOfAccount, eq(chartOfAccount.code, postingRule.accountCode))
        .where(and(eq(postingRule.event, 'lab_bill_collected'), inArray(postingRule.lineRole, ['cash_in', 'wallet_in', 'revenue'])));
      const byRole: Record<string, number> = Object.fromEntries(mapped.map((a) => [a.lineRole, a.accountId]));
      if (!byRole.cash_in || !byRole.wallet_in || !byRole.revenue) return;

      const lines: { accountId: number; debit: string; credit: string; subjectType?: string; subjectId?: number }[] = [];
      if (params.cash > 0) lines.push({ accountId: byRole.cash_in, debit: params.cash.toFixed(2), credit: '0' });
      if (params.wallet > 0) {
        lines.push({
          accountId: byRole.wallet_in,
          debit: params.wallet.toFixed(2),
          credit: '0',
          subjectType: 'member',
          subjectId: params.memberId,
        });
      }
      const total = params.cash + params.wallet;
      if (total <= 0 || lines.length === 0) return;
      lines.push({ accountId: byRole.revenue, debit: '0', credit: total.toFixed(2) });

      const [entry] = await tx
        .insert(journalEntry)
        .values({
          id: randomUUID(),
          entityId: store.entityId,
          postedOn: new Date().toISOString().slice(0, 10),
          sourceTable: 'lab_bill',
          // One entry per collection step (wallet, then each cash/GPay receipt) —
          // the same suffix a standard order's collections use.
          sourceId: `${params.bookingId}-${randomUUID().slice(0, 8)}`,
          event: 'lab_bill_collected',
          description: `Lab booking LB-${params.bookingId.toString().padStart(4, '0')} collected`,
        })
        .returning();
      if (!entry) return;

      await tx.insert(journalLine).values(
        lines.map((l) => ({
          entryId: entry.id,
          accountId: l.accountId,
          debit: l.debit,
          credit: l.credit,
          subjectType: l.subjectType,
          subjectId: l.subjectId,
        })),
      );
    } catch {
      // Ledger posting must never block a real payment being recorded.
    }
  }

  /**
   * What a member's wallet is actually good for right now: their balance,
   * further capped by what's left of this month's Health Pass allowance —
   * same calculation `OrderService.availableWalletCapForMember` uses,
   * ported from shieldweb's `walletMonth.ts` so a lab bill collection never
   * disagrees with the preview staff were already shown. A member with no
   * approved wallet card isn't on Health Pass, so nothing caps them beyond
   * their own balance.
   */
  /**
   * The cards/entries shape `wallet-month.ts`'s pure functions all take, for
   * one member's wallet — shared by `availableWalletCapForMember` and
   * `getWalletBalanceForLabBooking` so there is one query for it, not two.
   */
  private async walletMonthInputs(tx: Database, walletId: number) {
    const cards = await tx
      .select({ amount: walletCard.amount, bonus: walletCard.bonus, rechargedExtra: walletCard.rechargedExtra, issuedOn: walletCard.issuedOn })
      .from(walletCard)
      .where(and(eq(walletCard.walletId, walletId), eq(walletCard.status, 'APPROVED')));
    const entries = await tx
      .select({ kind: walletEntry.kind, amount: walletEntry.amount, occurredOn: walletEntry.occurredOn, createdAt: walletEntry.createdAt })
      .from(walletEntry)
      .where(eq(walletEntry.walletId, walletId))
      .orderBy(walletEntry.createdAt, walletEntry.id);
    return {
      cards: cards.map((c) => ({ loaded: Number(c.amount) + Number(c.bonus) + Number(c.rechargedExtra), issuedOn: toIsoDate(c.issuedOn) })),
      entries: entries.map((e) => ({ kind: e.kind, amount: Number(e.amount), occurredOn: toIsoDate(e.occurredOn) })),
    };
  }

  private async availableWalletCapForMember(tx: Database, walletId: number, balance: number): Promise<number> {
    const { cards, entries } = await this.walletMonthInputs(tx, walletId);
    if (cards.length === 0) {
      return balance;
    }
    return availablePlanAllowance(cards, entries, new Date(), balance);
  }

  async collectLabBillWithWallet(role: AdminRole, storeId: number | null, bookingId: number) {
    const found = await this.getLabBookingOwnedByStaffOrThrow(bookingId, role, storeId);

    return this.db.transaction(async (tx) => {
      const [found] = await tx.select().from(labBooking).where(eq(labBooking.id, bookingId)).limit(1).for('update');
      if (role !== 'ADMIN' && role !== 'SUPERADMIN' && role !== 'LAB' && found.storeId !== storeId) {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'This booking is no longer at your branch.' } });
      }
    const [theBill] = await tx.select().from(labBill).where(eq(labBill.labBookingId, bookingId)).limit(1).for('update');
    if (!theBill) {
      return { ok: false as const, reason: 'No bill has been sent for this booking yet.' };
    }
    if (theBill.status === 'PAID') {
      return { ok: false as const, reason: 'This bill is already paid.' };
    }
    // The paper bill's photo and number are mandatory before any money moves
    // (Lab Bills' own form enforces the same; this is the server-side gate).
    if (!theBill.image) {
      return { ok: false as const, reason: 'Upload a picture of the bill first.' };
    }
    if (!theBill.billNumber) {
      return { ok: false as const, reason: 'Enter the bill number first.' };
    }
    const billAmount = Number(theBill.amount);
    if (billAmount <= 0) {
      return { ok: false as const, reason: 'This bill has not been priced yet.' };
    }

      const alreadyWallet = Number(theBill.walletCollected);
      // The wallet step runs once. A repeat (the counter reopened the dialog
      // after the wallet was already debited) only reports what is still owed.
      if (alreadyWallet > 0) {
        const owed = billAmount - alreadyWallet - Number(theBill.cashCollected) - Number(theBill.gpayCollected);
        return { ok: true as const, walletAmount: alreadyWallet, cashAmount: Math.max(owed, 0), settled: owed <= 0 };
      }

      const [theWallet] = await tx.select().from(wallet).where(eq(wallet.memberId, found.memberId)).limit(1).for('update');
      const balance = theWallet ? Number(theWallet.balance) : 0;
      // Capped at this month's Health Pass allowance, not just the raw
      // balance — see OrderService.collectBillWithWallet's identical fix for
      // why: without it, a member who has already used up this month's
      // allowance could still have their whole wallet balance drawn here.
      const walletCap = theWallet ? await this.availableWalletCapForMember(tx, theWallet.id, balance) : 0;
      const walletAmount = Math.min(walletCap, billAmount);
      const cashAmount = billAmount - walletAmount;

      if (theWallet && walletAmount > 0) {
        await tx
          .update(wallet)
          .set({ balance: (balance - walletAmount).toString(), updatedAt: new Date() })
          .where(eq(wallet.id, theWallet.id));
        await tx.insert(walletEntry).values({
          walletId: theWallet.id,
          kind: 'SPEND',
          label: `Lab booking LB-${found.id.toString().padStart(4, '0')}`,
          amount: (-walletAmount).toString(),
          occurredOn: new Date().toISOString().slice(0, 10),
          labBookingId: found.id,
        });
      }

      // Same split a standard order's bill gets: the wallet is debited here,
      // and the bill is paid only when that covered everything. Whatever the
      // wallet could not cover is still owed and is received afterwards as
      // GPay / cash through receiveLabBillPayment — never assumed collected.
      const settled = cashAmount <= 0;
      if (walletAmount > 0 || settled) {
        await tx
          .update(labBill)
          .set({
            ...(settled ? { status: 'PAID' as const, paidAt: new Date() } : {}),
            walletCollected: walletAmount.toString(),
            updatedAt: new Date(),
          })
          .where(eq(labBill.id, theBill.id));
      }

      if (walletAmount > 0) {
        await this.postLabBillCollection(tx, {
          bookingId: found.id,
          storeId: found.storeId,
          memberId: found.memberId,
          cash: 0,
          wallet: walletAmount,
        });
      }

      return { ok: true as const, walletAmount, cashAmount, settled };
    });
  }

  /**
   * Records GPay and/or cash the counter takes against a lab bill after the
   * wallet step — the lab twin of OrderService.receiveBillPayment. Refuses
   * more than is still owed; marks the bill PAID once it is covered. GPay is
   * posted to the ledger with cash (the lab posting rule has one cash account).
   */
  async receiveLabBillPayment(role: AdminRole, storeId: number | null, bookingId: number, dto: ReceiveLabBillPaymentDto) {
    const found = await this.getLabBookingOwnedByStaffOrThrow(bookingId, role, storeId);

    return this.db.transaction(async (tx) => {
      const [current] = await tx.select().from(labBill).where(eq(labBill.labBookingId, bookingId)).limit(1).for('update');
      if (!current) return { ok: false as const, reason: 'No bill has been sent for this booking yet.' };
      if (current.status === 'PAID') return { ok: false as const, reason: 'This bill is already paid.' };
      if (Number(current.amount) <= 0) return { ok: false as const, reason: 'This bill has not been priced yet.' };

      const toPaise = (rupees: number) => Math.round(rupees * 100);
      const fromPaise = (paise: number) => (paise / 100).toFixed(2);
      const owedPaise =
        toPaise(Number(current.amount)) -
        toPaise(Number(current.walletCollected)) -
        toPaise(Number(current.cashCollected)) -
        toPaise(Number(current.gpayCollected));
      const cashPaise = toPaise(dto.cash);
      const gpayPaise = toPaise(dto.gpay);
      const receivingPaise = cashPaise + gpayPaise;

      if (owedPaise <= 0) return { ok: false as const, reason: 'Nothing is left to receive on this bill.' };
      if (receivingPaise > owedPaise) {
        return { ok: false as const, reason: `Only ₹${(owedPaise / 100).toFixed(2)} is still owed on this bill.` };
      }

      const settled = receivingPaise === owedPaise;
      await tx
        .update(labBill)
        .set({
          cashCollected: fromPaise(toPaise(Number(current.cashCollected)) + cashPaise),
          gpayCollected: fromPaise(toPaise(Number(current.gpayCollected)) + gpayPaise),
          ...(settled ? { status: 'PAID' as const, paidAt: new Date() } : {}),
          updatedAt: new Date(),
        })
        .where(eq(labBill.id, current.id));

      await this.postLabBillCollection(tx, {
        bookingId: found.id,
        storeId: found.storeId,
        memberId: found.memberId,
        cash: receivingPaise / 100,
        wallet: 0,
      });

      return {
        ok: true as const,
        receivedCash: fromPaise(cashPaise),
        receivedGpay: fromPaise(gpayPaise),
        remaining: fromPaise(owedPaise - receivingPaise),
        settled,
      };
    });
  }

  /** Same shape as order.service.ts's getOwnedByStaffOrThrow — SUPERADMIN,
   *  ADMIN and LAB (unscoped, see listLabBookingsForStaff's own doc) may
   *  manage any booking; LAB_TECHNICIAN only one at their own store. */
  private async getLabBookingOwnedByStaffOrThrow(id: number, role: AdminRole, storeId: number | null) {
    const conditions = [eq(labBooking.id, id)];
    if (role !== 'SUPERADMIN' && role !== 'ADMIN' && role !== 'LAB') {
      if (storeId == null) {
        throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Staff account has no store assigned' } });
      }
      conditions.push(eq(labBooking.storeId, storeId));
    }
    const [found] = await this.db.select().from(labBooking).where(and(...conditions)).limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Lab booking not found' } });
    return found;
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

  /**
   * No branch scoping — appointment has no store_id in the live schema
   * either. Joined out to the member/provider/store names the console's
   * card actually shows, matching what `shieldweb`'s own direct SQL used to
   * do before this route existed — see migration-plan.md Phase 1.
   */
  async listAppointmentsForStaff() {
    const memberStore = alias(shieldStore, 'member_store');
    return this.db
      .select({
        id: appointment.id,
        memberName: users.name,
        memberPhone: users.phone,
        kind: appointment.kind,
        providerName: sql<string>`coalesce(${clinic.name}, ${dietitian.name}, ${appointment.doctorName}, 'Sahakar 360 Tele-Consult')`,
        storeName: memberStore.name,
        scheduledFor: appointment.scheduledFor,
        status: appointment.status,
        remarks: appointment.remarks,
        createdAt: appointment.createdAt,
      })
      .from(appointment)
      .leftJoin(users, eq(users.id, appointment.memberId))
      .leftJoin(clinic, eq(clinic.id, appointment.clinicId))
      .leftJoin(dietitian, eq(dietitian.id, appointment.dietitianId))
      .leftJoin(memberStore, eq(memberStore.id, users.homeStoreId))
      .orderBy(desc(appointment.createdAt));
  }

  async updateAppointmentStatus(id: number, dto: UpdateAppointmentStatusDto) {
    const [found] = await this.db.select().from(appointment).where(eq(appointment.id, id)).limit(1);
    if (!found) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Appointment not found' } });
    assertLegalAppointmentTransition(found.status as AppointmentStatus, dto.status);

    const [updated] = await this.db.update(appointment).set({ status: dto.status }).where(eq(appointment.id, id)).returning();
    return updated;
  }
}
