-- Adds test_mode and report_on to app.lab_package, synced from app.lab_test,
-- so member-facing package cards and detail screens show the admin-entered
-- Test Mode (Automated/Manual/etc) and Report On (e.g. 5 Minutes / Same Day)
-- alongside the Sample type (Serum/CSF).
ALTER TABLE app.lab_package
  ADD COLUMN IF NOT EXISTS test_mode text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS report_on text NOT NULL DEFAULT '';

-- Backfill test_mode and report_on for any package synced from a Test Master row.
UPDATE app.lab_package p
SET
  test_mode = COALESCE(t.test_mode, ''),
  report_on = CASE
    WHEN t.report_on_value > 0 THEN (t.report_on_value::text || ' ' || COALESCE(NULLIF(t.report_on_unit, ''), 'Hours'))
    ELSE COALESCE(t.reporting_time, '')
  END,
  report_in = CASE
    WHEN COALESCE(NULLIF(p.report_in, ''), '') != '' THEN p.report_in
    WHEN t.report_on_value > 0 THEN (t.report_on_value::text || ' ' || COALESCE(NULLIF(t.report_on_unit, ''), 'Hours'))
    ELSE COALESCE(t.reporting_time, '')
  END
FROM app.lab_test t
WHERE p.source_test_id = t.id;
