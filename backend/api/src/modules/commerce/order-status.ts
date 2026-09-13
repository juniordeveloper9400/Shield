import { ConflictException } from '@nestjs/common';

export type OrderStatus = 'PROCESSING' | 'OUT_FOR_DELIVERY' | 'DELIVERED' | 'CANCELLED';

const ALLOWED_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  PROCESSING: ['OUT_FOR_DELIVERY', 'CANCELLED'],
  OUT_FOR_DELIVERY: ['DELIVERED', 'CANCELLED'],
  DELIVERED: [],
  CANCELLED: [],
};

/**
 * Centralizes the order lifecycle — see backend/docs/frd.md §3. Before
 * this, "no skipping PROCESSING straight to DELIVERED, no reopening a
 * CANCELLED order" was informal convention; this is the one place it's
 * actually enforced, for every caller.
 */
export function assertLegalTransition(from: OrderStatus, to: OrderStatus): void {
  if (from === to) return; // idempotent no-op, not a transition
  if (!ALLOWED_TRANSITIONS[from].includes(to)) {
    throw new ConflictException({
      error: { code: 'CONFLICT', message: `Cannot move an order from ${from} to ${to}` },
    });
  }
}
