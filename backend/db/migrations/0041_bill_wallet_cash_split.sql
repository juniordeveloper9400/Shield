-- ============================================================================
--  0041 · Wallet/cash split on a collected bill
-- ============================================================================
--  `collectBillWithWallet` (shieldweb/src/api/billPayments.ts) used to
--  require the member's wallet to cover a bill's FULL amount, or refuse the
--  whole collection. It now debits whatever the wallet actually has (up to
--  the bill amount) and treats the remainder as collected in cash at the
--  counter, in the same OTP-verified action. These two columns are the
--  audit trail of that split — how much of a PAID bill came from each
--  source — so a report can tell "fully on wallet" apart from "member paid
--  part cash" after the fact. Both stay 0 for a bill collected before this
--  migration (nothing to backfill: `collectBillWithWallet` only ever paid
--  bills in full from the wallet, so their whole amount was wallet money).
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0041_bill_wallet_cash_split.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.bill
    ADD COLUMN IF NOT EXISTS wallet_collected numeric(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cash_collected   numeric(12,2) NOT NULL DEFAULT 0;
