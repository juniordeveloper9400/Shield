-- ============================================================================
--  0087 · A staff-typed bill number on each priced bill
-- ============================================================================
--  `app.bill` had no field for the counter's own receipt-book number — the
--  number printed on whatever physical bill book or POS slip the pharmacy
--  hands the member alongside the app's own invoice. Admin → Bills needed a
--  text field for it.
--
--  Free text, not a generated sequence: a branch's own numbering (its
--  receipt book, or a separate POS) is outside this system, so the field
--  just records whatever staff type in, blank until the first bill the
--  counter actually adds one to.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0087_bill_number.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.bill
    ADD COLUMN IF NOT EXISTS bill_number text;
