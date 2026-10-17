-- Migration 0105: Add fix_charge to app.lab_booking
BEGIN;
ALTER TABLE app.lab_booking ADD COLUMN IF NOT EXISTS fix_charge numeric(12, 2) NOT NULL DEFAULT 0;
COMMIT;
