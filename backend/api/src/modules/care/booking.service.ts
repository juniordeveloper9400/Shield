import { ConflictException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, asc, desc, eq, getTableColumns, inArray, sql } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import {
  appointment,
  chartOfAccount,
  dietitian,
  journalEntry,
  journalLine,
  labBill,
  labBillLine,
  labBooking,
  labBookingPatient,
  labBookingReport,
  labPackage,
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
import { availablePlanAllowance, toIsoDate } from '../wallet/wallet-month';
import { assertLegalAppointmentTransition, assertLegalLabBookingTransition, type AppointmentStatus, type LabBookingStatus } from './care-status';
import type {
  BookAppointmentDto,
  BookLabTestDto,
  SendLabBillDto,
  UpdateAppointmentStatusDto,
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
    return this.db
      .select({ ...getTableColumns(labBooking), storeCode: shieldStore.code, storeName: shieldStore.name })
      .from(labBooking)
      .leftJoin(shieldStore, eq(shieldStore.id, labBooking.storeId))
      .where(unscoped ? undefined : eq(labBooking.storeId, storeId!))
      .orderBy(desc(labBooking.createdAt));
  }

  /** Public — the branch picker a member sees before confirming a lab booking. */
  async listLabStoresPublic() {
    return listLabStores(this.db);
  }

  async updateLabBookingStatus(role: AdminRole, storeId: number | null, id: number, dto: UpdateLabBookingStatusDto) {
    const found = await this.getLabBookingOwnedByStaffOrThrow(id, role, storeId);
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
    const [pkg] = await this.db.select({ name: labPackage.name }).from(labPackage).where(eq(labPackage.id, found.labPackageId)).limit(1);
    const amount = Math.max(Number(found.totalPrice) - dto.discountAmount, 0);

    return this.db.transaction(async (tx) => {
      const [existing] = await tx.select({ id: labBill.id }).from(labBill).where(eq(labBill.labBookingId, bookingId)).limit(1);
      let billId: number;
      if (existing) {
        await tx
          .update(labBill)
          .set({
            image: dto.image,
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
            image: dto.image,
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
    params: { bookingId: number; storeId: number | null; cash: number; wallet: number },
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

      const lines: { accountId: number; debit: string; credit: string }[] = [];
      if (params.cash > 0) lines.push({ accountId: byRole.cash_in, debit: params.cash.toFixed(2), credit: '0' });
      if (params.wallet > 0) lines.push({ accountId: byRole.wallet_in, debit: params.wallet.toFixed(2), credit: '0' });
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
          sourceId: String(params.bookingId),
          event: 'lab_bill_collected',
          description: `Lab booking LB-${params.bookingId.toString().padStart(4, '0')} collected`,
        })
        .returning();
      if (!entry) return;

      await tx.insert(journalLine).values(lines.map((l) => ({ entryId: entry.id, accountId: l.accountId, debit: l.debit, credit: l.credit })));
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
  private async availableWalletCapForMember(tx: Database, walletId: number, balance: number): Promise<number> {
    const cards = await tx
      .select({ amount: walletCard.amount, bonus: walletCard.bonus, rechargedExtra: walletCard.rechargedExtra, issuedOn: walletCard.issuedOn })
      .from(walletCard)
      .where(and(eq(walletCard.walletId, walletId), eq(walletCard.status, 'APPROVED')));
    if (cards.length === 0) {
      return balance;
    }
    const entries = await tx
      .select({ kind: walletEntry.kind, amount: walletEntry.amount, occurredOn: walletEntry.occurredOn, createdAt: walletEntry.createdAt })
      .from(walletEntry)
      .where(eq(walletEntry.walletId, walletId))
      .orderBy(walletEntry.createdAt, walletEntry.id);
    return availablePlanAllowance(
      cards.map((c) => ({ loaded: Number(c.amount) + Number(c.bonus) + Number(c.rechargedExtra), issuedOn: toIsoDate(c.issuedOn) })),
      entries.map((e) => ({ kind: e.kind, amount: Number(e.amount), occurredOn: toIsoDate(e.occurredOn) })),
      new Date(),
      balance,
    );
  }

  async collectLabBillWithWallet(role: AdminRole, storeId: number | null, bookingId: number) {
    const found = await this.getLabBookingOwnedByStaffOrThrow(bookingId, role, storeId);

    const [theBill] = await this.db.select().from(labBill).where(eq(labBill.labBookingId, bookingId)).limit(1);
    if (!theBill) {
      return { ok: false as const, reason: 'No bill has been sent for this booking yet.' };
    }
    if (theBill.status === 'PAID') {
      return { ok: false as const, reason: 'This bill is already paid.' };
    }
    const billAmount = Number(theBill.amount);
    if (billAmount <= 0) {
      return { ok: false as const, reason: 'This bill has not been priced yet.' };
    }

    return this.db.transaction(async (tx) => {
      const [theWallet] = await tx.select().from(wallet).where(eq(wallet.memberId, found.memberId)).limit(1);
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

      await tx
        .update(labBill)
        .set({
          status: 'PAID',
          paidAt: new Date(),
          walletCollected: walletAmount.toString(),
          cashCollected: cashAmount.toString(),
          updatedAt: new Date(),
        })
        .where(eq(labBill.id, theBill.id));

      await this.postLabBillCollection(tx, {
        bookingId: found.id,
        storeId: found.storeId,
        cash: cashAmount,
        wallet: walletAmount,
      });

      return { ok: true as const, walletAmount, cashAmount };
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
