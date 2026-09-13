-- ============================================================================
--  0028 · app.admin_user gets a password hash — staff auth stops needing Firebase
-- ============================================================================
--  Staff login moves from "verify a Firebase Email/Password token" to a
--  server-checked email + password, stored as a bcrypt hash right on this
--  row. Reasoning: with many branch-scoped admin accounts, requiring a
--  separate Firebase Authentication account (console setup, service-account
--  key for verification) per staff login was pure friction for no security
--  benefit over hashing it here — member login (Firebase phone OTP) is
--  completely unaffected by this and keeps using Firebase exactly as before.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0028_admin_user_password_hash.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.admin_user ADD COLUMN IF NOT EXISTS password_hash text;
