-- ============================================================================
--  0064 · Whole-bill discount amount
-- ============================================================================
--  `BillEditorModal`'s pricing step gets a single "Disc amount" field —
--  one number the admin types once, subtracted from the priced lines'
--  subtotal to get what the member actually owes. `app.bill.amount` keeps
--  meaning exactly what it always has (the payable total actually owed and
--  collected — what `collectBillWithWallet` reads), already net of this
--  discount; this column is purely the audit trail of how much of the
--  subtotal was knocked off, so the console can show "Subtotal — Disc —
--  Bill total" after the fact instead of only the net figure. 0 for every
--  bill sent before this migration (nothing was ever discounted).
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0064_bill_discount.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.bill
    ADD COLUMN IF NOT EXISTS discount_amount numeric(12,2) NOT NULL DEFAULT 0;
