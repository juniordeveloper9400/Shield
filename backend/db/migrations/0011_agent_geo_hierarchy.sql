-- ============================================================================
--  0011 · Agent geographic hierarchy, DB-driven
-- ============================================================================
--  "My Team" in the app draws its slot tree — region → state → district →
--  assembly → lsgd → ward — off a fixed shape that used to live hard-coded in
--  the Flutter build (lib/module/agent/agent_geo.dart). This table moves that
--  shape into Neon so the pharmacy admin can add / rename / delete a ward, an
--  LSGD or a whole district and have the app pick it up on the next open,
--  without a rebuild. The app keeps a bundled copy of this same seed as an
--  offline / test fallback; whatever is in this table wins when it can be
--  reached.
--
--  One self-referential table. `parent_id` is NULL only for the six regions;
--  ON DELETE CASCADE means dropping a district takes its assemblies, LSGDs and
--  wards with it. `code` is the printed tag a slot carries (AC136, TVC,
--  AC136-L1, AC136-L1-W005) — empty for the tiers that have no code (region,
--  state, district).
--
--  Seeded shape (all generated — real ward names can be edited in afterwards):
--    · 6 regions, their states (Kerala among South's five)
--    · Kerala's 14 districts
--    · Thiruvananthapuram's 13 assembly segments + the city corporation, coded
--    · every assembly segment → 3 panchayat LSGDs; the corporation segment →
--      the one "Thiruvananthapuram Municipal Corporation" LSGD
--    · every panchayat LSGD → 12 wards; the corporation LSGD → 100 wards
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0011_agent_geo_hierarchy.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.agent_geo_node (
    id         text PRIMARY KEY,
    parent_id  text REFERENCES app.agent_geo_node(id) ON DELETE CASCADE,
    level      text NOT NULL
      CHECK (level IN ('region','state','district','assembly','lsgd','ward')),
    name       text NOT NULL,
    code       text NOT NULL DEFAULT '',
    sort       integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS agent_geo_node_parent_idx
  ON app.agent_geo_node(parent_id);

-- A slot name is unique within its parent — the app matches a registered
-- agent to a slot by (parent, name), so two "Kovalam"s under one district
-- would be ambiguous.
CREATE UNIQUE INDEX IF NOT EXISTS agent_geo_node_parent_name_idx
  ON app.agent_geo_node(COALESCE(parent_id, ''), name);

-- Small internal helper: a name → id-slug ("Kovalam Panchayat 1" → the
-- "kovalam-panchayat-1" tail of its node id).
CREATE OR REPLACE FUNCTION app._geo_slug(t text) RETURNS text AS $fn$
  SELECT lower(regexp_replace(trim(t), '[^a-zA-Z0-9]+', '-', 'g'));
$fn$ LANGUAGE sql IMMUTABLE;

DO $seed$
DECLARE
  regions       text[] := ARRAY[
    'North','South','East','West','Central','Northeast'
  ];
  states        jsonb  := '{
    "North":["Chandigarh","Delhi","Haryana","Himachal Pradesh","Jammu & Kashmir","Ladakh","Punjab","Rajasthan"],
    "South":["Andhra Pradesh","Karnataka","Kerala","Tamil Nadu","Telangana"],
    "East":["Bihar","Jharkhand","Odisha","West Bengal"],
    "West":["Chhattisgarh","Goa","Gujarat","Maharashtra"],
    "Central":["Madhya Pradesh","Uttar Pradesh","Uttarakhand"],
    "Northeast":["Arunachal Pradesh","Assam","Manipur","Meghalaya","Mizoram","Nagaland","Sikkim","Tripura"]
  }'::jsonb;
  kerala_districts text[] := ARRAY[
    'Thiruvananthapuram','Kollam','Pathanamthitta','Alappuzha','Kottayam',
    'Idukki','Ernakulam','Thrissur','Palakkad','Malappuram','Kozhikode',
    'Wayanad','Kannur','Kasaragod'
  ];
  tvm_assemblies jsonb := '[
    ["Varkala","AC124"],["Attingal","AC125"],["Chirayinkeezhu","AC126"],
    ["Nedumangad","AC127"],["Vamanapuram","AC128"],["Kazhakkoottam","AC129"],
    ["Vattiyoorkavu","AC130"],["Nemom","AC132"],["Aruvikkara","AC133"],
    ["Parassala","AC134"],["Kattakkada","AC135"],["Kovalam","AC136"],
    ["Neyyattinkara","AC137"],["Thiruvananthapuram Corporation","TVC"]
  ]'::jsonb;

  v_region      text;
  v_state       text;
  v_district    text;
  v_assembly    jsonb;
  v_aname       text;
  v_acode       text;
  v_lsgd        text;
  v_lcode       text;
  v_region_id   text;
  v_state_id    text;
  v_district_id text;
  v_assembly_id text;
  v_lsgd_id     text;
  r_sort int; s_sort int; d_sort int; a_sort int; l_sort int;
  n_lsgd int; n_ward int; i int; w int;
