-- ============================================================================
--  0085 · A real brand list the admin console can pick from
-- ============================================================================
--  app.product.brand has always been plain free text — whatever an admin
--  typed at creation time, no list behind it. This adds app.brand: a real,
--  reusable list the "Add product" form's Brand field now picks from (plus
--  a "+" to register a new one), so two admins typing the same brand don't
--  end up with "Cetaphil" and "cetaphil" as two different values.
--
--  app.product.brand itself is UNCHANGED — still plain text, not a foreign
--  key — so no existing product or query breaks. This is additive: a
--  reference list the UI reads from, backfilled with every distinct brand
--  already in use so the dropdown starts populated, not empty.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0085_product_brand_table.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.brand (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid       uuid NOT NULL DEFAULT gen_random_uuid(),
    name       text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Case-insensitive uniqueness: "Cetaphil" and "cetaphil" are the same brand.
CREATE UNIQUE INDEX IF NOT EXISTS brand_name_lower_idx ON app.brand (lower(name));

-- Backfill every distinct brand already typed on a product, trimmed, so the
-- dropdown isn't empty on day one.
INSERT INTO app.brand (name)
SELECT DISTINCT trim(p.brand)
FROM app.product p
WHERE p.brand IS NOT NULL AND trim(p.brand) <> ''
ON CONFLICT (lower(name)) DO NOTHING;
