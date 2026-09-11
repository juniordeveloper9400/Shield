-- ============================================================================
--  0019 · app.approval_status gains ON_HOLD
-- ============================================================================
--  Reviewing a Health Pass activation (app.wallet_card.status) was a strict
--  binary: approve or reject. There was no way to pause on one that needs
--  more information from the member (a blurry receipt, an amount that
--  doesn't quite match) without either deciding it outright or leaving it
--  silently sitting in the pending queue looking untouched.
--
--  app.approval_status is shared with app.approval (the pharmacist
--  substitution/out-of-stock approval on a prescription) -- adding a value
--  here does not force that table to use it; nothing changes for rows or
--  code that never reference ON_HOLD.
--
--  `ADD VALUE IF NOT EXISTS` (PG 12+; Neon runs PG 18) makes this idempotent
--  directly -- deliberately NOT wrapped in a DO block or function body: PG
--  refuses ALTER TYPE ... ADD VALUE inside either, since both run as an
--  implicit subtransaction and this statement cannot run inside one (a
--  plain top-level statement, or one in an explicit BEGIN/COMMIT with no
--  exception handler, is fine -- only a sub-transaction is the problem).
--    dart run backend/db/apply_migration.dart backend/db/migrations/0019_approval_status_on_hold.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TYPE app.approval_status ADD VALUE IF NOT EXISTS 'ON_HOLD';
