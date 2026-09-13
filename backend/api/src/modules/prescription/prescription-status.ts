import { ConflictException } from '@nestjs/common';

export type PrescriptionStatus = 'AWAITING_REVIEW' | 'READ' | 'IN_CART' | 'ORDERED';

const ALLOWED_TRANSITIONS: Record<PrescriptionStatus, PrescriptionStatus[]> = {
  AWAITING_REVIEW: ['READ'],
  READ: ['IN_CART'],
  IN_CART: ['ORDERED'],
  ORDERED: [],
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
