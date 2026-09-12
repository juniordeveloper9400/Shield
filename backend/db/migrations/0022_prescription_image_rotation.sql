-- ============================================================================
--  0022 · app.prescription gets image_rotation
-- ============================================================================
--  The console's prescription review already let a reviewer rotate the
--  uploaded script's image for reading -- but only in the full-size viewer,
--  and only for that one look: it reset to 0 every time the viewer reopened
--  or a different prescription was selected. A script photographed sideways
--  stayed sideways for the next person to open it.
--
--  image_rotation stores the fix permanently: 0 / 90 / 180 / 270 degrees
--  clockwise, applied wherever the image renders (the small preview and the
--  full-size viewer alike) rather than being a per-view, throwaway setting.
--
--  Idempotent: IF NOT EXISTS, so a re-run is harmless.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0022_prescription_image_rotation.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.prescription
  ADD COLUMN IF NOT EXISTS image_rotation smallint NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'prescription_image_rotation_check'
  ) THEN
    ALTER TABLE app.prescription
      ADD CONSTRAINT prescription_image_rotation_check
      CHECK (image_rotation IN (0, 90, 180, 270));
  END IF;
END $$;

COMMENT ON COLUMN app.prescription.image_rotation IS
  'Degrees clockwise (0/90/180/270) to display the uploaded script image '
  'rotated by, fixed by a reviewer in the console. Applied wherever the '
  'image renders, not just the view that set it.';
