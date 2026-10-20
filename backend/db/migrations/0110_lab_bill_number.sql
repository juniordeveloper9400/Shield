-- ============================================================================
--  0110 · A staff-typed bill number on each lab bill
-- ============================================================================
--  Same idea as 0087 (app.bill.bill_number): the counter's own receipt-book /
--  POS number for the paper bill handed to the member. Lab Bills now asks for
--  it, together with a photo of the bill, before a payment can be collected.
--
--  Also adds gpay_collected: Lab Bills now settles a bill the way a standard
--  order's bill is settled — the wallet is debited under an OTP, then whatever
--  is left is received at the counter as GPay and/or cash (migration 0071's
--  idea, applied to app.lab_bill).
--
--  Free text, blank until staff type one in. Idempotent — safe to run more
--  than once. Apply this BEFORE deploying the backend that reads it:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0110_lab_bill_number.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.lab_bill
    ADD COLUMN IF NOT EXISTS bill_number text;

ALTER TABLE app.lab_bill
    ADD COLUMN IF NOT EXISTS gpay_collected numeric(12,2) NOT NULL DEFAULT 0;
