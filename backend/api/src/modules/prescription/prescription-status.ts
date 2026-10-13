import { ConflictException } from '@nestjs/common';

export type PrescriptionStatus = 'AWAITING_REVIEW' | 'READ' | 'IN_CART' | 'ORDERED';

// "Back to awaiting" (shieldweb's PrescriptionReviewModal — a reviewer's own
// undo, offered from any non-awaiting status including ORDERED) is a real,
// relied-on admin action, not an oversight — each forward status keeps that
// one reverse path alongside its normal forward one.
const ALLOWED_TRANSITIONS: Record<PrescriptionStatus, PrescriptionStatus[]> = {
  AWAITING_REVIEW: ['READ'],
  READ: ['IN_CART', 'AWAITING_REVIEW'],
  IN_CART: ['ORDERED', 'AWAITING_REVIEW'],
  ORDERED: ['AWAITING_REVIEW'],
};

/** Same enforcement pattern as commerce/order-status.ts, applied to the prescription lifecycle. */
export function assertLegalPrescriptionTransition(from: PrescriptionStatus, to: PrescriptionStatus): void {
  if (from === to) return;
  if (!ALLOWED_TRANSITIONS[from].includes(to)) {
    throw new ConflictException({
      error: { code: 'CONFLICT', message: `Cannot move a prescription from ${from} to ${to}` },
    });
  }
}
