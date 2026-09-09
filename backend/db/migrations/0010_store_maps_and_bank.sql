-- ============================================================================
--  0010 · Maps link and bank details on app.shield_store
-- ============================================================================
--  The admin console's Stores page reads and writes a Google Maps link (for
--  "Get directions" on a branch) and the branch's own bank account — where a
--  member's plan-activation bank transfer actually lands — alongside its
--  existing coordinates. Without this migration the console's Stores page
--  fails outright: "column s.maps_url does not exist".
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0010_store_maps_and_bank.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.shield_store
  ADD COLUMN IF NOT EXISTS maps_url            text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_name    text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_number  text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_ifsc            text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_name            text NOT NULL DEFAULT '';
