-- ============================================================================
--  0048 · Lab test master: scheduled days, reporting time, lab rate
-- ============================================================================
--  The reference-lab rate list the master is seeded from (0049) carries three
--  things app.lab_test had no place for:
--
--    scheduled_days   when the test is run       'Daily', 'Tue, Thu, Sat'
--    reporting_time   when the report is ready   'Same Day', '3rd Day', '1 week'
--    lab_rate         what the lab charges       (rate / amount stay the price
--                                                 the patient pays)
--
--  Free text for the first two, because the list is (a weekday set, "3rd Day",
--  "Next Day (1 pm)", "1 week", ...); 0 in lab_rate means "no lab rate quoted".
--  The existing cut_of_time column holds the list's cut-off time ('1 pm').
--
--  Purely additive and idempotent. Needs 0046 applied first.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0048_lab_test_rate_list_columns.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.lab_test
  ADD COLUMN IF NOT EXISTS scheduled_days text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS reporting_time text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS lab_rate       numeric(12,2) NOT NULL DEFAULT 0
                                          CHECK (lab_rate >= 0);

COMMENT ON COLUMN app.lab_test.scheduled_days IS
  'Days the test is run, as free text: ''Daily'' or ''Tue, Thu, Sat''.';
COMMENT ON COLUMN app.lab_test.reporting_time IS
  'When the report is ready, as free text: ''Same Day'', ''3rd Day'', ''1 week''.';
COMMENT ON COLUMN app.lab_test.lab_rate IS
  'What the lab charges for the test; rate/amount are what the patient pays. 0 = not quoted.';
