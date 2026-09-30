-- ============================================================================
--  0066 · Lab Orders billing — app.lab_bill / app.lab_bill_line
-- ============================================================================
--  Gives a lab booking the same "price it, then collect payment from the
--  member's wallet (cash making up any shortfall) under a phone OTP" flow
--  app.bill/app.bill_line already give a standard/prescription order — same
--  shape (one bill per booking, itemised lines, wallet/cash split, discount
--  audit trail, reusing app.order_payment_status since PENDING/PAID already
--  means exactly what a lab bill's status needs to). Its own table, though,
--  not app.bill widened to a polymorphic FK: app.bill.order_id is NOT NULL
--  UNIQUE and referenced by every existing bill read/write path, and
--  lab_booking has no relationship to app."order" at all, and never has.
--
--  Unlike a prescription's bill, a lab booking's price is already fixed at
--  booking time (lab_package.price × patients) — there is no variable
--  medicine-by-medicine picker here, so lab_bill_line is filled in
--  automatically from the booking's own unit_price/patients_count rather
--  than typed line by line by staff (see backend/api's LabBillService).
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0066_lab_bill.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.lab_bill (
    id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid             uuid NOT NULL DEFAULT gen_random_uuid(),
    lab_booking_id   bigint NOT NULL UNIQUE REFERENCES app.lab_booking(id) ON DELETE CASCADE,
    image            text NOT NULL,
    amount           numeric(12,2) NOT NULL DEFAULT 0,
    discount_amount  numeric(12,2) NOT NULL DEFAULT 0,
    status           app.order_payment_status NOT NULL DEFAULT 'PENDING',
    paid_at          timestamptz,
    wallet_collected numeric(12,2) NOT NULL DEFAULT 0,
    cash_collected   numeric(12,2) NOT NULL DEFAULT 0,
    sent_at          timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);

-- Same shape as app.bill_line, against app.lab_bill instead — see this
-- file's own doc on why it's auto-filled rather than staff-typed.
CREATE TABLE IF NOT EXISTS app.lab_bill_line (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lab_bill_id bigint NOT NULL REFERENCES app.lab_bill(id) ON DELETE CASCADE,
    name        text NOT NULL,
    pack        text NOT NULL DEFAULT '',
    unit_price  numeric(12,2) NOT NULL DEFAULT 0,
    qty         integer NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS lab_bill_line_bill_idx ON app.lab_bill_line(lab_bill_id);

-- A wallet debit from collecting a lab bill needs an audit trail pointing
-- somewhere other than order_id (a lab booking is never an order) — same
-- role order_id already plays for an order-paid wallet_entry.
ALTER TABLE app.wallet_entry
    ADD COLUMN IF NOT EXISTS lab_booking_id bigint REFERENCES app.lab_booking(id);
