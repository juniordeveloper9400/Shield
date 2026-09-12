-- ============================================================================
--  0023 · app.prescription_medicine gains route_time
-- ============================================================================
--  The intake card's per-medicine row was Name / Pack / Intake (the
--  three-digit morning-afternoon-night code) / Quantity. The console's
--  review form now also captures how and when to take it (e.g. "Oral,
--  after food") alongside the dosage form (Pack, relabelled Type in the
--  form -- same column, no schema change needed for that one) -- something
--  the intake code alone doesn't say.
--
--  Idempotent: IF NOT EXISTS, so a re-run is harmless.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0023_prescription_medicine_route_time.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.prescription_medicine
  ADD COLUMN IF NOT EXISTS route_time text NOT NULL DEFAULT '';

COMMENT ON COLUMN app.prescription_medicine.route_time IS
  'How and when to take this medicine, e.g. "Oral, after food" -- free text '
  'the pharmacist enters alongside the structured intake code.';
