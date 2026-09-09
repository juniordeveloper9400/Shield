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
--  One self-referential table, `id bigint GENERATED ALWAYS AS IDENTITY` like
--  every other app.* table. `parent_id` is NULL only for the six regions;
--  ON DELETE CASCADE means dropping a district takes its assemblies, LSGDs and
--  wards with it. `code` is the printed tag a slot carries (AC136, TVC,
--  AC136-L1, AC136-L1-W005) — empty for the tiers that have no code (region,
--  state, district). Adding a row: set `parent_id` to the parent's numeric id,
--  `level`, `name`; `id` fills itself in.
--
--  Seeded shape (generated — real names can be edited in afterwards):
--    · 6 regions, their states (Kerala among South's five)
--    · Kerala's 14 districts
--    · Thiruvananthapuram's 13 assembly segments + the city corporation, coded
--    · Varkala → its 6 grama panchayats + Varkala Municipality; the corporation
--      segment → its one municipal-corporation LSGD; every other segment → 3
--      generic "<name> Panchayat n" LSGDs
--    · Varkala Municipality → its 34 named wards; the corporation LSGD → 100
--      wards; every panchayat LSGD → 12 wards
--
--  Each INSERT is guarded with NOT EXISTS, so re-running just the seed part is
--  harmless. Running the whole file DROPs and rebuilds the table — do that
--  only before any admin edits have been made.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0011_agent_geo_hierarchy.sql --yes
-- ============================================================================

SET search_path TO app, public;

-- The first cut of this table used a text slug id; replace it.
DROP TABLE IF EXISTS app.agent_geo_node CASCADE;
DROP FUNCTION IF EXISTS app._geo_slug(text);

CREATE TABLE app.agent_geo_node (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid       uuid NOT NULL DEFAULT gen_random_uuid(),
    parent_id  bigint REFERENCES app.agent_geo_node(id) ON DELETE CASCADE,
    level      text NOT NULL
      CHECK (level IN ('region','state','district','assembly','lsgd','ward')),
    name       text NOT NULL,
    code       text NOT NULL DEFAULT '',
    sort       integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX agent_geo_node_parent_idx ON app.agent_geo_node(parent_id);

-- A slot name is unique within its parent — the app matches a registered
-- agent to a slot by (parent, name). COALESCE folds the six NULL-parent
-- regions into one bucket.
CREATE UNIQUE INDEX agent_geo_node_parent_name_idx
  ON app.agent_geo_node(COALESCE(parent_id, 0), name);

CREATE TRIGGER agent_geo_node_touch BEFORE UPDATE ON app.agent_geo_node
  FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

-- ---- regions -----------------------------------------------------------
INSERT INTO app.agent_geo_node (parent_id, level, name, code, sort)
SELECT NULL, 'region', v.name, '', v.ord
FROM (VALUES
  ('North', 1), ('South', 2), ('East', 3),
  ('West', 4), ('Central', 5), ('Northeast', 6)
) AS v(name, ord)
WHERE NOT EXISTS (
  SELECT 1 FROM app.agent_geo_node g
  WHERE g.level = 'region' AND g.name = v.name
);

-- ---- states ----------------------------------------------------------
INSERT INTO app.agent_geo_node (parent_id, level, name, code, sort)
SELECT p.id, 'state', v.name, '', v.ord
FROM (VALUES
  ('North', 'Chandigarh', 1), ('North', 'Delhi', 2), ('North', 'Haryana', 3),
  ('North', 'Himachal Pradesh', 4), ('North', 'Jammu & Kashmir', 5),
  ('North', 'Ladakh', 6), ('North', 'Punjab', 7), ('North', 'Rajasthan', 8),
  ('South', 'Andhra Pradesh', 1), ('South', 'Karnataka', 2),
  ('South', 'Kerala', 3), ('South', 'Tamil Nadu', 4), ('South', 'Telangana', 5),
  ('East', 'Bihar', 1), ('East', 'Jharkhand', 2), ('East', 'Odisha', 3),
  ('East', 'West Bengal', 4),
  ('West', 'Chhattisgarh', 1), ('West', 'Goa', 2), ('West', 'Gujarat', 3),
  ('West', 'Maharashtra', 4),
  ('Central', 'Madhya Pradesh', 1), ('Central', 'Uttar Pradesh', 2),
  ('Central', 'Uttarakhand', 3),
  ('Northeast', 'Arunachal Pradesh', 1), ('Northeast', 'Assam', 2),
  ('Northeast', 'Manipur', 3), ('Northeast', 'Meghalaya', 4),
  ('Northeast', 'Mizoram', 5), ('Northeast', 'Nagaland', 6),
  ('Northeast', 'Sikkim', 7), ('Northeast', 'Tripura', 8)
) AS v(region, name, ord)
JOIN app.agent_geo_node p ON p.level = 'region' AND p.name = v.region
WHERE NOT EXISTS (
  SELECT 1 FROM app.agent_geo_node g
  WHERE g.parent_id = p.id AND g.name = v.name
);

-- ---- Kerala's districts --------------------------------------------------
INSERT INTO app.agent_geo_node (parent_id, level, name, code, sort)
SELECT p.id, 'district', v.name, '', v.ord
FROM (VALUES
  ('Thiruvananthapuram', 1), ('Kollam', 2), ('Pathanamthitta', 3),
  ('Alappuzha', 4), ('Kottayam', 5), ('Idukki', 6), ('Ernakulam', 7),
  ('Thrissur', 8), ('Palakkad', 9), ('Malappuram', 10), ('Kozhikode', 11),
  ('Wayanad', 12), ('Kannur', 13), ('Kasaragod', 14)
) AS v(name, ord)
JOIN app.agent_geo_node p ON p.level = 'state' AND p.name = 'Kerala'
WHERE NOT EXISTS (
  SELECT 1 FROM app.agent_geo_node g
  WHERE g.parent_id = p.id AND g.name = v.name
);

-- ---- Thiruvananthapuram's assembly segments (13) + the corporation -----
INSERT INTO app.agent_geo_node (parent_id, level, name, code, sort)
SELECT p.id, 'assembly', v.name, v.code, v.ord
FROM (VALUES
  ('Varkala', 'AC124', 1), ('Attingal', 'AC125', 2),
  ('Chirayinkeezhu', 'AC126', 3), ('Nedumangad', 'AC127', 4),
  ('Vamanapuram', 'AC128', 5), ('Kazhakkoottam', 'AC129', 6),
  ('Vattiyoorkavu', 'AC130', 7), ('Nemom', 'AC132', 8),
  ('Aruvikkara', 'AC133', 9), ('Parassala', 'AC134', 10),
  ('Kattakkada', 'AC135', 11), ('Kovalam', 'AC136', 12),
  ('Neyyattinkara', 'AC137', 13),
  ('Thiruvananthapuram Corporation', 'TVC', 14)
) AS v(name, code, ord)
JOIN app.agent_geo_node p ON p.level = 'district' AND p.name = 'Thiruvananthapuram'
WHERE NOT EXISTS (
  SELECT 1 FROM app.agent_geo_node g
  WHERE g.parent_id = p.id AND g.name = v.name
);

-- ---- LSGDs: Varkala's six grama panchayats + Varkala Municipality -------
INSERT INTO app.agent_geo_node (parent_id, level, name, code, sort)
SELECT p.id, 'lsgd', v.name, 'AC124-L' || v.ord, v.ord
FROM (VALUES
  ('Chemmaruthy', 1), ('Edava', 2), ('Elakamon', 3), ('Madavoor', 4),
  ('Pallickal', 5), ('Vettoor', 6), ('Varkala Municipality', 7)
) AS v(name, ord)
JOIN app.agent_geo_node p ON p.level = 'assembly' AND p.name = 'Varkala'
WHERE NOT EXISTS (
  SELECT 1 FROM app.agent_geo_node g
  WHERE g.parent_id = p.id AND g.name = v.name
);

-- ---- LSGDs: 3 generic panchayats for every other assembly segment ------
INSERT INTO app.agent_geo_node (parent_id, level, name, code, sort)
SELECT a.id, 'lsgd',
       a.name || ' Panchayat ' || g.n,
       a.code || '-L' || g.n,
       g.n
FROM app.agent_geo_node a
CROSS JOIN generate_series(1, 3) AS g(n)
WHERE a.level = 'assembly' AND a.code NOT IN ('AC124', 'TVC')
  AND NOT EXISTS (
    SELECT 1 FROM app.agent_geo_node x
    WHERE x.parent_id = a.id AND x.name = a.name || ' Panchayat ' || g.n
  );

-- ---- LSGD: the corporation's single local body ------------------------
INSERT INTO app.agent_geo_node (parent_id, level, name, code, sort)
SELECT a.id, 'lsgd', 'Thiruvananthapuram Municipal Corporation', 'TVC-L1', 1
FROM app.agent_geo_node a
WHERE a.level = 'assembly' AND a.code = 'TVC'
  AND NOT EXISTS (SELECT 1 FROM app.agent_geo_node x WHERE x.parent_id = a.id);

-- ---- wards: Varkala Municipality's 34 named divisions ------------------
INSERT INTO app.agent_geo_node (parent_id, level, name, code, sort)
SELECT l.id, 'ward', v.name,
       'AC124-L7-W' || lpad(v.ord::text, 3, '0'), v.ord
FROM (VALUES
  ('Vilakkulam', 1), ('Idapparambu', 2), ('Janathamukku', 3),
  ('Karunilakode', 4), ('Kallazhi', 5), ('Pullannikode', 6),
  ('Ayanikkuzhivila', 7), ('Kannamba', 8), ('Nadayara', 9),
  ('Kanwasramam', 10), ('Chaluvila', 11), ('Kallamkonam', 12),
  ('Cherukunnam', 13), ('Sivagiri', 14), ('Teachers Colony', 15),
  ('Raghunathapuram', 16), ('Puthenchantha', 17), ('Thachankonam', 18),
  ('Ramanthali', 19), ('Panayil', 20), ('Vallakkadavu', 21),
  ('Perumkulam', 22), ('Kottumoola', 23), ('Maithanam', 24),
  ('Municipal Office', 25), ('Hospital', 26), ('Temple', 27),
  ('Janardhanapuram / Papanasam', 28), ('Parayil / Mundayil', 29),
  ('Jawahar Park', 30), ('Punnamoodu', 31), ('Parayil', 32),
  ('Papanasam', 33), ('Kurakkanni', 34)
) AS v(name, ord)
JOIN app.agent_geo_node l ON l.level = 'lsgd' AND l.name = 'Varkala Municipality'
WHERE NOT EXISTS (
  SELECT 1 FROM app.agent_geo_node g
  WHERE g.parent_id = l.id AND g.name = v.name
);

-- ---- wards: 12 per panchayat LSGD -----------------------------------
INSERT INTO app.agent_geo_node (parent_id, level, name, code, sort)
SELECT l.id, 'ward',
       l.name || ' Ward ' || lpad(g.n::text, 2, '0'),
       l.code || '-W' || lpad(g.n::text, 3, '0'),
       g.n
FROM app.agent_geo_node l
CROSS JOIN generate_series(1, 12) AS g(n)
WHERE l.level = 'lsgd' AND l.code NOT IN ('AC124-L7', 'TVC-L1')
  AND NOT EXISTS (
    SELECT 1 FROM app.agent_geo_node x
    WHERE x.parent_id = l.id
      AND x.name = l.name || ' Ward ' || lpad(g.n::text, 2, '0')
  );

-- ---- wards: 100 for the corporation LSGD ---------------------------
INSERT INTO app.agent_geo_node (parent_id, level, name, code, sort)
SELECT l.id, 'ward',
       l.name || ' Ward ' || lpad(g.n::text, 2, '0'),
       l.code || '-W' || lpad(g.n::text, 3, '0'),
       g.n
FROM app.agent_geo_node l
CROSS JOIN generate_series(1, 100) AS g(n)
WHERE l.level = 'lsgd' AND l.code = 'TVC-L1'
  AND NOT EXISTS (
    SELECT 1 FROM app.agent_geo_node x
    WHERE x.parent_id = l.id
      AND x.name = l.name || ' Ward ' || lpad(g.n::text, 2, '0')
  );

-- Sanity check — expect region 6, state 34, district 14, assembly 14,
-- lsgd 44, ward 638.
-- SELECT level, count(*) FROM app.agent_geo_node
--   GROUP BY level
--   ORDER BY array_position(
--     ARRAY['region','state','district','assembly','lsgd','ward'], level);
