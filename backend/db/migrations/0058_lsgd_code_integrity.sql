-- ============================================================================
--  0058 · Geo hierarchy — enforce real LSGD/ward codes, backfill LSGD sort
-- ============================================================================
--  Two gaps found auditing the Suvida LSG source against migration 0014's
--  tables (region -> state -> district -> assembly -> lsgd -> ward):
--
--  1. `lsgd.code` and `ward.code` hold the real, government-assigned codes
--     from the source ('C01001', 'C01001001', ...) but nothing enforced
--     their uniqueness — `lsgd`'s own unique key is (assembly_id, name), and
--     the three no-assembly corporations (Kochi, Thrissur, Kozhikkode;
--     assembly_id NULL) don't even get that protection, since Postgres
--     treats every NULL as distinct. Add partial unique indexes on the code
--     columns themselves (partial so the '' default used by any row without
--     a source code doesn't collide).
--
--  2. `backend/db/seed_kerala_geo.dart`'s original lsgd INSERT never set
--     `sort`, so every LSGD landed at the column default (0) regardless of
--     its real position in the source. The script now derives `sort` from
--     the code's own trailing digits ('C01001' -> 1001); this backfills
--     that value for any lsgd rows already loaded before that fix, using
--     the same rule, so a re-run of the seed script and this migration agree.
--
--  Safe to re-run: the indexes use IF NOT EXISTS, and the backfill only
--  touches rows still sitting at the old sort = 0 default.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0058_lsgd_code_integrity.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE UNIQUE INDEX IF NOT EXISTS lsgd_code_key ON app.lsgd (code) WHERE code <> '';
CREATE UNIQUE INDEX IF NOT EXISTS ward_code_key ON app.ward (code) WHERE code <> '';

UPDATE app.lsgd
SET sort = substring(code FROM '\d+$')::integer
WHERE sort = 0
  AND code ~ '\d+$';

-- Expect after a seed run: 0 rows left at sort = 0 with a numeric-suffixed code.
--   SELECT count(*) FROM app.lsgd WHERE sort = 0 AND code ~ '\d+$';
