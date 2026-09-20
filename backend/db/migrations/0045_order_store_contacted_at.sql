-- ============================================================================
--  0045 · app."order".store_contacted_at — "the store has contacted you"
-- ============================================================================
--  The member's Track order screen shows four stages: Order placed -> Store
--  contact -> Billed -> Complete. Three of them are already recorded (the
--  order row itself, a bill row, and status = DELIVERED); this stamps the
--  missing one -- the first time staff use the console's Call or WhatsApp
--  button beside the member's phone number on an order (or on the linked
--  prescription's Details step).
--
--  First click wins: the console only ever sets it while it's still NULL, so
--  a later re-contact never moves the date the member sees.
--
--  Purely additive and idempotent. Nothing is backfilled -- an order that was
--  billed or completed before this column existed simply reads as having
--  passed the Store contact stage, because the member app shows the furthest
--  stage reached.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0045_order_store_contacted_at.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app."order"
  ADD COLUMN IF NOT EXISTS store_contacted_at timestamptz;

COMMENT ON COLUMN app."order".store_contacted_at IS
  'When staff first used the console''s Call / WhatsApp button for this '
  'order''s member; drives the "Store contact" stage on the member''s Track '
  'order screen.';
