-- ============================================================================
--  0056 · Tests and group tests offered to members ("Top Profiles and Tests")
-- ============================================================================
--  A test or group test made on the console's Test Master lived only there:
--  the member apps read `app.lab_package`, so nothing a lab user created as a
--  single test or a group test (Liver Function Test, HbA1c, …) could ever be
--  seen or booked. The apps' Lab screen now has a "Top Profiles and Tests"
--  list beside the package cards, and this is what feeds it:
--
--  - `app.lab_test.show_in_app` — the Test Master's "Show in the app" switch.
--    Off by default (the imported rate list stays console-only); the console
--    turns it on for a test made there.
--  - `app.lab_package.source_test_id` — a test that is switched on is listed as
--    its own one-profile `lab_package` row (that is what a member actually
--    books — `lab_booking.lab_package_id` is not-null), kept in step with the
--    test by the console every time the test is saved. This column ties the
--    listing back to its test. It is what separates a profile/test listing
--    (set) from a real package (null), in the apps and on Member packages.
--    `ON DELETE CASCADE`, so removing a test removes its listing (refused by
--    `lab_booking`'s own RESTRICT while somebody has booked it).
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0056_lab_test_show_in_app.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.lab_test
    ADD COLUMN IF NOT EXISTS show_in_app boolean NOT NULL DEFAULT false;

ALTER TABLE app.lab_package
    ADD COLUMN IF NOT EXISTS source_test_id bigint UNIQUE
        REFERENCES app.lab_test(id) ON DELETE CASCADE;
