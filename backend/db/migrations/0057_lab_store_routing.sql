-- ============================================================================
--  0057 · Lab bookings route to a real branch, like a product order does
-- ============================================================================
--  `app.lab_booking` has never carried a branch — every lab order landed
--  nowhere in particular, and the Lab Admin's own "Lab Orders" screen had no
--  branch to scope or even show. This gives it the same shape a standard
--  order already has:
--
--  - `app.shield_store.offers_lab_collection` — a branch's own switch for
--    whether it takes lab bookings at all (a branch with no phlebotomist on
--    staff, say). On by default; the console can turn it off per branch.
--  - `app.lab_booking.store_id` — which branch a booking is routed to,
--    `ON DELETE SET NULL` so a branch that closes never blocks deleting it.
--
--  A member's own home branch (`app.users.home_store_id`) is where their lab
--  bookings default to, the same as a standard order — the app still lets
--  them pick a different one (any branch with `offers_lab_collection`) before
--  checkout, the same freedom the branch picker already gives at registration.
--
--  This migration also settles two explicit admin decisions, applied once,
--  directly:
--   - every existing branch is switched active (`is_active = true`) —
--     none of the ten real branches were serving a member until now;
--   - Karinkallathani (SHD-KKT) and Makkaraparamba (SHD-MKP) do not take lab
--     bookings (`offers_lab_collection = false`); every other existing branch
--     does. Two more branches (an "AR Nagar" and a "Vengara") were also named
--     to exclude from lab, but neither exists yet — there is nothing here to
--     switch off until they are created with their own code, area, city,
--     state and pincode.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0057_lab_store_routing.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.shield_store
    ADD COLUMN IF NOT EXISTS offers_lab_collection boolean NOT NULL DEFAULT true;

ALTER TABLE app.lab_booking
    ADD COLUMN IF NOT EXISTS store_id bigint REFERENCES app.shield_store(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS lab_booking_store_idx ON app.lab_booking (store_id);

-- Explicit admin decisions, applied once (harmless to re-run — each is
-- already the desired end state, not a relative change).
UPDATE app.shield_store SET is_active = true WHERE is_active = false;
UPDATE app.shield_store SET offers_lab_collection = false WHERE code IN ('SHD-KKT', 'SHD-MKP');
