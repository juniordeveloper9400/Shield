-- ============================================================================
--  0040 · Multiple images per prescription upload
-- ============================================================================
--  A prescription used to carry exactly one photo, in `app.prescription.
--  image` (a resized JPEG data: URI) plus `image_rotation`. A prescription
--  is often more than one page (front/back, or several pages of a longer
--  script), so a member can now attach up to 3 images at upload — this adds
--  a child table to hold them, ordered, each with its own rotation (a
--  reviewer may need to fix a sideways photo on page 2 but not page 1).
--
--  Existing single-image rows are backfilled into the new table as their
--  one (sort 0) image, so nothing already uploaded is lost. Going forward,
--  `app.prescription.image` / `image_rotation` are no longer written to —
--  every reader (backend/api, shieldweb) moves to `app.prescription_image`
--  as the one source of truth. The two legacy columns are left in place
--  rather than dropped, matching this codebase's usual caution around
--  removing columns a rollback might still need.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0040_prescription_multi_image.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.prescription_image (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    prescription_id bigint NOT NULL REFERENCES app.prescription(id) ON DELETE CASCADE,
    sort            integer NOT NULL DEFAULT 0,
    image           text NOT NULL,
    image_rotation  smallint NOT NULL DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prescription_image_prescription_idx
    ON app.prescription_image(prescription_id, sort);

-- One-time backfill — only rows that don't already have a prescription_image
-- (so re-running this migration never duplicates rows).
INSERT INTO app.prescription_image (prescription_id, sort, image, image_rotation)
SELECT rx.id, 0, rx.image, rx.image_rotation
FROM app.prescription rx
WHERE rx.image IS NOT NULL
  AND rx.image <> ''
  AND NOT EXISTS (
      SELECT 1 FROM app.prescription_image pi WHERE pi.prescription_id = rx.id
  );
