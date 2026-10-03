-- ============================================================================
--  0070 · Backfill: a script's image was saved, but only to the old column
-- ============================================================================
--  The root app's own upload path (`PrescriptionRepository.insertUpload`)
--  has only ever written an uploaded script's photo to the legacy single
--  column `app.prescription.image` — never to `app.prescription_image`, the
--  newer multi-page-capable table added for rotating one page of a
--  multi-page script without touching the others.
--
--  `OrderRepository.fetchPrescriptions` (what the Track Order screen's
--  "Prescription uploaded" card reads for its own "View" button) reads only
--  `app.prescription_image`, not the legacy column — so every prescription
--  uploaded through the root app's direct-Neon path has shown the plain
--  document-icon placeholder there, with no "View" button, even though the
--  photo was genuinely uploaded and has been sitting in `app.prescription.
--  image` the whole time. `fetchForMember` (My Prescriptions) still reads the
--  legacy column directly, so that screen has shown the photo correctly —
--  only Track Order was affected. The investor app's own upload path
--  (`backend/api`'s `prescription.service.ts`) has only ever written
--  `app.prescription_image` and never had this gap.
--
--  Fixed going forward in `lib/data/neon/prescription_repository.dart`'s
--  `insertUpload`, which now writes both places. This backfills every
--  already-uploaded prescription that has an image in the old column but no
--  corresponding row in the new table yet, so a script uploaded before the
--  fix becomes viewable from Track Order too, without the member re-uploading
--  it.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0070_backfill_prescription_image.sql --yes
-- ============================================================================

SET search_path TO app, public;

INSERT INTO app.prescription_image (prescription_id, sort, image, image_rotation)
SELECT rx.id, 0, rx.image, rx.image_rotation
FROM app.prescription rx
WHERE rx.image IS NOT NULL
  AND rx.image <> ''
  AND NOT EXISTS (
    SELECT 1 FROM app.prescription_image pi
    WHERE pi.prescription_id = rx.id AND pi.sort = 0
  );
