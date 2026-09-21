-- ============================================================================
--  0052 · Lab bookings: a note from the lab, and the report itself
-- ============================================================================
--  The Lab Admin works a booking in the console's Lab Orders page. Two things
--  were missing for that to be a full workflow:
--
--    app.lab_booking.note              a line from the lab to the member
--                                      ("Please come fasting"), shown in the
--                                      app beside the booking.
--    app.lab_booking.report_uploaded_at  when the report was last attached.
--    app.lab_booking_report            the report itself — one row per page.
--
--  A report page is stored the way a prescription page already is: a resized
--  JPEG data URI in a text column (app.prescription_image), read only by the
--  signed-in member who owns the booking and by staff. It is never given a
--  public URL. `sort` orders the pages; the member sees them in that order.
--
--  Rescheduling needs no column: `scheduled_for` already exists.
--
--  Purely additive and idempotent.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0052_lab_booking_details_report.sql --yes
--
--  To undo: DROP TABLE app.lab_booking_report;
--           ALTER TABLE app.lab_booking DROP COLUMN note, DROP COLUMN report_uploaded_at;
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.lab_booking
  ADD COLUMN IF NOT EXISTS note               text,
  ADD COLUMN IF NOT EXISTS report_uploaded_at timestamptz;

CREATE TABLE IF NOT EXISTS app.lab_booking_report (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lab_booking_id  bigint NOT NULL REFERENCES app.lab_booking(id) ON DELETE CASCADE,
    name            text NOT NULL DEFAULT '',            -- the picked file's name, for the console
    image           text NOT NULL,                       -- resized JPEG data URI
    sort            integer NOT NULL DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS lab_booking_report_booking_idx
  ON app.lab_booking_report(lab_booking_id, sort, id);

COMMENT ON COLUMN app.lab_booking.note IS
  'A line from the lab to the member, shown beside the booking in the app.';
COMMENT ON TABLE app.lab_booking_report IS
  'The lab report for a booking, one row per page (resized JPEG data URI). '
  'Private: read only by the owning member and by staff, never by public URL.';
