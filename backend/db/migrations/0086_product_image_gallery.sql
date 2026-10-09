-- ============================================================================
--  0086 · More than one image per product, with a primary
-- ============================================================================
--  app.product.image has always been one image. This adds app.product_image
--  — every image a product has, in order — while leaving app.product.image
--  exactly as every other reader (the apps' product cards, cart, order
--  lines) already expects it: the primary image, kept in sync as whichever
--  row has sort = 0 here.
--
--  Nothing existing reads this table yet; it is additive, and the admin
--  console's "Add product" form is the first and only writer so far (see
--  that change for how "Set as primary" renumbers sort).
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0086_product_image_gallery.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.product_image (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id bigint NOT NULL REFERENCES app.product(id) ON DELETE CASCADE,
    image      text NOT NULL,
    -- 0 = primary, matching app.product.image.
    sort       integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS product_image_product_idx ON app.product_image(product_id, sort);
