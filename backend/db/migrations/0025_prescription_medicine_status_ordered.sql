-- ============================================================================
--  0025 · app.prescription_medicine_status gains a fourth value: ORDERED
-- ============================================================================
--  Migration 0024 gave the intake card's per-medicine Stock status three
--  values: Available / Out of stock / Not possible. A fourth sits between
--  the middle two: out of stock right now, but already re-ordered from the
--  supplier -- distinct from "Not possible" (can never be dispensed here at
--  all -- discontinued, wrong branch, …).
--
--  Postgres can only add an enum value, never remove or reorder one, and
--  ALTER TYPE ... ADD VALUE cannot run inside the same transaction as a
--  statement that uses the new value -- this migration only adds it.
--
--  Idempotent: IF NOT EXISTS, so a re-run is harmless.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0025_prescription_medicine_status_ordered.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TYPE app.prescription_medicine_status ADD VALUE IF NOT EXISTS 'ORDERED';
