-- ============================================================================
--  0067 · A lab test can also be reachable from a second health-concern tile
-- ============================================================================
--  `app.lab_package.category_id` has always been one column — a test or
--  package sits under exactly one "Explore by health concern" tile. That is
--  right for most tests, but some genuinely belong under more than one
--  concern (FSH, LH and SHBG matter to both a men's and a women's hormone
--  workup; Anti-Sperm Antibodies comes up in both too) — and the column
--  can't express that without picking a side.
--
--  `category_id` stays exactly what it was: the one PRIMARY category the
--  admin console's Category field edits, and what every existing count
--  (care.service.ts's listLabCategories, migration 0056's own sync) already
--  keys off. This adds `app.lab_package_extra_category` — any number of
--  ADDITIONAL categories on top, read alongside the primary one wherever a
--  member browses by category, never replacing it.
-- ============================================================================

SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.lab_package_extra_category (
    package_id  bigint NOT NULL REFERENCES app.lab_package(id) ON DELETE CASCADE,
    category_id bigint NOT NULL REFERENCES app.lab_category(id) ON DELETE CASCADE,
    PRIMARY KEY (package_id, category_id)
);

CREATE INDEX IF NOT EXISTS lab_package_extra_category_category_idx
    ON app.lab_package_extra_category (category_id);
