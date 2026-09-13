import { ConflictException, Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { and, eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { idempotencyKey } from '../../db/schema';

/**
 * See db/schema/backend-idempotency.ts for why this is reserve-then-complete
 * rather than check-then-insert.
 */
@Injectable()
export class IdempotencyService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  async run<T>(sessionId: string, endpoint: string, key: string, fn: () => Promise<T>): Promise<T> {
    let reservationId: string | undefined;

    try {
      // Explicit id (not the column's DB-side DEFAULT gen_random_uuid()) —
      // this insert shape runs identically on every call by design, which
      // trips a pg-mem test-only limitation identical to the one already
      // worked around in auth.service.ts. See that file's comment; the
      // same fix applies here for the same reason.
      const [reserved] = await this.db
        .insert(idempotencyKey)
        .values({ id: randomUUID(), key, sessionId, endpoint })
        .returning();
      reservationId = reserved.id;
    } catch {
      // unique(key, endpoint) already exists — someone else holds this key.
    }

    if (!reservationId) {
      const [existing] = await this.db
        .select()
        .from(idempotencyKey)
        .where(and(eq(idempotencyKey.key, key), eq(idempotencyKey.endpoint, endpoint)))
        .limit(1);

      if (existing?.responseSnapshot != null) return existing.responseSnapshot as T;

      throw new ConflictException({
        error: { code: 'CONFLICT', message: 'A request with this Idempotency-Key is already in progress or was not completed — retry with a new key if this persists' },
      });
    }

    const result = await fn();
    await this.db
      .update(idempotencyKey)
      .set({ responseSnapshot: result as object })
      .where(eq(idempotencyKey.id, reservationId));
    return result;
  }
}
