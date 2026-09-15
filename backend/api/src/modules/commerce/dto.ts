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

export const updateOrderStatusSchema = z.object({
  status: z.enum(['PROCESSING', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED']),
  detail: z.string().optional(),
});

// Matches the existing app.bill.image convention (a data: URI) — see
// backend/db/app_schema.sql. Moving this to object storage + a URL column
// is a schema change out of scope for this module; see backend/docs/security.md.
export const sendBillSchema = z.object({
  image: z.string().min(1),
});

// A manual-transfer claim, not a payment confirmation — no image bytes: the
// live app has never uploaded the receipt photo itself anywhere, only this
// metadata (see order_repository.dart's OrderReceiptInput on the client this
// mirrors). Staff settle the claim against `reference` by hand.
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
export type SubmitOrderReceiptDto = z.infer<typeof submitOrderReceiptSchema>;
