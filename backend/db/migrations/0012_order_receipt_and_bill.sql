-- ============================================================================
--  0012 · Receipt photo on app.order_receipt, admin-sent bill on app."order"
-- ============================================================================
--  Two related gaps, closed together:
--
--  1. A member's uploaded payment receipt (product-order checkout) was never
--     stored as a picture — only its file name and size. The admin console's
--     Orders section had nothing to show for "the user added transaction
--     photo". `image` closes that, the same `data:` JPEG convention already
--     used by app.prescription.image and app.wallet_card.receipt_image.
--
--  2. There was no way for the store to hand a member their own bill/invoice
--     back through the app. `bill_image` + `billed_at` give the admin console
--     somewhere to attach one, and the customer app somewhere to read it from.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0012_order_receipt_and_bill.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.order_receipt
  ADD COLUMN IF NOT EXISTS image text;

ALTER TABLE app."order"
  ADD COLUMN IF NOT EXISTS bill_image text,
  ADD COLUMN IF NOT EXISTS billed_at  timestamptz;
