-- Adds the rest of the data the member-facing Test/Package detail screen
-- needs so none of it is hardcoded: symptoms chips on Test Master, and the
-- alias/"why this test" text synced onto the member-facing listing the same
-- way migration 0106 synced Fasting.
ALTER TABLE app.lab_test
  ADD COLUMN IF NOT EXISTS symptoms text[] NOT NULL DEFAULT '{}';

ALTER TABLE app.lab_package
  ADD COLUMN IF NOT EXISTS symptoms text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS short_name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS why_this_test text NOT NULL DEFAULT '';
