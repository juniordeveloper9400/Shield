import { jsonb, text, timestamp, unique, uuid } from 'drizzle-orm/pg-core';
import { authSession, backendSchema } from './backend-auth';

/**
 * Dedupes retried mutating requests (checkout, wallet redeem, agent
 * withdrawal/transfer — anything irreversible) — see backend/docs/erd.md §3
 * and backend/docs/api-spec.md "Idempotency".
 *
 * Uses a RESERVE-then-COMPLETE pattern, not check-then-insert: two
 * concurrent requests with the same key both race to INSERT a row with
 * `response_snapshot = NULL` first. The `unique(key, endpoint)` constraint
 * lets exactly one of them win; the loser sees the constraint violation
 * immediately and is told to retry, rather than both racing past a SELECT
 * and both executing the underlying side effect. See
 * common/idempotency/idempotency.service.ts.
 */
export const idempotencyKey = backendSchema.table(
  'idempotency_key',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    key: text('key').notNull(),
    sessionId: uuid('session_id')
      .notNull()
      .references(() => authSession.id, { onDelete: 'cascade' }),
    endpoint: text('endpoint').notNull(),
    responseSnapshot: jsonb('response_snapshot'), // null while the request is still in flight
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    keyEndpointUnique: unique('idempotency_key_key_endpoint_unique').on(table.key, table.endpoint),
  }),
);
