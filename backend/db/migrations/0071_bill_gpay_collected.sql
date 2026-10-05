-- ============================================================================
--  0071 · Record GPay and cash received against a priced bill
-- ============================================================================
--  `app.bill` already splits a paid bill into `wallet_collected` (what the
--  member's wallet covered) and `cash_collected` (what the counter took).
--  The Bills → Manual cash "Receive" panel lets staff record money as it
--  arrives — cash, GPay, or both — and needs GPay kept apart from cash so
--  the counter's own record stays accurate. This adds that column.
--
--  Outstanding on a bill = amount − wallet_collected − cash_collected −
--  gpay_collected. Once it reaches zero the bill is marked PAID.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0071_bill_gpay_collected.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.bill
    ADD COLUMN IF NOT EXISTS gpay_collected numeric(12,2) NOT NULL DEFAULT 0;
