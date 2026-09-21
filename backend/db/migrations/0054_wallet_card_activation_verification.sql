-- ============================================================================
--  0054 · Health Pass activation: the admin's own verification checklist
-- ============================================================================
--  Before approving an activation and crediting real money, a reviewer now
--  records four things of their own, separate from what the member submitted
--  (`receipt_reference`, `receipt_file_name`, `receipt_image`):
--
--    verified_reference  text            the UTR / transaction id the admin
--                                         read off their own bank statement
--    received_on         date            when the admin actually saw the
--                                         transfer land
--    receipt_verified     boolean         the admin has looked at the
--                                         uploaded receipt image and it
--                                         checks out
--    received_amount      numeric(12,2)   what the admin saw credited,
--                                         compared against `amount` (the
--                                         load the member claims)
--
--  Purely an audit trail on `app.wallet_card` — never read by
--  `app.approve_wallet_card_activation` (migration 0033) or any commission
--  logic, which are unchanged. The console (`ActivationDetailPage.tsx`)
--  enables its Approve button only once all four are filled in; this is
--  where that record is kept.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0054_wallet_card_activation_verification.sql --yes
--
--  To undo: ALTER TABLE app.wallet_card
--             DROP COLUMN verified_reference, DROP COLUMN received_on,
--             DROP COLUMN receipt_verified, DROP COLUMN received_amount;
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.wallet_card
  ADD COLUMN IF NOT EXISTS verified_reference text,
  ADD COLUMN IF NOT EXISTS received_on         date,
  ADD COLUMN IF NOT EXISTS receipt_verified     boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS received_amount      numeric(12,2);

COMMENT ON COLUMN app.wallet_card.verified_reference IS
  'The UTR / transaction id the admin read off their own bank statement — separate from receipt_reference, what the member claims.';
COMMENT ON COLUMN app.wallet_card.received_on IS
  'When the admin actually saw the transfer land, recorded while reviewing.';
COMMENT ON COLUMN app.wallet_card.receipt_verified IS
  'The admin has looked at the uploaded receipt image and it checks out.';
COMMENT ON COLUMN app.wallet_card.received_amount IS
  'What the admin saw credited, compared against amount (the load the member claims).';
