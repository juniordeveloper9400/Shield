-- ============================================================================
--  0044 · Order review (per-line stock status) and explicit "convert to bill"
-- ============================================================================
--  Until now every order landed in the console's Bills page the moment the
--  member placed it. Orders are now reviewed first, like a prescription:
--
--   1. Each order line gets a counter-only stock status -- Stock available /
--      Out of stock / Not possible / Customer not needed -- set from the
--      Orders review modal. Never read or shown by the member's own app.
--   2. "Submit" on the modal's Details step stamps app."order".reviewed_at.
--   3. "Convert to bill" stamps app."order".converted_to_bill_at. Only orders
--      with that stamp are listed on the Bills page; the OTP-gated payment
--      collection still happens there, unchanged.
--
--  Backfill: an order that already has a bill row was, by definition, already
--  being billed, so it is stamped with that bill's sent_at and keeps showing
--  on the Bills page. Orders with no bill row yet start unconverted.
--
--  Purely additive and idempotent -- new enum only if missing, new columns
--  only if missing, backfill only touches rows still unstamped -- so a re-run
--  is harmless and never overwrites a stamp already set.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0044_order_review_and_bill_conversion.sql --yes
-- ============================================================================

SET search_path TO app, public;

DO $$ BEGIN
    CREATE TYPE app.order_line_status AS ENUM
        ('AVAILABLE', 'OUT_OF_STOCK', 'NOT_POSSIBLE', 'CUSTOMER_NOT_NEEDED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE app.order_line
  ADD COLUMN IF NOT EXISTS stock_status app.order_line_status
    NOT NULL DEFAULT 'AVAILABLE';

ALTER TABLE app."order"
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS converted_to_bill_at timestamptz;

UPDATE app."order" o
   SET reviewed_at          = COALESCE(o.reviewed_at, b.sent_at),
       converted_to_bill_at = b.sent_at
  FROM app.bill b
 WHERE b.order_id = o.id
   AND o.converted_to_bill_at IS NULL;

COMMENT ON COLUMN app.order_line.stock_status IS
  'Counter-only stock status for this line, set from the console''s Orders '
  'review modal -- never shown in the member''s own app.';
COMMENT ON COLUMN app."order".reviewed_at IS
  'When the counter submitted this order''s review (Details step).';
COMMENT ON COLUMN app."order".converted_to_bill_at IS
  'When the order was converted to a bill; the console''s Bills page lists '
  'only orders where this is set.';
