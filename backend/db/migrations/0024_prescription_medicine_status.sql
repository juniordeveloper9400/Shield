-- ============================================================================
--  0024 · app.prescription_medicine gains a pharmacist-only stock status
-- ============================================================================
--  Per medicine line on the intake card, whether the pharmacist actually has
--  it on hand right now: Stock available / Out of stock / Not possible
--  (cannot be dispensed at all -- discontinued, needs a special order, …).
--  Purely an internal counter note, set and changed the same way as any
--  other intake-card field, any number of times. The member's own app never
--  shows it -- their intake card is unchanged by this.
--
--  Idempotent: the enum is created only if missing, the column only if
--  missing, so a re-run is harmless and never touches data already saved.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0024_prescription_medicine_status.sql --yes
-- ============================================================================

SET search_path TO app, public;

DO $$ BEGIN
    CREATE TYPE app.prescription_medicine_status AS ENUM
        ('AVAILABLE', 'OUT_OF_STOCK', 'NOT_POSSIBLE');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE app.prescription_medicine
  ADD COLUMN IF NOT EXISTS status app.prescription_medicine_status
    NOT NULL DEFAULT 'AVAILABLE';

COMMENT ON COLUMN app.prescription_medicine.status IS
  'Pharmacist-only stock status for this line, set from the console''s '
  'intake-card editor -- never shown in the member''s own app.';
