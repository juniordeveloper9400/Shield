-- ============================================================================
--  0021 · region/state/district/assembly/lsgd/ward gain agent_id
-- ============================================================================
--  The only link between an agent and the slot they head has been
--  app.agent.area_id -- the agent points at their slot, not the other way
--  round. Answering "who heads Kerala" meant querying app.agent by area_id;
--  there was nothing on app.state's own row to look at directly.
--
--  This adds agent_id to every named-slot table (region, state, district,
--  assembly, lsgd, ward) -- a reverse, denormalized mirror of
--  app.agent.area_id, kept in sync by the console (shieldweb src/api/geo.ts
--  resyncGeoSlotAgent, called from approveAgent / convertToAgent /
--  updateAgentPosition) whenever an agent is placed, moved, or removed. The
--  source of truth stays app.agent.area_id; this is a read convenience so
--  "who is the agent for this row" is answerable from the row itself --
--  exactly what the Neon table browser shows without a join.
--
--  ON DELETE SET NULL: deleting an app.agent row (the manual duplicate
--  cleanup path, say) frees the slot automatically, with no application
--  code needed to notice.
--
--  UNIQUE per table: at most one agent per slot at the database level too,
--  not just the application's own duplicate-slot checks (NULLs are exempt
--  from a unique constraint, so any number of unfilled rows is fine).
--
--  Idempotent: every ALTER is IF NOT EXISTS; the backfill only touches rows
--  agent_id hasn't already reached.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0021_geo_slot_agent_id.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.region   ADD COLUMN IF NOT EXISTS agent_id bigint REFERENCES app.agent(id) ON DELETE SET NULL;
ALTER TABLE app.state    ADD COLUMN IF NOT EXISTS agent_id bigint REFERENCES app.agent(id) ON DELETE SET NULL;
ALTER TABLE app.district ADD COLUMN IF NOT EXISTS agent_id bigint REFERENCES app.agent(id) ON DELETE SET NULL;
ALTER TABLE app.assembly ADD COLUMN IF NOT EXISTS agent_id bigint REFERENCES app.agent(id) ON DELETE SET NULL;
ALTER TABLE app.lsgd     ADD COLUMN IF NOT EXISTS agent_id bigint REFERENCES app.agent(id) ON DELETE SET NULL;
ALTER TABLE app.ward     ADD COLUMN IF NOT EXISTS agent_id bigint REFERENCES app.agent(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'region_agent_id_key') THEN
    ALTER TABLE app.region ADD CONSTRAINT region_agent_id_key UNIQUE (agent_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'state_agent_id_key') THEN
    ALTER TABLE app.state ADD CONSTRAINT state_agent_id_key UNIQUE (agent_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'district_agent_id_key') THEN
    ALTER TABLE app.district ADD CONSTRAINT district_agent_id_key UNIQUE (agent_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'assembly_agent_id_key') THEN
    ALTER TABLE app.assembly ADD CONSTRAINT assembly_agent_id_key UNIQUE (agent_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'lsgd_agent_id_key') THEN
    ALTER TABLE app.lsgd ADD CONSTRAINT lsgd_agent_id_key UNIQUE (agent_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ward_agent_id_key') THEN
    ALTER TABLE app.ward ADD CONSTRAINT ward_agent_id_key UNIQUE (agent_id);
  END IF;
END $$;

-- Backfill from whatever already holds each slot today.
UPDATE app.region   t SET agent_id = a.id FROM app.agent a WHERE a.area_id = t.id AND a.level = 'REGION'   AND a.approval_status = 'APPROVED' AND t.agent_id IS DISTINCT FROM a.id;
UPDATE app.state    t SET agent_id = a.id FROM app.agent a WHERE a.area_id = t.id AND a.level = 'STATE'    AND a.approval_status = 'APPROVED' AND t.agent_id IS DISTINCT FROM a.id;
UPDATE app.district t SET agent_id = a.id FROM app.agent a WHERE a.area_id = t.id AND a.level = 'DISTRICT' AND a.approval_status = 'APPROVED' AND t.agent_id IS DISTINCT FROM a.id;
UPDATE app.assembly t SET agent_id = a.id FROM app.agent a WHERE a.area_id = t.id AND a.level = 'ASSEMBLY' AND a.approval_status = 'APPROVED' AND t.agent_id IS DISTINCT FROM a.id;
UPDATE app.lsgd     t SET agent_id = a.id FROM app.agent a WHERE a.area_id = t.id AND a.level = 'LSGD'     AND a.approval_status = 'APPROVED' AND t.agent_id IS DISTINCT FROM a.id;
UPDATE app.ward     t SET agent_id = a.id FROM app.agent a WHERE a.area_id = t.id AND a.level = 'WARD'     AND a.approval_status = 'APPROVED' AND t.agent_id IS DISTINCT FROM a.id;

COMMENT ON COLUMN app.region.agent_id   IS 'The approved agent heading this region, mirrored from app.agent.area_id. NULL when the slot is open.';
COMMENT ON COLUMN app.state.agent_id    IS 'The approved agent heading this state, mirrored from app.agent.area_id. NULL when the slot is open.';
COMMENT ON COLUMN app.district.agent_id IS 'The approved agent heading this district, mirrored from app.agent.area_id. NULL when the slot is open.';
COMMENT ON COLUMN app.assembly.agent_id IS 'The approved agent heading this assembly segment, mirrored from app.agent.area_id. NULL when the slot is open.';
COMMENT ON COLUMN app.lsgd.agent_id     IS 'The approved agent heading this LSGD, mirrored from app.agent.area_id. NULL when the slot is open.';
COMMENT ON COLUMN app.ward.agent_id     IS 'The approved agent heading this ward, mirrored from app.agent.area_id. NULL when the slot is open.';
