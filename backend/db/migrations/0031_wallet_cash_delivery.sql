-- ============================================================================
--  0031 · wallet/cash checkout, delivery method, delivery-boy role, priced
--         prescription bills
-- ============================================================================
--  Replaces the bank-transfer-only order checkout with two real methods:
--  paying from the member's SHIELD wallet, or cash settled in person (handed
--  to a delivery boy on home delivery, or paid at the counter on store
--  pickup). Adds the fulfilment choice itself (home delivery vs store
--  pickup), a payment_status on the order so cash can stay "pending" until
--  someone actually collects it, a DELIVERY console role + per-order
--  assignment so a delivery boy can see and settle their own drops, and
--  turns app.bill from an unstructured image into a priced invoice (amount +
--  line items) so a prescription order can finally be paid for.
--
--  bank-transfer is not deleted — existing orders/order_receipt rows FK to
--  it — just marked not live so it stops being offered at checkout. The
--  Health Pass / privilege-plan purchase screen (which funds the wallet) is
--  untouched by this migration; it doesn't use app.bill or these order
--  columns.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0031_wallet_cash_delivery.sql --yes
-- ============================================================================

SET search_path TO app, public;

DO $$ BEGIN
    CREATE TYPE app.fulfillment_type AS ENUM ('HOME_DELIVERY', 'STORE_PICKUP');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE app.order_payment_status AS ENUM ('PENDING', 'PAID');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TYPE app.admin_role ADD VALUE IF NOT EXISTS 'DELIVERY';

ALTER TABLE app."order"
    ADD COLUMN IF NOT EXISTS fulfillment_type app.fulfillment_type NOT NULL DEFAULT 'HOME_DELIVERY',
    ADD COLUMN IF NOT EXISTS payment_status   app.order_payment_status NOT NULL DEFAULT 'PENDING',
    ADD COLUMN IF NOT EXISTS delivery_boy_id  bigint REFERENCES app.admin_user(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS paid_at          timestamptz;

ALTER TABLE app.bill
    ADD COLUMN IF NOT EXISTS amount   numeric(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS status   app.order_payment_status NOT NULL DEFAULT 'PENDING',
    ADD COLUMN IF NOT EXISTS paid_at  timestamptz;

-- Itemised breakdown for a priced bill — same shape as app.order_line, but
-- against the bill (so a prescription order, priced only after intake, can
-- carry a proper line-item invoice rather than order_line's cart-time rows).
CREATE TABLE IF NOT EXISTS app.bill_line (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bill_id     bigint NOT NULL REFERENCES app.bill(id) ON DELETE CASCADE,
    name        text NOT NULL,
    pack        text NOT NULL DEFAULT '',
    unit_price  numeric(12,2) NOT NULL DEFAULT 0,
    qty         integer NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS bill_line_bill_idx ON app.bill_line(bill_id);

INSERT INTO app.payment_method (code, name, blurb, is_live, sort)
VALUES
    ('wallet', 'Wallet balance', 'Pay from your SHIELD wallet', true, 0),
    ('cash', 'Cash', 'Pay the delivery person, or at the store on pickup', true, 1)
ON CONFLICT (code) DO UPDATE
    SET name = excluded.name, blurb = excluded.blurb, is_live = excluded.is_live, sort = excluded.sort;

UPDATE app.payment_method SET is_live = false, sort = 9 WHERE code = 'bank-transfer';
