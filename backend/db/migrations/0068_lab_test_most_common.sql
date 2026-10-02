-- ============================================================================
--  0068 · Staff-curated "Most Common Tests" banner
-- ============================================================================
--  The apps' Lab section shows a colourful "Most Common Tests" banner strip
--  above the package cards — previously just the first few single tests in
--  whatever order the Test Master's own `sort` happened to leave them in,
--  because the schema had no real "most booked" signal to read instead.
--
--  This gives staff an actual switch for it, the same shape as migration
--  0056's "Show in the app":
--
--  - `app.lab_test.is_most_common` — the Test Master's new "Most Common Test"
--    checkbox, beside "Show in the app" and meaningless without it. Off by
--    default — staff opts a test in, nothing shows just from being created.
--  - `app.lab_package.is_most_common` — mirrored onto the test's own app
--    listing by `syncLabTestListing` (labTests.ts) every time the test is
--    saved, the same way that function already copies over price, MRP and
--    category. The apps read this column directly, with no join back to
--    `lab_test`, exactly how they already read `source_test_id IS NOT NULL`
--    for "is this a profile at all".
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0068_lab_test_most_common.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.lab_test
    ADD COLUMN IF NOT EXISTS is_most_common boolean NOT NULL DEFAULT false;

ALTER TABLE app.lab_package
    ADD COLUMN IF NOT EXISTS is_most_common boolean NOT NULL DEFAULT false;
