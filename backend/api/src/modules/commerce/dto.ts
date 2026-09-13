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
  reference: z.string().optional(),
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

export type AddCartLineDto = z.infer<typeof addCartLineSchema>;
export type UpdateCartLineDto = z.infer<typeof updateCartLineSchema>;
export type CheckoutDto = z.infer<typeof checkoutSchema>;
export type UpdateOrderStatusDto = z.infer<typeof updateOrderStatusSchema>;
export type SendBillDto = z.infer<typeof sendBillSchema>;
