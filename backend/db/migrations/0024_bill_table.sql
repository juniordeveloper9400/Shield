-- ============================================================================
--  0024 · A dedicated app.bill table for the store's invoice
-- ============================================================================
--  The store's bill/invoice for an order lived as two columns bolted onto
--  app."order" (bill_image, billed_at — added in migration 0012). That was
--  fine while it was a single field buried in the Orders modal, but the
--  admin console now has a standalone Bills directory, and a real table
--  reads and joins far more naturally than two nullable columns on the
--  order itself — same reasoning as app.order_receipt sitting next to
--  app."order" rather than being columns on it.
--
--  One row per order (order_id is UNIQUE): sending a bill upserts it,
--  replacing one overwrites the same row, removing one deletes it — the
--  same single-bill-per-order behaviour the admin console already has,
--  just backed by a table instead of two columns.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0024_bill_table.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.bill (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid       uuid NOT NULL DEFAULT gen_random_uuid(),
    order_id   bigint NOT NULL UNIQUE REFERENCES app."order"(id) ON DELETE CASCADE,
    image      text NOT NULL,                          -- data: URI, same convention as order.bill_image was
    sent_at    timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Carry over any bill already sent under the old columns before they're
-- dropped below. ON CONFLICT guards a re-run of this migration.
INSERT INTO app.bill (order_id, image, sent_at)
SELECT id, bill_image, COALESCE(billed_at, now())
FROM app."order"
WHERE bill_image IS NOT NULL
ON CONFLICT (order_id) DO NOTHING;

ALTER TABLE app."order" DROP COLUMN IF EXISTS bill_image;
ALTER TABLE app."order" DROP COLUMN IF EXISTS billed_at;
