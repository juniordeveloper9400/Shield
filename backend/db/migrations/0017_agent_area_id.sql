-- ============================================================================
--  0017 · app.agent gets area_id — the real slot id behind `area`
-- ============================================================================
--  `app.agent.area` (migration in app_schema.sql) is free text — a display
--  name only, e.g. "Kovalam". Matching an agent to their slot by that name
--  is exactly the bug fixed on the client side today (GeoHierarchy /
--  Agent.areaId, agent_geo.dart): the real Kerala data repeats thousands of
--  ward names and a hundred-plus names across different tiers, so a bare
--  name cannot tell two slots apart.
--
--  `area_id` is that slot's real id from whichever geo table the agent's
--  `level` points at — app.region / app.state / app.district / app.assembly
--  / app.lsgd / app.ward — a different table per level, so this is not a
--  normal single-table foreign key. Left unconstrained by a DB-level FK on
--  purpose; the app enforces which table it must resolve in for the given
--  level. NULL for the national agent (heads no single slot) and for an
--  agent placed on a free-text `place` rather than a fixed slot.
--
--  Idempotent: guarded with IF NOT EXISTS, so a re-run is harmless.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0017_agent_area_id.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.agent ADD COLUMN IF NOT EXISTS area_id uuid;

COMMENT ON COLUMN app.agent.area_id IS
  'The real slot id (app.region/state/district/assembly/lsgd/ward, chosen by level) '
  'that app.agent.area names on display. No DB-level FK — polymorphic by level; '
  'app-enforced. NULL for the national agent or a free-text-place agent.';
