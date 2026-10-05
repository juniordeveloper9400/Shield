import { Inject, Injectable } from '@nestjs/common';
import { and, asc, desc, eq, inArray, ne, sql, type SQL } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import {
  adminUser,
  bill,
  billLine,
  order,
  orderLine,
  orderReceipt,
  paymentMethod,
  prescriptionMedicine,
  prescriptionOrder,
  product,
  productCategory,
  shieldStore,
  users,
} from '../../db/schema';
import type { AdminRole } from '../auth/session.types';

/**
 * The order board the admin console reads: one card per order, carrying its
 * lines, bill, receipt and the billable-items check. This is the server-side
 * form of what shieldweb's src/api/orders.ts used to build from raw SQL in the
 * browser; the field names and value formats match the console's `Order` type
 * exactly, so the screens render the same.
 *
 * Branch scope follows the console's own rule: an order belongs to the branch
 * it was booked at, or — when none was set — to the member's home branch.
 * SUPERADMIN and ADMIN see every branch; every other role sees its own only.
 */

const NO_BRANCH_NAME = '—';

/** The lowercase string form the console's enum types use ('OUT_FOR_DELIVERY' → 'out_for_delivery'). */
const lower = (value: string | null | undefined, fallback: string) => (value ?? fallback).toLowerCase();

const iso = (value: Date | null | undefined): string => (value ? value.toISOString() : '');

const numberOf = (value: string | number | null | undefined): number => {
  if (typeof value === 'number') return value;
  if (typeof value === 'string' && value.trim() !== '') return Number(value);
  return 0;
};

export interface StaffOrderCard {
  id: string;
  code: string;
  memberId: string;
  memberName: string;
  memberPhone: string;
  kind: 'standard' | 'prescription';
  status: 'processing' | 'out_for_delivery' | 'delivered' | 'cancelled';
  itemCount: number;
  mrpTotal: number;
  paidTotal: number;
  deliveryFee: number;
  storeId: string;
  storeCode: string;
  storeName: string;
  reviewedAt: string;
  convertedToBillAt: string;
  storeContactedAt: string;
  paymentMethod: string;
  paymentMethodCode: string;
  fulfillmentType: 'home_delivery' | 'store_pickup';
  paymentStatus: 'pending' | 'paid';
  deliveryBoyId: string;
  deliveryBoyName: string;
  placedAt: string;
  lines: {
    id: string;
    status: 'available' | 'out_of_stock' | 'not_possible' | 'customer_not_needed';
    name: string;
    pack: string;
    unitPrice: number;
    mrp: number;
    qty: number;
    categoryTitle: string;
  }[];
  receipt: {
    payerName: string;
    reference: string;
    amount: number;
    fileName: string;
    image: string;
    uploadedAt: string;
  } | null;
  billImage: string;
  billedAt: string;
  billAmount: number;
  billDiscount: number;
  billId: string;
  billWalletCollected: number;
  billCashCollected: number;
  billGpayCollected: number;
  billStatus: 'pending' | 'paid';
  billLines: { name: string; pack: string; unitPrice: number; qty: number }[];
  billableItemNames: string[];
}

