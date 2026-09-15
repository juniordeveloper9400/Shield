import { bigint, boolean, date, integer, numeric, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';

/**
 * Typed READ/WRITE MIRROR of commerce tables owned by
 * backend/db/app_schema.sql — see backend/docs/erd.md §2. `cart_line.
 * prescription_id` and `order.billed_wallet_card_id` are left as plain
 * bigint (no FK) here — their referenced tables (prescription, wallet_card)
 * aren't mirrored yet; M4/M5 add them.
 */
export const cartLineSourceEnum = appSchema.enum('cart_line_source', ['SHOP', 'PRESCRIPTION']);
export const orderKindEnum = appSchema.enum('order_kind', ['STANDARD', 'PRESCRIPTION']);
export const orderStatusEnum = appSchema.enum('order_status', [
  'PROCESSING',
  'OUT_FOR_DELIVERY',
  'DELIVERED',
  'CANCELLED',
]);
export const trackStateEnum = appSchema.enum('track_state', ['DONE', 'CURRENT', 'UPCOMING']);

/** migration 0031: how the order reaches the member, and whether it's paid. */
export const fulfillmentTypeEnum = appSchema.enum('fulfillment_type', ['HOME_DELIVERY', 'STORE_PICKUP']);
export const orderPaymentStatusEnum = appSchema.enum('order_payment_status', ['PENDING', 'PAID']);

/**
 * Checkout payment methods (`'upi'` / `'wallet'` / `'cod'`) — previously
 * unmirrored entirely; `order.paymentMethodId` had nothing to validate
 * against.
 */
export const paymentMethod = appSchema.table('payment_method', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  code: text('code').notNull(),
  name: text('name').notNull(),
  blurb: text('blurb').notNull().default(''),
  isLive: boolean('is_live').notNull().default(false),
  sort: integer('sort').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const cart = appSchema.table('cart', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  memberId: bigint('member_id', { mode: 'number' }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const cartLine = appSchema.table('cart_line', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  cartId: bigint('cart_id', { mode: 'number' }).notNull(),
  productId: bigint('product_id', { mode: 'number' }),
  name: text('name').notNull(),
  pack: text('pack').notNull().default(''),
  price: numeric('price', { precision: 12, scale: 2 }).notNull().default('0'),
  mrp: numeric('mrp', { precision: 12, scale: 2 }).notNull().default('0'),
  image: text('image'),
  qty: integer('qty').notNull().default(1),
  source: cartLineSourceEnum('source').notNull().default('SHOP'),
  prescriptionId: bigint('prescription_id', { mode: 'number' }),
  addedAt: timestamp('added_at', { withTimezone: true }).notNull().defaultNow(),
});

export const order = appSchema.table('order', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  memberId: bigint('member_id', { mode: 'number' }).notNull(),
  code: text('code').notNull(),
  kind: orderKindEnum('kind').notNull().default('STANDARD'),
  status: orderStatusEnum('status').notNull().default('PROCESSING'),
  itemCount: integer('item_count').notNull().default(0),
  mrpTotal: numeric('mrp_total', { precision: 12, scale: 2 }).notNull().default('0'),
  paidTotal: numeric('paid_total', { precision: 12, scale: 2 }).notNull().default('0'),
  deliveryFee: numeric('delivery_fee', { precision: 12, scale: 2 }).notNull().default('0'),
  deliveryAddressId: bigint('delivery_address_id', { mode: 'number' }),
  storeId: bigint('store_id', { mode: 'number' }),
  paymentMethodId: bigint('payment_method_id', { mode: 'number' }),
  billedWalletCardId: bigint('billed_wallet_card_id', { mode: 'number' }),
  reference: text('reference'),
  fulfillmentType: fulfillmentTypeEnum('fulfillment_type').notNull().default('HOME_DELIVERY'),
  paymentStatus: orderPaymentStatusEnum('payment_status').notNull().default('PENDING'),
  deliveryBoyId: bigint('delivery_boy_id', { mode: 'number' }),
  paidAt: timestamp('paid_at', { withTimezone: true }),
  placedOn: date('placed_on').notNull(),
  placedAt: timestamp('placed_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const orderLine = appSchema.table('order_line', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  orderId: bigint('order_id', { mode: 'number' }).notNull(),
  productId: bigint('product_id', { mode: 'number' }),
  name: text('name').notNull(),
  pack: text('pack').notNull().default(''),
  unitPrice: numeric('unit_price', { precision: 12, scale: 2 }).notNull().default('0'),
  mrp: numeric('mrp', { precision: 12, scale: 2 }).notNull().default('0'),
  qty: integer('qty').notNull().default(1),
});

export const orderTrackStep = appSchema.table('order_track_step', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  orderId: bigint('order_id', { mode: 'number' }).notNull(),
  sort: integer('sort').notNull().default(0),
  title: text('title').notNull(),
  detail: text('detail'),
  state: trackStateEnum('state').notNull().default('UPCOMING'),
  occurredAt: timestamp('occurred_at', { withTimezone: true }),
});

export const orderReceipt = appSchema.table('order_receipt', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  orderId: bigint('order_id', { mode: 'number' }).notNull(),
  payerName: text('payer_name'),
  reference: text('reference'),
  amount: numeric('amount', { precision: 12, scale: 2 }),
  storagePath: text('storage_path'),
  fileName: text('file_name'),
  mimeType: text('mime_type'),
  uploadedAt: timestamp('uploaded_at', { withTimezone: true }).notNull().defaultNow(),
  verifiedAt: timestamp('verified_at', { withTimezone: true }),
});

export const bill = appSchema.table('bill', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  orderId: bigint('order_id', { mode: 'number' }).notNull(),
  image: text('image').notNull(),
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull().default('0'),
  status: orderPaymentStatusEnum('status').notNull().default('PENDING'),
  paidAt: timestamp('paid_at', { withTimezone: true }),
  sentAt: timestamp('sent_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const billLine = appSchema.table('bill_line', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  billId: bigint('bill_id', { mode: 'number' }).notNull(),
  name: text('name').notNull(),
  pack: text('pack').notNull().default(''),
  unitPrice: numeric('unit_price', { precision: 12, scale: 2 }).notNull().default('0'),
  qty: integer('qty').notNull().default(1),
});
