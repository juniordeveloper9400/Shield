-- ============================================================================
--  0007 · Coordinates on app.shield_store
-- ============================================================================
--  Registration and privilege-plan activation rank the branches by real
--  distance (haversine) so the nearest one is pre-selected, and the branch map
--  drops a red pin per store. When a branch has no coordinates the app falls
--  back to pincode-prefix ranking, so this is safe to roll out one branch at a
--  time — and an admin adds new branches (with coordinates) straight into
--  app.shield_store from the console.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0007_shield_store_coords.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.shield_store
  ADD COLUMN IF NOT EXISTS latitude  numeric(9,6),
  ADD COLUMN IF NOT EXISTS longitude numeric(9,6);

-- Approximate town-centre coordinates for the seeded branches — good enough to
-- rank branches 5–40 km apart. Only fills a row that has no coordinates yet.
UPDATE app.shield_store s SET latitude = v.lat, longitude = v.lng
FROM (VALUES
  ('SHD-MEL', 10.988000, 76.216000),
  ('SHD-MKP', 10.944000, 76.101000),
  ('SHD-TIR', 10.913800, 75.921800),
  ('SHD-KKT', 10.970000, 76.245000),
  ('SHD-MJR', 11.120000, 76.119000),
  ('SHD-ALN', 10.976000, 76.523000),
  ('SHD-TRD', 11.042000, 75.928000),
  ('SHD-KNP', 10.993000, 76.080000),
  ('SHD-KND', 11.139000, 75.964000),
  ('SHD-ARK', 11.205000, 76.008000)
) AS v(code, lat, lng)
WHERE s.code = v.code AND s.latitude IS NULL;
