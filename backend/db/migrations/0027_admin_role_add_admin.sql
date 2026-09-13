-- ============================================================================
--  0027 · app.admin_role gets ADMIN
-- ============================================================================
--  shieldweb's console role model (shieldweb/src/config/permissions.ts) has
--  always had a fifth login role — 'admin', one level under Super Admin:
--  every operational module except the Admins page itself (which manages who
--  can sign in). Until now that role had no database counterpart at all,
--  because staff auth was a static credential list (shieldweb/src/config/
--  admins.ts), never backed by app.admin_user.role. backend/docs/erd.md §5
--  already flagged this drift.
--
--  Backend service M9 (client cutover) makes app.admin_user.role the real
--  authorization boundary for the first time, so the enum has to actually
--  carry every role the console has ever offered.
--
--  Idempotent — ADD VALUE IF NOT EXISTS, safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0027_admin_role_add_admin.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TYPE app.admin_role ADD VALUE IF NOT EXISTS 'ADMIN';
