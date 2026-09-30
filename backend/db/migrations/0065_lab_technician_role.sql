-- ============================================================================
--  0065 · LAB_TECHNICIAN admin role
-- ============================================================================
--  A store's own lab technician login — full lab-booking detail (patient,
--  test, report), scoped to their one branch, the same way PHARMACY and
--  DELIVERY are already store-scoped (see migration 0031's own comment on
--  DELIVERY for the precedent this follows).
--
--  Unlike the existing LAB role — one login working every branch's bookings,
--  by design (see backend/api/src/modules/care/booking.service.ts's doc on
--  listLabBookingsForStaff) — LAB_TECHNICIAN sees only their own store's
--  bookings. PHARMACY (the store's own admin) can now also see those same
--  bookings listed alongside their regular orders, but without the
--  patient/test detail — a redacted view, not full lab-technician access.
--
--  No new table: app.admin_user's existing storeId column (generic to any
--  role already) is all a LAB_TECHNICIAN account needs.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0065_lab_technician_role.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TYPE app.admin_role ADD VALUE IF NOT EXISTS 'LAB_TECHNICIAN';
