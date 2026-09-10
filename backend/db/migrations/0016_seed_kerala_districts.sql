-- ============================================================================
--  0016 · Seed — Kerala's 14 districts
-- ============================================================================
--  Fills app.district (migration 0014) with every district of Kerala, each
--  linked to the Kerala row in app.state (seeded by migration 0015) through
--  `state_id`. Assemblies, LSGDs and wards under these districts are added
--  afterwards.
--
--  Requires 0015 to have run — if the Kerala state row is missing this file
--  inserts nothing (the JOIN finds no parent) and exits clean.
--
--  Order and numbering follow the Kerala government's official district list
--  (south to north). `code` is that two-digit number prefixed `KL-` — 'KL-01'
--  Thiruvananthapuram … 'KL-14' Kasaragod.
--
--  Each INSERT is guarded with NOT EXISTS, so re-running is harmless.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0016_seed_kerala_districts.sql --yes
-- ============================================================================

SET search_path TO app, public;

INSERT INTO app.district (state_id, name, code, sort)
SELECT s.id, v.name, v.code, v.ord
FROM (VALUES
  ('Thiruvananthapuram', 'KL-01',  1),
  ('Kollam',             'KL-02',  2),
  ('Pathanamthitta',     'KL-03',  3),
  ('Alappuzha',          'KL-04',  4),
  ('Kottayam',           'KL-05',  5),
  ('Idukki',             'KL-06',  6),
  ('Ernakulam',          'KL-07',  7),
  ('Thrissur',           'KL-08',  8),
  ('Palakkad',           'KL-09',  9),
  ('Malappuram',         'KL-10', 10),
  ('Kozhikode',          'KL-11', 11),
  ('Wayanad',            'KL-12', 12),
  ('Kannur',             'KL-13', 13),
  ('Kasaragod',          'KL-14', 14)
) AS v(name, code, ord)
JOIN app.state s ON s.name = 'Kerala' AND s.code = 'KL'
WHERE NOT EXISTS (
  SELECT 1 FROM app.district d WHERE d.state_id = s.id AND d.name = v.name
);

-- Expect: 14 rows under Kerala.
--   SELECT d.sort, d.code, d.name
--   FROM app.district d
--   JOIN app.state s ON s.id = d.state_id
--   WHERE s.name = 'Kerala'
--   ORDER BY d.sort;
