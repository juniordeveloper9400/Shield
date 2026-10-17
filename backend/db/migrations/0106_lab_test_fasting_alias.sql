-- Adds a structured "Fasting" prep field (Test Master, for a PACKAGE-type
-- test, synced onto the member-facing package) and lets each included-test
-- row on a package (app.lab_profile) carry a real link back to its Test
-- Master row plus that test's short name/alias — so tapping an included
-- test in the app can open a real Test Details page.
ALTER TABLE app.lab_test
  ADD COLUMN IF NOT EXISTS fasting text NOT NULL DEFAULT '';

ALTER TABLE app.lab_package
  ADD COLUMN IF NOT EXISTS fasting text NOT NULL DEFAULT '';

ALTER TABLE app.lab_profile
  ADD COLUMN IF NOT EXISTS test_id bigint REFERENCES app.lab_test(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS short_name text NOT NULL DEFAULT '';