@Injectable()
export class StaffOrderBoardService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  /** Every order this role may see, newest first. */
  async listForStaff(role: AdminRole, storeId: number | null): Promise<StaffOrderCard[]> {
    if (!isAdmin(role) && storeId == null) return [];
    const scope = isAdmin(role) ? undefined : sql`COALESCE(${order.storeId}, ${users.homeStoreId}) = ${storeId}`;
    return this.build(scope);
  }

  /** One order by id, if this role may see it. */
  async getForStaff(role: AdminRole, storeId: number | null, orderId: number): Promise<StaffOrderCard | null> {
    if (!isAdmin(role) && storeId == null) return null;
    const scope = isAdmin(role)
      ? eq(order.id, orderId)
      : and(eq(order.id, orderId), sql`COALESCE(${order.storeId}, ${users.homeStoreId}) = ${storeId}`);
    const [card] = await this.build(scope);
    return card ?? null;
  }

  private async build(where: SQL | undefined): Promise<StaffOrderCard[]> {
    const orderRows = await this.db
      .select({
        id: order.id,
        code: order.code,
        memberId: order.memberId,
        memberName: users.name,
        memberPhone: users.phone,
        homeStoreId: users.homeStoreId,
        kind: order.kind,
        status: order.status,
        itemCount: order.itemCount,
        mrpTotal: order.mrpTotal,
        paidTotal: order.paidTotal,
        deliveryFee: order.deliveryFee,
        storeId: order.storeId,
        reviewedAt: order.reviewedAt,
        convertedToBillAt: order.convertedToBillAt,
        storeContactedAt: order.storeContactedAt,
        reference: order.reference,
        paymentMethodCode: paymentMethod.code,
        paymentMethodName: paymentMethod.name,
        fulfillmentType: order.fulfillmentType,
        paymentStatus: order.paymentStatus,
        deliveryBoyId: order.deliveryBoyId,
        deliveryBoyName: adminUser.name,
        placedAt: order.placedAt,
        billId: bill.id,
        billImage: bill.image,
        billedAt: bill.sentAt,
        billAmount: bill.amount,
        billDiscount: bill.discountAmount,
        billStatus: bill.status,
        billWalletCollected: bill.walletCollected,
        billCashCollected: bill.cashCollected,
        billGpayCollected: bill.gpayCollected,
      })
      .from(order)
      .leftJoin(users, eq(users.id, order.memberId))
      .leftJoin(bill, eq(bill.orderId, order.id))
      .leftJoin(adminUser, eq(adminUser.id, order.deliveryBoyId))
      .leftJoin(paymentMethod, eq(paymentMethod.id, order.paymentMethodId))
      .where(where)
      .orderBy(desc(order.placedAt));

    if (orderRows.length === 0) return [];

    const stores = await this.db.select({ id: shieldStore.id, code: shieldStore.code, name: shieldStore.name }).from(shieldStore);
    const storeById = new Map(stores.map((s) => [s.id, s]));

    const ids = orderRows.map((r) => r.id);

    const lineRows = await this.db
      .select({
        orderId: orderLine.orderId,
        id: orderLine.id,
        name: orderLine.name,
        pack: orderLine.pack,
        unitPrice: orderLine.unitPrice,
        mrp: orderLine.mrp,
        qty: orderLine.qty,
        stockStatus: orderLine.stockStatus,
        categoryTitle: productCategory.title,
      })
      .from(orderLine)
      .leftJoin(product, eq(product.id, orderLine.productId))
      .leftJoin(productCategory, eq(productCategory.id, product.categoryId))
      .where(inArray(orderLine.orderId, ids))
      .orderBy(asc(orderLine.id));

    const billIds = orderRows.flatMap((r) => (r.billId == null ? [] : [r.billId]));
    const billLineRows =
      billIds.length === 0
        ? []
        : await this.db
            .select({ billId: billLine.billId, name: billLine.name, pack: billLine.pack, unitPrice: billLine.unitPrice, qty: billLine.qty })
            .from(billLine)
            .where(inArray(billLine.billId, billIds))
            .orderBy(asc(billLine.id));

    const prescriptionRows = await this.db
      .select({ orderId: prescriptionOrder.orderId, name: prescriptionMedicine.name })
      .from(prescriptionOrder)
      .innerJoin(prescriptionMedicine, eq(prescriptionMedicine.prescriptionId, prescriptionOrder.prescriptionId))
      .where(and(inArray(prescriptionOrder.orderId, ids), ne(prescriptionMedicine.status, 'NOT_POSSIBLE')));

    const receiptRows = await this.db
      .select({
        orderId: orderReceipt.orderId,
        payerName: orderReceipt.payerName,
        reference: orderReceipt.reference,
        amount: orderReceipt.amount,
        fileName: orderReceipt.fileName,
        image: orderReceipt.image,
        uploadedAt: orderReceipt.uploadedAt,
      })
      .from(orderReceipt)
      .where(inArray(orderReceipt.orderId, ids))
      .orderBy(desc(orderReceipt.uploadedAt));

    const linesBy = groupBy(lineRows, (l) => l.orderId);
    const billLinesBy = groupBy(billLineRows, (l) => l.billId);
    const billableBy = groupBy(prescriptionRows, (p) => p.orderId ?? -1);
    const latestReceiptBy = new Map<number, (typeof receiptRows)[number]>();
    for (const receipt of receiptRows) {
      if (!latestReceiptBy.has(receipt.orderId)) latestReceiptBy.set(receipt.orderId, receipt);
    }

    return orderRows.map((r): StaffOrderCard => {
      const ownStore = r.storeId == null ? undefined : storeById.get(r.storeId);
      const homeStore = r.homeStoreId == null ? undefined : storeById.get(r.homeStoreId);
      const lines = (linesBy.get(r.id) ?? []).map((l) => ({
        id: String(l.id),
        status: lower(l.stockStatus, 'AVAILABLE') as StaffOrderCard['lines'][number]['status'],
        name: l.name,
        pack: l.pack ?? '',
        unitPrice: numberOf(l.unitPrice),
        mrp: numberOf(l.mrp),
        qty: numberOf(l.qty),
        categoryTitle: l.categoryTitle ?? '',
      }));
      const receiptRow = latestReceiptBy.get(r.id);
      const billLinesOut = r.billId == null
        ? []
        : (billLinesBy.get(r.billId) ?? []).map((b) => ({
            name: b.name,
            pack: b.pack ?? '',
            unitPrice: numberOf(b.unitPrice),
            qty: numberOf(b.qty),
          }));
      const billableItemNames =
        r.kind === 'PRESCRIPTION'
          ? (billableBy.get(r.id) ?? []).map((p) => p.name)
          : lines.filter((l) => l.status === 'available').map((l) => l.name);

      return {
        id: String(r.id),
        code: r.code,
        memberId: r.memberId == null ? '' : String(r.memberId),
        memberName: r.memberName ?? NO_BRANCH_NAME,
        memberPhone: r.memberPhone ?? '',
        kind: lower(r.kind, 'STANDARD') as StaffOrderCard['kind'],
        status: lower(r.status, 'PROCESSING') as StaffOrderCard['status'],
        itemCount: numberOf(r.itemCount),
        mrpTotal: numberOf(r.mrpTotal),
        paidTotal: numberOf(r.paidTotal),
        deliveryFee: numberOf(r.deliveryFee),
        storeId: r.storeId == null ? '' : String(r.storeId),
        storeCode: ownStore?.code ?? homeStore?.code ?? '',
        storeName: ownStore?.name ?? homeStore?.name ?? NO_BRANCH_NAME,
        reviewedAt: iso(r.reviewedAt),
        convertedToBillAt: iso(r.convertedToBillAt),
        storeContactedAt: iso(r.storeContactedAt),
        paymentMethod: r.paymentMethodName ?? r.reference ?? NO_BRANCH_NAME,
        paymentMethodCode: r.paymentMethodCode ?? '',
        fulfillmentType: lower(r.fulfillmentType, 'HOME_DELIVERY') as StaffOrderCard['fulfillmentType'],
        paymentStatus: lower(r.paymentStatus, 'PENDING') as StaffOrderCard['paymentStatus'],
        deliveryBoyId: r.deliveryBoyId == null ? '' : String(r.deliveryBoyId),
        deliveryBoyName: r.deliveryBoyName ?? '',
        placedAt: iso(r.placedAt) || new Date(0).toISOString(),
        lines,
        receipt: receiptRow?.uploadedAt
          ? {
              payerName: receiptRow.payerName ?? '',
              reference: receiptRow.reference ?? '',
              amount: numberOf(receiptRow.amount),
              fileName: receiptRow.fileName ?? '',
              image: receiptRow.image ?? '',
              uploadedAt: iso(receiptRow.uploadedAt),
            }
          : null,
        billImage: r.billImage ?? '',
        billedAt: iso(r.billedAt),
        billAmount: numberOf(r.billAmount),
        billDiscount: numberOf(r.billDiscount),
        billId: r.billId == null ? '' : String(r.billId),
        billWalletCollected: numberOf(r.billWalletCollected),
        billCashCollected: numberOf(r.billCashCollected),
        billGpayCollected: numberOf(r.billGpayCollected),
        billStatus: lower(r.billStatus, 'PENDING') as StaffOrderCard['billStatus'],
        billLines: billLinesOut,
        billableItemNames,
      };
    });
  }
}

function isAdmin(role: AdminRole): boolean {
  return role === 'SUPERADMIN' || role === 'ADMIN';
}

function groupBy<T, K extends number>(rows: T[], key: (row: T) => K): Map<K, T[]> {
  const out = new Map<K, T[]>();
  for (const row of rows) {
    const k = key(row);
    const bucket = out.get(k);
    if (bucket) bucket.push(row);
    else out.set(k, [row]);
  }
  return out;
}
