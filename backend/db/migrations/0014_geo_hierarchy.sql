-- ============================================================================
--  0014 · Geographic hierarchy — one table per tier, UUIDv7 keys
-- ============================================================================
--  Replaces app.agent_geo_node (the slug-id self-referential slot table from
--  migration 0011 — its bigint rewrite was never applied) with one table per
--  administrative tier, linked child -> parent by real UUID foreign keys.
--
--  Tree:  region -> state -> district -> assembly -> lsgd -> ward
--
--  There is no `national` table: India is implicit. `region` instead carries
--  `national_agent_id` — the single national-tier agent the six regions all
--  report up to. Nullable so the schema exists before that agent does; it
--  points at app.agent (whose `level` enum already has 'NATIONAL'),
--  ON DELETE SET NULL so removing the agent never touches the regions.
--
--  Every primary key is `id uuid DEFAULT uuidv7()` — time-ordered, index
--  friendly, nothing to hand-craft or keep in step. Neon runs PostgreSQL 18,
--  so uuidv7() is built in (no extension).
--
--  LSGD bodies (corporation / municipality / grama panchayat) are ONE table
--  with a `type` (app.lsgd_type enum) — not three tables. A ward hangs off an
--  lsgd whatever its type.
--
--  Deletes up the geographic chain are ON DELETE RESTRICT: removing a parent
--  that still has children is refused rather than silently cascading a whole
--  subtree away. Delete leaves first.
--
--  No seed rows — the real region..ward data is loaded separately.
--
--  Re-runnable: the whole file DROPs and rebuilds every table below.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0014_geo_hierarchy.sql --yes
--
--  App follow-up (NOT done here): agent_geo_repository.dart / agent_geo.dart /
--  agent_team_tree_screen.dart / agent_registration_screen.dart — in both
--  shield/ and "shield agent_invester/" — plus test/agent_portal_test.dart and
--  the (not-yet-built) admin-web hierarchy module still target the old
--  agent_geo_node shape and must be reworked against these tables.
-- ============================================================================

SET search_path TO app, public;

-- ---- drop the obsolete slot table (verified: no inbound FKs) -------------
DROP TABLE IF EXISTS app.agent_geo_node CASCADE;
DROP FUNCTION IF EXISTS app._geo_slug(text);

-- ---- re-runnable: drop the new shape too, deepest dependency first -------
DROP TABLE IF EXISTS app.ward      CASCADE;
DROP TABLE IF EXISTS app.lsgd      CASCADE;
DROP TABLE IF EXISTS app.assembly  CASCADE;
DROP TABLE IF EXISTS app.district  CASCADE;
DROP TABLE IF EXISTS app.state     CASCADE;
DROP TABLE IF EXISTS app.region    CASCADE;
DROP TYPE  IF EXISTS app.lsgd_type CASCADE;

CREATE TYPE app.lsgd_type AS ENUM ('corporation', 'municipality', 'grama_panchayat');

-- ---- region — the top geographic tier ----------------------------------
CREATE TABLE app.region (
    id                uuid PRIMARY KEY DEFAULT uuidv7(),
    national_agent_id bigint REFERENCES app.agent(id) ON DELETE SET NULL,
    name              text NOT NULL,
    code              text NOT NULL DEFAULT '',
    sort              integer NOT NULL DEFAULT 0,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT region_name_key UNIQUE (name)
);
CREATE INDEX region_national_agent_idx ON app.region (national_agent_id);

CREATE TABLE app.state (
    id         uuid PRIMARY KEY DEFAULT uuidv7(),
    region_id  uuid NOT NULL REFERENCES app.region(id) ON DELETE RESTRICT,
    name       text NOT NULL,
    code       text NOT NULL DEFAULT '',
    sort       integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT state_parent_name_key UNIQUE (region_id, name)
);
CREATE INDEX state_region_idx ON app.state (region_id);

CREATE TABLE app.district (
    id         uuid PRIMARY KEY DEFAULT uuidv7(),
    state_id   uuid NOT NULL REFERENCES app.state(id) ON DELETE RESTRICT,
    name       text NOT NULL,
    code       text NOT NULL DEFAULT '',
    sort       integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT district_parent_name_key UNIQUE (state_id, name)
);
CREATE INDEX district_state_idx ON app.district (state_id);

CREATE TABLE app.assembly (
    id          uuid PRIMARY KEY DEFAULT uuidv7(),
    district_id uuid NOT NULL REFERENCES app.district(id) ON DELETE RESTRICT,
    name        text NOT NULL,
    code        text NOT NULL DEFAULT '',   -- AC number, e.g. 'AC124'
    sort        integer NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    -- Keyed on `code`, not `name`: the official Suvida LSG source has a
    -- handful of rows where the same free-text name is paired with two
    -- different AC codes within one district (a data-entry inconsistency,
    -- not two constituencies sharing a name). `code` is the real, stable,
    -- government-assigned identifier, so it is the natural key here.
    CONSTRAINT assembly_parent_code_key UNIQUE (district_id, code)
);
CREATE INDEX assembly_district_idx ON app.assembly (district_id);

CREATE TABLE app.lsgd (
    id          uuid PRIMARY KEY DEFAULT uuidv7(),
    -- Nullable: a handful of large corporations (Kochi, Thrissur, Kozhikkode)
    -- genuinely span more than one assembly constituency, so there is no
    -- single correct value — the source data (Suvida LSG list) leaves the
    -- assembly blank for exactly these three rather than picking one
    -- arbitrarily. Every panchayat, municipality and smaller corporation
    -- still gets a real assembly_id.
    assembly_id uuid REFERENCES app.assembly(id) ON DELETE RESTRICT,
    type        app.lsgd_type NOT NULL,
    name        text NOT NULL,
    code        text NOT NULL DEFAULT '',
    sort        integer NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT lsgd_parent_name_key UNIQUE (assembly_id, name)
);
CREATE INDEX lsgd_assembly_idx ON app.lsgd (assembly_id);
CREATE INDEX lsgd_type_idx     ON app.lsgd (type);

CREATE TABLE app.ward (
    id          uuid PRIMARY KEY DEFAULT uuidv7(),
    lsgd_id     uuid NOT NULL REFERENCES app.lsgd(id) ON DELETE RESTRICT,
    ward_number integer NOT NULL,
    name        text NOT NULL DEFAULT '',
    code        text NOT NULL DEFAULT '',
    sort        integer NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ward_parent_number_key UNIQUE (lsgd_id, ward_number)
);
CREATE INDEX ward_lsgd_idx ON app.ward (lsgd_id);

-- ---- updated_at touch triggers ---------------------------------------
CREATE TRIGGER region_touch   BEFORE UPDATE ON app.region   FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER state_touch    BEFORE UPDATE ON app.state    FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER district_touch BEFORE UPDATE ON app.district FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER assembly_touch BEFORE UPDATE ON app.assembly FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER lsgd_touch     BEFORE UPDATE ON app.lsgd     FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER ward_touch     BEFORE UPDATE ON app.ward     FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

-- Sanity (all zero after this migration):
--   SELECT 'region' t, count(*) FROM app.region
--   UNION ALL SELECT 'state', count(*) FROM app.state
--   UNION ALL SELECT 'district', count(*) FROM app.district
--   UNION ALL SELECT 'assembly', count(*) FROM app.assembly
--   UNION ALL SELECT 'lsgd', count(*) FROM app.lsgd
--   UNION ALL SELECT 'ward', count(*) FROM app.ward;
