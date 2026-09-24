-- ============================================================================
--  0063 · District prefix_code gets its own 'DIS-' tag
-- ============================================================================
--  0062 gave district a bare '<3-letter district abbr>-<sort>' prefix_code
--  ('TVM-01' .. 'KSR-14') — every other tier in that scheme carries its own
--  level tag (REG-, STA-, ASS-, COR-/MUN-/GP-, WRD-) except this one.
--  Corrected here to match: 'DIS-TVM-01' .. 'DIS-KSR-14'.
--
--  Nothing reads district.prefix_code's exact shape anywhere in the app —
--  backend/api's geo.service.ts, shieldweb's geo.ts/agents.ts, and
--  shield agent_invester's agent_geo(_repository).dart/
--  agent_team_tree_screen.dart all just pass the string straight through —
--  so this is a pure data correction with no code change needed alongside
--  it. Idempotent: only touches rows that don't already start with 'DIS-'.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0063_district_prefix_dis.sql --yes
-- ============================================================================

SET search_path TO app, public;

UPDATE app.district
SET prefix_code = 'DIS-' || prefix_code
WHERE prefix_code <> '' AND prefix_code NOT LIKE 'DIS-%';

-- Expect after this: every district's prefix_code starts with 'DIS-'.
--   SELECT name, prefix_code FROM app.district ORDER BY sort;
