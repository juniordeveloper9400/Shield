-- ============================================================================
--  0015 · Seed — the 6 regions and every Indian state / UT
-- ============================================================================
--  Fills app.region (migration 0014) with the six zones and app.state with all
--  28 states + 8 union territories, each mapped to its zone. Districts,
--  assemblies, LSGDs and wards are added afterwards by hand.
--
--  Region -> state mapping follows the project's earlier seed (migration
--  0011). The four UTs 0011 omitted are placed here: Andaman & Nicobar,
--  Lakshadweep and Puducherry under South; Dadra & Nagar Haveli and Daman &
--  Diu under West. A few zone calls are conventional rather than strict
--  geography (Chhattisgarh -> West, Rajasthan -> North, Uttar Pradesh /
--  Uttarakhand -> Central) — move a row with a plain UPDATE if you prefer a
--  different grouping.
--
--  `code` is the ISO 3166-2:IN subdivision code (without the "IN-" prefix).
--  Each INSERT is guarded with NOT EXISTS, so re-running is harmless.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0015_seed_regions_states.sql --yes
-- ============================================================================

SET search_path TO app, public;

-- ---- the six regions --------------------------------------------------
INSERT INTO app.region (name, code, sort)
SELECT v.name, v.code, v.ord
FROM (VALUES
  ('North', 'N', 1),
  ('South', 'S', 2),
  ('East', 'E', 3),
  ('West', 'W', 4),
  ('Central', 'C', 5),
  ('Northeast', 'NE', 6)
) AS v(name, code, ord)
WHERE NOT EXISTS (SELECT 1 FROM app.region r WHERE r.name = v.name);

-- ---- states & union territories, mapped to their zone ---------------
INSERT INTO app.state (region_id, name, code, sort)
SELECT r.id, v.name, v.code, v.ord
FROM (VALUES
  -- North
  ('North', 'Chandigarh',                         'CH', 1),
  ('North', 'Delhi',                              'DL', 2),
  ('North', 'Haryana',                            'HR', 3),
  ('North', 'Himachal Pradesh',                   'HP', 4),
  ('North', 'Jammu & Kashmir',                    'JK', 5),
  ('North', 'Ladakh',                             'LA', 6),
  ('North', 'Punjab',                             'PB', 7),
  ('North', 'Rajasthan',                          'RJ', 8),
  -- South
  ('South', 'Andhra Pradesh',                     'AP', 1),
  ('South', 'Karnataka',                          'KA', 2),
  ('South', 'Kerala',                             'KL', 3),
  ('South', 'Tamil Nadu',                         'TN', 4),
  ('South', 'Telangana',                          'TG', 5),
  ('South', 'Andaman & Nicobar Islands',          'AN', 6),
  ('South', 'Lakshadweep',                        'LD', 7),
  ('South', 'Puducherry',                         'PY', 8),
  -- East
  ('East',  'Bihar',                              'BR', 1),
  ('East',  'Jharkhand',                          'JH', 2),
  ('East',  'Odisha',                             'OR', 3),
  ('East',  'West Bengal',                        'WB', 4),
  -- West
  ('West',  'Chhattisgarh',                       'CT', 1),
  ('West',  'Goa',                                'GA', 2),
  ('West',  'Gujarat',                            'GJ', 3),
  ('West',  'Maharashtra',                        'MH', 4),
  ('West',  'Dadra & Nagar Haveli and Daman & Diu', 'DH', 5),
  -- Central
  ('Central', 'Madhya Pradesh',                   'MP', 1),
  ('Central', 'Uttar Pradesh',                    'UP', 2),
  ('Central', 'Uttarakhand',                      'UT', 3),
  -- Northeast
  ('Northeast', 'Arunachal Pradesh',             'AR', 1),
  ('Northeast', 'Assam',                         'AS', 2),
  ('Northeast', 'Manipur',                       'MN', 3),
  ('Northeast', 'Meghalaya',                     'ML', 4),
  ('Northeast', 'Mizoram',                       'MZ', 5),
  ('Northeast', 'Nagaland',                      'NL', 6),
  ('Northeast', 'Sikkim',                        'SK', 7),
  ('Northeast', 'Tripura',                       'TR', 8)
) AS v(region, name, code, ord)
JOIN app.region r ON r.name = v.region
WHERE NOT EXISTS (
  SELECT 1 FROM app.state s WHERE s.region_id = r.id AND s.name = v.name
);

-- Expect: region 6, state 36 (28 states + 8 UTs).
--   SELECT r.name, count(s.id)
--   FROM app.region r LEFT JOIN app.state s ON s.region_id = r.id
--   GROUP BY r.name, r.sort ORDER BY r.sort;
