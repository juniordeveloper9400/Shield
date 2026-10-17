-- Staff-managed pick lists for the Test Master's free-text fields
-- (Department, Method, Sample, Volume, Scheduled Days, Cut of time,
-- Reporting Time, Technology, Test Mode, Perform At) — separate from any
-- one test's own value, so an entry can be added, renamed or removed
-- without touching every test that happens to use it.
BEGIN;

CREATE TABLE IF NOT EXISTS app.lab_test_field_option (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  field_key text NOT NULL,
  value text NOT NULL,
  sort integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS lab_test_field_option_key_value_uidx
  ON app.lab_test_field_option (field_key, lower(value));

-- Seed from whatever every saved test already uses, per field, so existing
-- values are managed from day one rather than starting the list empty.
INSERT INTO app.lab_test_field_option (field_key, value)
SELECT 'department', department FROM app.lab_test WHERE trim(department) != ''
UNION
SELECT 'method', method FROM app.lab_test WHERE trim(method) != ''
UNION
SELECT 'sample', sample FROM app.lab_test WHERE trim(sample) != ''
UNION
SELECT 'volume', volume FROM app.lab_test WHERE trim(volume) != ''
UNION
SELECT 'scheduledDays', scheduled_days FROM app.lab_test WHERE trim(scheduled_days) != ''
UNION
SELECT 'cutOfTime', cut_of_time FROM app.lab_test WHERE trim(cut_of_time) != ''
UNION
SELECT 'reportingTime', reporting_time FROM app.lab_test WHERE trim(reporting_time) != ''
UNION
SELECT 'technology', technology FROM app.lab_test WHERE trim(technology) != ''
UNION
SELECT 'testMode', test_mode FROM app.lab_test WHERE trim(test_mode) != ''
UNION
SELECT 'performAt', perform_at FROM app.lab_test WHERE trim(perform_at) != ''
ON CONFLICT DO NOTHING;

-- Also seed shieldweb's own built-in suggestion lists (src/lib/labTests.ts)
-- so the list starts populated even on a database with no tests yet — a
-- one-time copy, not a synced source of truth with that file from here on.
INSERT INTO app.lab_test_field_option (field_key, value)
VALUES
  ('department', 'BIOCHEMISTRY'), ('department', 'HAEMATOLOGY'), ('department', 'CLINICAL PATHOLOGY'),
  ('department', 'MICROBIOLOGY'), ('department', 'SEROLOGY'), ('department', 'IMMUNOLOGY'),
  ('department', 'HORMONES'), ('department', 'HISTOPATHOLOGY'), ('department', 'CYTOLOGY'),
  ('department', 'MOLECULAR BIOLOGY'),
  ('sample', 'SERUM'), ('sample', 'PLASMA'), ('sample', 'WHOLE BLOOD'), ('sample', 'URINE'),
  ('sample', 'STOOL'), ('sample', 'SPUTUM'), ('sample', 'SWAB'), ('sample', 'CSF'), ('sample', 'BODY FLUID'),
  ('volume', '1 ml'), ('volume', '2 ml'), ('volume', '3 ml'), ('volume', '5 ml'), ('volume', '10 ml'), ('volume', '50 ml'),
  ('cutOfTime', '10 am'), ('cutOfTime', '11 am'), ('cutOfTime', '12 pm'), ('cutOfTime', '1 pm'),
  ('cutOfTime', '2 pm'), ('cutOfTime', '3 pm'), ('cutOfTime', '4 pm'),
  ('scheduledDays', 'Daily'), ('scheduledDays', 'Mon, Wed, Fri'), ('scheduledDays', 'Tue, Thu, Sat'),
  ('scheduledDays', 'Mon, Thu'), ('scheduledDays', 'Tue, Fri'), ('scheduledDays', 'Wed, Sat'),
  ('scheduledDays', 'Mon'), ('scheduledDays', 'Tue'), ('scheduledDays', 'Wed'), ('scheduledDays', 'Thu'),
  ('scheduledDays', 'Fri'), ('scheduledDays', 'Sat'),
  ('reportingTime', 'Same Day'), ('reportingTime', 'Next Day'), ('reportingTime', '2nd Day'),
  ('reportingTime', '3rd Day'), ('reportingTime', '4th Day'), ('reportingTime', '5th Day'), ('reportingTime', '1 week'),
  ('technology', 'Spectrophotometry'), ('technology', 'Immunoassay'), ('technology', 'CLIA'),
  ('technology', 'ELISA'), ('technology', 'Electrolyte analyser'), ('technology', 'Microscopy'), ('technology', 'Culture'),
  ('testMode', 'Manual'), ('testMode', 'Automated'), ('testMode', 'Semi-automated'),
  ('performAt', 'In House'), ('performAt', 'Outsourced')
ON CONFLICT DO NOTHING;

COMMIT;
