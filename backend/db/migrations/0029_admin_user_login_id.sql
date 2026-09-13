-- ============================================================================
--  0029 · app.admin_user.email becomes login_id — no email format required
-- ============================================================================
--  Staff sign in with a short login id (e.g. 'pharmacy_mel'), matching the
--  original console convention (shieldweb's old config/admins.ts), not a
--  real email address. A plain RENAME preserves the existing unique
--  constraint and every existing row's value — the one seeded account's
--  current value (an email-shaped string) still works fine as a login id,
--  nothing forces it to change.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0029_admin_user_login_id.sql --yes
-- ============================================================================

SET search_path TO app, public;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'admin_user' AND column_name = 'email'
  ) THEN
    ALTER TABLE app.admin_user RENAME COLUMN email TO login_id;
  END IF;
END $$;
