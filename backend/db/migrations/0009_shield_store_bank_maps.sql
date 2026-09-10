-- ============================================================================
--  0009 · Bank account + Google Maps link on app.shield_store
-- ============================================================================
--  The admin console (shieldweb/) "Add branch" and "Edit details" forms now
--  capture a branch's settlement bank account and a pasted Google Maps share
--  link for the shopfront:
--
--    maps_url             — a Google Maps link; the console shows an
--                           "Open in Maps" action when it is set, blank otherwise
--    bank_account_name    — account holder name
--    bank_account_number  — 9–18 digits (validated in the form, stored as text
--                           to keep leading zeros)
--    bank_ifsc            — 11-char IFSC, upper-cased in the form
--    bank_name            — e.g. "State Bank of India"
--
--  All five are optional. The console enforces "all four bank fields together
--  or none". Existing joins on app.shield_store are unaffected.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0009_shield_store_bank_maps.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.shield_store
  ADD COLUMN IF NOT EXISTS maps_url            text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_name   text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_number text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_ifsc           text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_name           text NOT NULL DEFAULT '';
