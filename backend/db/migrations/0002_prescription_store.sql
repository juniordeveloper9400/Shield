-- ============================================================================
--  0002 · app.prescription.store_id — the branch a script is filled at
-- ============================================================================
--  app.prescription had no branch column, so the admin console (shieldweb/)
--  attributed every uploaded script to the member's home branch. A member who
--  skipped registration has no home branch, so their scripts were invisible to
--  every Pharmacy Admin (only a Super Admin saw them).
--
--  The Flutter app now resolves a branch when the prescription is uploaded
--  (registered store → nearest by pincode → first branch in the directory) and
--  writes it here. The console reads store_id first, then the linked
--  app.prescription_order.store_id, then the member's home branch.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0002_prescription_store.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.prescription
    ADD COLUMN IF NOT EXISTS store_id bigint
        REFERENCES app.shield_store(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS prescription_store_idx ON app.prescription(store_id);
