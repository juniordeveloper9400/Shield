import { z } from 'zod';

export const addCartLineSchema = z.object({
  productId: z.number().int().positive(),
  qty: z.number().int().min(1).max(999).default(1),
});

export const updateCartLineSchema = z.object({
  qty: z.number().int().min(1).max(999),
});

export const checkoutSchema = z.object({
  deliveryAddressId: z.number().int().positive().optional(),
  paymentMethodId: z.number().int().positive().optional(),
  // migration 0031: how the order reaches the member. Defaults to
  // HOME_DELIVERY server-side (the column's own default) when omitted.
  fulfillmentType: z.enum(['HOME_DELIVERY', 'STORE_PICKUP']).optional(),
  reference: z.string().optional(),
  // The wallet's share of the order when the client has already worked out
  // (from the member's monthly allowance) that it should not cover the
  // whole total. Only read when the resolved payment method's code is
  // 'wallet' — see order.service.ts's checkout(). Omitted debits the full
  // total, the pre-existing behaviour.
  walletAmount: z.number().nonnegative().optional(),
});

/** Fulfilment status set from the admin console (cancel, delivered, out for delivery). No legal-transition check: see OrderService.setFulfilmentStatus. */
export const setFulfilmentStatusSchema = z.object({
  status: z.enum(['PROCESSING', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED']),
});

export const updateOrderStatusSchema = z.object({
  status: z.enum(['PROCESSING', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED']),
  detail: z.string().optional(),
});

// Matches the existing app.bill.image convention (a data: URI) — see
// backend/db/app_schema.sql. Moving this to object storage + a URL column
// is a schema change out of scope for this module; see backend/docs/security.md.
//
// `amount`/`discountAmount`/`lines` mirror shieldweb's own richer
// sendOrderInvoice (src/api/orders.ts) — a priced, line-itemised bill with a
// real discount, the figure MemberEarnings/Purchase.billDiscount counts as
// saved, never the checkout-time mrpTotal/paidTotal gap (see order.service.ts's
// own listForMember doc). `image` alone still works for the old
// photo-only flow this schema originally covered. Optional, not required,
// so a caller that only has a picture (no itemised pricing yet) still works.
export const sendBillSchema = z.object({
  image: z.string().default(''),
  amount: z.number().nonnegative().optional(),
  discountAmount: z.number().nonnegative().default(0),
  // The counter's own receipt-book / POS number — free text, optional. Same
  // "blank keeps whatever is already on record" rule as `image` below, so a
  // line-items-only re-price never blanks out a number typed in earlier.
  billNumber: z.string().default(''),
  lines: z
    .array(
      z.object({
        name: z.string().min(1),
        pack: z.string().optional(),
        unitPrice: z.number().nonnegative(),
        qty: z.number().int().positive().default(1),
      }),
    )
    .optional(),
});

// A manual-transfer claim, not a payment confirmation — no image bytes: the
// live app has never uploaded the receipt photo itself anywhere, only this
// metadata (see order_repository.dart's OrderReceiptInput on the client this
// mirrors). Staff settle the claim against `reference` by hand.
/** Money the counter takes against a priced bill, as it arrives — GPay and
 *  cash, either or both. Each is a rupee amount; at least one must be above 0. */
export const receiveBillPaymentSchema = z
  .object({
    cash: z.number().nonnegative().max(10000000).default(0),
    gpay: z.number().nonnegative().max(10000000).default(0),
  })
  .refine((v) => v.cash + v.gpay > 0, { message: 'Enter an amount to receive.' });

export const submitOrderReceiptSchema = z.object({
  payerName: z.string().optional(),
  reference: z.string().optional(),
  amount: z.number().nonnegative().optional(),
  fileName: z.string().optional(),
});

export type AddCartLineDto = z.infer<typeof addCartLineSchema>;
export type UpdateCartLineDto = z.infer<typeof updateCartLineSchema>;
export type CheckoutDto = z.infer<typeof checkoutSchema>;
export type UpdateOrderStatusDto = z.infer<typeof updateOrderStatusSchema>;
export type SendBillDto = z.infer<typeof sendBillSchema>;
export type ReceiveBillPaymentDto = z.infer<typeof receiveBillPaymentSchema>;
export type SubmitOrderReceiptDto = z.infer<typeof submitOrderReceiptSchema>;

// ---- Staff order writes (migrated from shieldweb's direct-SQL orders.ts) ----

/** The counter's stock call on one line — the same four values as app.order_line_status. */
export const orderLineStatusInput = z.enum(['AVAILABLE', 'OUT_OF_STOCK', 'NOT_POSSIBLE', 'CUSTOMER_NOT_NEEDED']);

/** "Save"/"Convert to bill" on the review page. `lines` are the existing checkout lines (status only);
 *  `newLines` are rows the counter added by hand; `storeId` moves the order to a branch. */
export const reviewOrderSchema = z.object({
  lines: z.array(z.object({ id: z.number().int().positive(), status: orderLineStatusInput })).default([]),
  newLines: z
    .array(
      z.object({
        name: z.string().trim().min(1).max(200),
        pack: z.string().max(200).default(''),
        unitPrice: z.number().nonnegative().max(10000000),
        qty: z.number().int().min(1).max(9999).default(1),
        status: orderLineStatusInput.default('AVAILABLE'),
      }),
    )
    .default([]),
  storeId: z.number().int().positive().nullable().default(null),
});

/** A priced, line-itemised invoice (see sendOrderInvoice in shieldweb's orders.ts). */
export const sendInvoiceSchema = z.object({
  image: z.string().default(''),
  amount: z.number().nonnegative().max(10000000),
  discountAmount: z.number().nonnegative().max(10000000).default(0),
  // The counter's own receipt-book / POS number — free text, optional. Blank
  // keeps whatever is already on record, same rule `image` already follows,
  // so a line-items-only re-price never blanks out a number typed in earlier.
  billNumber: z.string().max(100).default(''),
  lines: z
    .array(
      z.object({
        name: z.string().trim().min(1).max(200),
        pack: z.string().max(200).optional(),
        unitPrice: z.number().nonnegative().max(10000000),
        qty: z.number().int().min(1).max(9999).default(1),
      }),
    )
    .optional(),
});

/** A picture-only bill (shieldweb's sendOrderBill): leaves the bill's amount and discount alone. */
export const sendPictureSchema = z.object({
  image: z.string().min(1),
});

export type ReviewOrderDto = z.infer<typeof reviewOrderSchema>;
export type SendInvoiceDto = z.infer<typeof sendInvoiceSchema>;
export type SendPictureDto = z.infer<typeof sendPictureSchema>;
export type SetFulfilmentStatusDto = z.infer<typeof setFulfilmentStatusSchema>;
