import { pgEnum, pgSchema, text, timestamp, uuid } from 'drizzle-orm/pg-core';

/**
 * Tables this service owns for its own session/audit concerns — kept in a
 * separate `backend` Postgres schema, deliberately apart from `app`. See
 * backend/docs/erd.md §3 for the rationale.
 */
export const backendSchema = pgSchema('backend');

export const subjectTypeEnum = pgEnum('backend_subject_type', ['MEMBER', 'STAFF']);

export const authSession = backendSchema.table('auth_session', {
  id: uuid('id').primaryKey().defaultRandom(),
  subjectType: subjectTypeEnum('subject_type').notNull(),
  subjectId: text('subject_id').notNull(), // app.users.id or app.admin_user.id, stored as text (bigint-safe)
  issuedAt: timestamp('issued_at', { withTimezone: true }).notNull().defaultNow(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  revokedAt: timestamp('revoked_at', { withTimezone: true }),
  userAgent: text('user_agent'),
  ip: text('ip'),
});

export const refreshToken = backendSchema.table('refresh_token', {
  id: uuid('id').primaryKey().defaultRandom(),
  sessionId: uuid('session_id')
    .notNull()
    .references(() => authSession.id, { onDelete: 'cascade' }),
  tokenHash: text('token_hash').notNull(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  usedAt: timestamp('used_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});
