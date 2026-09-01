-- ============================================================================
--  0003 · app.wallet_card approval workflow
-- ============================================================================
--  A privilege card is now submitted from the app as PENDING and credits
--  nothing. A Super Admin approves it in the console (shieldweb/) — which writes
--  the ACTIVATION + BONUS ledger lines and moves the wallet balance — or
--  rejects it with a note the member sees in their wallet.
--
--  Adds the status / review columns to app.wallet_card. Any card that already
--  existed under the old "activate immediately" flow is marked APPROVED so its
--  balance is not retro-actively pulled.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0003_wallet_card_approval.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.wallet_card
    ADD COLUMN IF NOT EXISTS status            app.approval_status NOT NULL DEFAULT 'PENDING',
    ADD COLUMN IF NOT EXISTS submitted_at      timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS reviewed_at       timestamptz,
    ADD COLUMN IF NOT EXISTS reviewer_note     text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS receipt_reference text,
    ADD COLUMN IF NOT EXISTS receipt_file_name text;

-- Cards written before this migration were live the moment they were created.
UPDATE app.wallet_card
   SET status = 'APPROVED', reviewed_at = COALESCE(reviewed_at, created_at)
 WHERE created_at < now() - interval '1 minute'
   AND status = 'PENDING';

CREATE INDEX IF NOT EXISTS wallet_card_status_idx
    ON app.wallet_card(status, submitted_at DESC);