BEGIN
  r_sort := 0;
  FOREACH v_region IN ARRAY regions LOOP
    r_sort := r_sort + 1;
    v_region_id := 'geo/' || app._geo_slug(v_region);
    INSERT INTO app.agent_geo_node (id, parent_id, level, name, code, sort)
      VALUES (v_region_id, NULL, 'region', v_region, '', r_sort)
      ON CONFLICT (id) DO NOTHING;

    s_sort := 0;
    FOR v_state IN SELECT jsonb_array_elements_text(states -> v_region) LOOP
      s_sort := s_sort + 1;
      v_state_id := v_region_id || '/' || app._geo_slug(v_state);
      INSERT INTO app.agent_geo_node (id, parent_id, level, name, code, sort)
        VALUES (v_state_id, v_region_id, 'state', v_state, '', s_sort)
        ON CONFLICT (id) DO NOTHING;

      CONTINUE WHEN v_state <> 'Kerala';

      d_sort := 0;
      FOREACH v_district IN ARRAY kerala_districts LOOP
        d_sort := d_sort + 1;
        v_district_id := v_state_id || '/' || app._geo_slug(v_district);
        INSERT INTO app.agent_geo_node (id, parent_id, level, name, code, sort)
          VALUES (v_district_id, v_state_id, 'district', v_district, '', d_sort)
          ON CONFLICT (id) DO NOTHING;

        CONTINUE WHEN v_district <> 'Thiruvananthapuram';

        a_sort := 0;
        FOR v_assembly IN SELECT jsonb_array_elements(tvm_assemblies) LOOP
          a_sort := a_sort + 1;
          v_aname := v_assembly ->> 0;
          v_acode := v_assembly ->> 1;
          v_assembly_id := v_district_id || '/' || app._geo_slug(v_aname);
          INSERT INTO app.agent_geo_node (id, parent_id, level, name, code, sort)
            VALUES (v_assembly_id, v_district_id, 'assembly', v_aname, v_acode, a_sort)
            ON CONFLICT (id) DO NOTHING;

          IF v_acode = 'TVC' THEN
            n_lsgd := 1;
          ELSE
            n_lsgd := 3;
          END IF;

          l_sort := 0;
          FOR i IN 1..n_lsgd LOOP
            l_sort := l_sort + 1;
            IF v_acode = 'TVC' THEN
              v_lsgd  := 'Thiruvananthapuram Municipal Corporation';
              v_lcode := 'TVC-L1';
              n_ward  := 100;
            ELSE
              v_lsgd  := v_aname || ' Panchayat ' || i;
              v_lcode := v_acode || '-L' || i;
              n_ward  := 12;
            END IF;
            v_lsgd_id := v_assembly_id || '/' || app._geo_slug(v_lsgd);
            INSERT INTO app.agent_geo_node (id, parent_id, level, name, code, sort)
              VALUES (v_lsgd_id, v_assembly_id, 'lsgd', v_lsgd, v_lcode, l_sort)
              ON CONFLICT (id) DO NOTHING;

            FOR w IN 1..n_ward LOOP
              INSERT INTO app.agent_geo_node (id, parent_id, level, name, code, sort)
                VALUES (
                  v_lsgd_id || '/ward-' || lpad(w::text, 3, '0'),
                  v_lsgd_id,
                  'ward',
                  v_lsgd || ' Ward ' || lpad(w::text, 2, '0'),
                  v_lcode || '-W' || lpad(w::text, 3, '0'),
                  w
                )
                ON CONFLICT (id) DO NOTHING;
            END LOOP;
          END LOOP;
        END LOOP;
      END LOOP;
    END LOOP;
  END LOOP;
END
$seed$;
