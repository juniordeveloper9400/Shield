-- ============================================================================
--  0050 · Lab test master: where a test came from
-- ============================================================================
--  The console's "Saved tests" list should show the tests the lab creates, not
--  the 525-test reference rate list (0049) it was seeded with. That list stays
--  in the table -- it is what a Group Test or Package picks its member tests
--  from -- but is tagged so the two can be told apart:
--
--    source = 'ADMIN'      created on the Test Master tab (the default)
--    source = 'RATE_LIST'  imported from the reference-lab rate list
--
--  Existing rows written by the 0049 import (created_by = 'Rate list import')
--  are re-tagged RATE_LIST; everything else, including any test already
--  created in the console, stays ADMIN. 0049 itself now sets the tag for a
--  database seeded after this change, so this is a no-op there.
--
--  Purely additive and idempotent. Needs 0046 applied first.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0050_lab_test_source.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.lab_test
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'ADMIN'
  CHECK (source IN ('ADMIN', 'RATE_LIST'));

UPDATE app.lab_test
   SET source = 'RATE_LIST'
 WHERE created_by = 'Rate list import' AND source = 'ADMIN';

CREATE INDEX IF NOT EXISTS lab_test_source_idx ON app.lab_test (source, is_active);

COMMENT ON COLUMN app.lab_test.source IS
  'ADMIN = created in the console; RATE_LIST = imported reference-lab rate list (hidden from Saved tests, offered when building a group).';
