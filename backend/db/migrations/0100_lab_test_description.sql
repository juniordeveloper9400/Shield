-- Public test descriptions are separate from private staff notes.
BEGIN;
ALTER TABLE app.lab_test ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '';
UPDATE app.lab_test AS t
SET description = p.about
FROM app.lab_package AS p
WHERE p.source_test_id = t.id AND t.description = '' AND p.about IS NOT NULL;
COMMIT;
