import { bigint, boolean, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';

/**
 * Mirrors app.admin_user. The drift called out in docs/erd.md §5 (repo
 * root) — shieldweb's console has always had an "admin" role with no DB
 * counterpart — is resolved as of migration
 * backend/db/migrations/0027_admin_role_add_admin.sql: ADMIN is now a real
 * app.admin_role value, not a client-only concept. That migration must be
 * applied to the live database before this matches reality there.
 *
 * DELIVERY added by migration 0031_wallet_cash_delivery.sql — a delivery
 * boy's own login, store-scoped the same way PHARMACY is.
 */
export const adminRoleEnum = appSchema.enum('admin_role', [
  'SUPERADMIN',
  'ADMIN',
  'PHARMACY',
  'LAB',
  'APPOINTMENTS',
  'DELIVERY',
]);

export const adminUser = appSchema.table('admin_user', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  // No longer used for staff login (see migration 0028) — kept only in case
  // a future integration wants it; staff auth is now loginId+password,
  // checked directly against passwordHash, with no Firebase dependency.
  firebaseUid: text('firebase_uid'),
  // A short handle ('pharmacy_mel'), not an email — migration 0029 renamed
  // this from `email` once login stopped requiring email format.
  loginId: text('login_id').notNull(),
  name: text('name').notNull(),
  // bcrypt hash (see auth.service.ts loginStaff). Nullable only so a row
  // can exist before a password is set; login is refused with no hash.
  passwordHash: text('password_hash'),
  role: adminRoleEnum('role').notNull().default('PHARMACY'),
  storeId: bigint('store_id', { mode: 'number' }),
  avatarColor: text('avatar_color').notNull().default('#2c57a6'),
  isActive: boolean('is_active').notNull().default(true),
  lastLoginAt: timestamp('last_login_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
