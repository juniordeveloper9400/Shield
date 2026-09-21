-- ============================================================================
--  0055 · Lab categories — "Explore by health concern", tied to real tests
-- ============================================================================
--  The Lab Tests member screen has no way to browse by health concern
--  (Diabetes, Liver Health, …) the way a reference lab-booking app does, and
--  neither `app.lab_test` (the LIS-style test master) nor `app.lab_package`
--  (what a member actually books) can be filed under one. This migration adds
--  the category itself, lets both carry one, and gives the console a real way
--  to build a bookable package out of the test master's own tests — until now
--  `app.lab_package` had no admin-console "create" path at all; only price,
--  MRP and active/inactive were ever editable (`src/api/labPackages.ts`), and
--  every row was hand-seeded.
--
--  - `app.lab_category` — id, name, an uploaded `image` (a data URI, same
--    column name and shape as `app.product_category.image`, not a fixed
--    icon-font set), sort, is_active.
--  - `app.lab_test.category_id` — set from the Test Master's create/edit form
--    (`ADD COLUMN`, nullable, `ON DELETE SET NULL` so removing a category
--    never blocks deleting it, it just leaves the test uncategorised).
--  - `app.lab_package.category_id` — same, for the member-facing package;
--    what the category grid actually counts and filters by.
--  - `app.lab_package_test_item` — the new package-builder's own link: which
--    real `app.lab_test` rows a `lab_package` was built from, so re-opening
--    it to change the tests reads back the real selection rather than
--    guessing from `app.lab_profile`'s free-text rows (which the builder also
--    writes, unchanged, so the existing package-card rendering in both apps
--    needs no changes at all to show a console-built package).
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0055_lab_categories.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.lab_category (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid        uuid NOT NULL DEFAULT gen_random_uuid(),
    name        text NOT NULL,
    -- An uploaded data URI, same shape as app.product_category.image — not a
    -- fixed icon-font set, so the admin can put up real artwork per concern.
    image       text,
    sort        integer NOT NULL DEFAULT 0,
    is_active   boolean NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
         WHERE schemaname = 'app' AND indexname = 'lab_category_name_uidx'
    ) THEN
        CREATE UNIQUE INDEX lab_category_name_uidx ON app.lab_category (lower(name));
    END IF;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'lab_category_touch'
    ) THEN
        CREATE TRIGGER lab_category_touch BEFORE UPDATE ON app.lab_category
            FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
    END IF;
END;
$$;

ALTER TABLE app.lab_test
    ADD COLUMN IF NOT EXISTS category_id bigint REFERENCES app.lab_category(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS lab_test_category_idx ON app.lab_test (category_id);

ALTER TABLE app.lab_package
    ADD COLUMN IF NOT EXISTS category_id bigint REFERENCES app.lab_category(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS lab_package_category_idx ON app.lab_package (category_id);

-- The package-builder's own link: which real lab_test rows a console-built
-- package was assembled from. RESTRICT on the test (same as
-- lab_test_group_item) — a test in active use by a package cannot be deleted
-- out from under it; the admin removes it from the package first.
CREATE TABLE IF NOT EXISTS app.lab_package_test_item (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    package_id  bigint NOT NULL REFERENCES app.lab_package(id) ON DELETE CASCADE,
    test_id     bigint NOT NULL REFERENCES app.lab_test(id) ON DELETE RESTRICT,
    sort        integer NOT NULL DEFAULT 0,
    CONSTRAINT lab_package_test_item_unique UNIQUE (package_id, test_id)
);
CREATE INDEX IF NOT EXISTS lab_package_test_item_test_idx ON app.lab_package_test_item (test_id);
