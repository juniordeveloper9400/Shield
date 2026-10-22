-- ============================================================================
--  0112 · One order id across every test placed together
-- ============================================================================
--  Each test in a lab cart still books as its own app.lab_booking row — its
--  own status, report and bill stay independently trackable, which the whole
--  admin workflow (confirm, assign staff, attach a report, bill) already
--  depends on per booking. What was missing was any way to tell "these three
--  rows were placed in the same checkout" from "three separate times the
--  member booked one test each" — order_group_id is that tag: the app
--  generates one uuid per "Place lab test" tap and sends it on every booking
--  from that cart, so My Lab Bookings / Lab Orders can group and count them
--  as a single order while every per-test action still targets its own row.
--
--  Null for every booking placed before this existed, and for a single-test
--  checkout if the client chooses not to send one — both read as "its own
--  order of one", same as a group of size one would.
--
--  Idempotent — safe to run more than once. Apply this BEFORE deploying the
--  backend that reads it:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0112_lab_booking_order_group.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.lab_booking
    ADD COLUMN IF NOT EXISTS order_group_id uuid;

CREATE INDEX IF NOT EXISTS lab_booking_order_group_id_idx
    ON app.lab_booking (order_group_id)
    WHERE order_group_id IS NOT NULL;
