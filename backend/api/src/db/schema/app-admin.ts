import { bigint, boolean, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';

/**
 * Mirrors app.admin_user. The drift called out in docs/erd.md §5 (repo
 * root) — shieldweb's console has always had an "admin" role with no DB
 * counterpart — is resolved as of migration
 * backend/db/migrations/0027_admin_role_add_admin.sql: ADMIN is now a real
 * app.admin_role value, not a client-only concept. That migration must be
 * applied to the live database before this matches reality there.
 */
export const adminRoleEnum = appSchema.enum('admin_role', ['SUPERADMIN', 'ADMIN', 'PHARMACY', 'LAB', 'APPOINTMENTS']);

export const adminUser = appSchema.table('admin_user', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  firebaseUid: text('firebase_uid'),
  email: text('email').notNull(),
  name: text('name').notNull(),
  role: adminRoleEnum('role').notNull().default('PHARMACY'),
  storeId: bigint('store_id', { mode: 'number' }),
  isActive: boolean('is_active').notNull().default(true),
  lastLoginAt: timestamp('last_login_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
