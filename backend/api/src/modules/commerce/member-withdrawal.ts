import { ConflictException } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import type { Database } from '../../db/client';
import { bill, order, orderTrackStep } from '../../db/schema';

type Tx = Parameters<Parameters<Database['transaction']>[0]>[0];

export const ORDER_LOCKED_MESSAGE =
  'The store has already started on this order, so it can no longer be cancelled or deleted from the app. Please contact the store.';

/**
 * A member may pull an order back (cancel it, or delete the prescription it
 * came from) only while the store has not touched it: still PROCESSING, no
 * review saved, no contact made, not converted to a bill, no bill sent, and
 * nothing paid. Anything past that is the store's to cancel from the admin
 * console.
 */
export function isUntouchedByStore(
  o: {
    status: string;
    paymentStatus: string;
    reviewedAt: Date | null;
    storeContactedAt: Date | null;
    convertedToBillAt: Date | null;
  },
  hasBill: boolean,
): boolean {
  return (
    o.status === 'PROCESSING' &&
    o.paymentStatus === 'PENDING' &&
    o.reviewedAt === null &&
    o.storeContactedAt === null &&
    o.convertedToBillAt === null &&
    !hasBill
  );
}

/**
 * Cancels [orderId] on the member's behalf inside [tx], under a row lock so a
 * store action landing at the same moment cannot be raced past. Resolves
 * 'already' for an order that is already cancelled (a retry is not an error)
 * and throws 409 ORDER_LOCKED once the store has touched it.
 */
export async function cancelOrderForMember(tx: Tx, orderId: number): Promise<'cancelled' | 'already'> {
  const [found] = await tx.select().from(order).where(eq(order.id, orderId)).limit(1).for('update');
  if (!found) return 'already';
  if (found.status === 'CANCELLED') return 'already';
  const [theBill] = await tx.select({ id: bill.id }).from(bill).where(eq(bill.orderId, orderId)).limit(1);
  if (!isUntouchedByStore(found, theBill !== undefined)) {
    throw new ConflictException({ error: { code: 'ORDER_LOCKED', message: ORDER_LOCKED_MESSAGE } });
  }
  await tx.update(order).set({ status: 'CANCELLED', updatedAt: new Date() }).where(eq(order.id, orderId));
  await tx.insert(orderTrackStep).values({
    orderId,
    sort: 999,
    title: 'CANCELLED',
    detail: 'Cancelled by the member',
    state: 'DONE',
    occurredAt: new Date(),
  });
  return 'cancelled';
}
