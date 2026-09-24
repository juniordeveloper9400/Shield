-- ============================================================================
--  0062 · Geo hierarchy — level-prefixed display codes (prefix_code)
-- ============================================================================
--  Adds a new `prefix_code` column to region/state/district/assembly/lsgd/ward.
--  The existing `code` column is untouched: it stays exactly what it always
--  was — the real, government-assigned Suvida LSG source code, relied on for
--  uniqueness and idempotent re-seeding (see 0014/0058/seed_kerala_geo.dart).
--  `prefix_code` is a separate, purely presentational, level-tagged code for
--  showing an agent's own position readably (product ask: agent cards should
--  show "<level prefix>, <code>, <member id>" for the agent's own tier only —
--  never the whole ancestor chain strung together).
--
--  There is no `national` row (region already carries `national_agent_id` —
--  India is implicit, see 0014's own header). The national tier's code is
--  the fixed constant 'NAT-INDIA-01', defined in application code
--  (backend/api's agent code generator and the Flutter apps' AgentDirectory),
--  not stored here.
--
--  Scheme (confirmed with the product owner over the sample codes given):
--    Region     REG-<3-letter zone abbr>-01      e.g. REG-SOU-01
--    State      STA-<3-letter state abbr>-01     e.g. STA-KER-01
--    District   DIS-<3-letter district abbr>-<sort>  e.g. DIS-TVM-01 ..
--               DIS-KSR-14 — corrected from a bare '<abbr>-<sort>' with no
--               level tag by migration 0063; the VALUES list below is left
--               as originally written for history, not fixed in place.
--    Assembly   ASS-<district abbr>-<official AC number, 3 digits>
--               e.g. ASS-TVM-134 — the real statewide AC number (1-140,
--               already stored as assembly.sort/assembly.code); the "141"
--               in the original ask doesn't match any real AC (max is 140,
--               confirmed live), so it's read as approximate, not literal.
--    LSGD       COR-<district abbr>-<code>   corporations (~1 per district)
--               MUN-<LSGD name>-<code>       municipalities (several/district;
--                                              not in the original ask —
--                                              inferred to match GP's own
--                                              pattern, since like GP there
--                                              can be many per district)
--               GP-<LSGD name>-<code>        grama panchayats (confirmed)
--    Ward       WRD-<ward name>-<code>       `code` already carries its
--                                              parent's own C/M/G letter, so
--                                              this needs no type-branching.
--
--  region/state/district are small and hand-curated below, the same style as
--  0015/0016's own seeds. assembly/lsgd/ward are computed from already-loaded
--  data via UPDATE — run this AFTER a seed_kerala_geo.dart pass that has left
--  every lsgd row with a real assembly_id (0058 + the assembly_id-refreshing
--  ON CONFLICT fix in seed_kerala_geo.dart must both be in place first, or
--  the three-corporations-with-no-assembly gap silently leaves their
--  prefix_code blank).
--
--  Re-runnable: every UPDATE recomputes from the same deterministic inputs.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0062_geo_prefix_codes.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.region   ADD COLUMN IF NOT EXISTS prefix_code text NOT NULL DEFAULT '';
ALTER TABLE app.state    ADD COLUMN IF NOT EXISTS prefix_code text NOT NULL DEFAULT '';
ALTER TABLE app.district ADD COLUMN IF NOT EXISTS prefix_code text NOT NULL DEFAULT '';
ALTER TABLE app.assembly ADD COLUMN IF NOT EXISTS prefix_code text NOT NULL DEFAULT '';
ALTER TABLE app.lsgd     ADD COLUMN IF NOT EXISTS prefix_code text NOT NULL DEFAULT '';
ALTER TABLE app.ward     ADD COLUMN IF NOT EXISTS prefix_code text NOT NULL DEFAULT '';

-- ---- region ----------------------------------------------------------
-- Matched by `code` (the fixed one-letter zone code, N/S/E/W/C/NE), not by
-- `name` — the live rows read "North India"/"South India"/… (0015's own
-- seed comment describes bare "North"/"South"/…, but that's not what's
-- actually live; `code` is unambiguous either way and never drifts).
UPDATE app.region SET prefix_code = 'REG-' || v.abbr || '-01'
FROM (VALUES
  ('N',  'NOR'),
  ('S',  'SOU'),
  ('E',  'EAS'),
  ('W',  'WEA'),
  ('C',  'CEN'),
  ('NE', 'NOREAS')
) AS v(code, abbr)
WHERE app.region.code = v.code;

-- ---- state (all 36; only Kerala has real geography below it today) ---
UPDATE app.state SET prefix_code = 'STA-' || v.abbr || '-01'
FROM (VALUES
  ('Chandigarh', 'CHD'), ('Delhi', 'DEL'), ('Haryana', 'HAR'),
  ('Himachal Pradesh', 'HIM'), ('Jammu & Kashmir', 'JAK'), ('Ladakh', 'LAD'),
  ('Punjab', 'PUN'), ('Rajasthan', 'RAJ'),
  ('Andhra Pradesh', 'APR'), ('Karnataka', 'KAR'), ('Kerala', 'KER'),
  ('Tamil Nadu', 'TAM'), ('Telangana', 'TEL'),
  ('Andaman & Nicobar Islands', 'AND'), ('Lakshadweep', 'LAK'), ('Puducherry', 'PUD'),
  ('Bihar', 'BIH'), ('Jharkhand', 'JHA'), ('Odisha', 'ODI'), ('West Bengal', 'WBE'),
  ('Chhattisgarh', 'CHH'), ('Goa', 'GOA'), ('Gujarat', 'GUJ'), ('Maharashtra', 'MAH'),
  ('Dadra & Nagar Haveli and Daman & Diu', 'DND'),
  ('Madhya Pradesh', 'MPR'), ('Uttar Pradesh', 'UPR'), ('Uttarakhand', 'UTK'),
  ('Arunachal Pradesh', 'ARU'), ('Assam', 'ASM'), ('Manipur', 'MAN'),
  ('Meghalaya', 'MEG'), ('Mizoram', 'MIZ'), ('Nagaland', 'NAG'),
  ('Sikkim', 'SIK'), ('Tripura', 'TRI')
) AS v(name, abbr)
WHERE app.state.name = v.name;

-- ---- district (Kerala's 14 — abbreviations match the user's own TVM/KSR
-- examples exactly) -----------------------------------------------------
UPDATE app.district SET prefix_code = v.abbr || '-' || lpad(app.district.sort::text, 2, '0')
FROM (VALUES
  ('Thiruvananthapuram', 'TVM'), ('Kollam', 'KLM'), ('Pathanamthitta', 'PTA'),
  ('Alappuzha', 'ALP'), ('Kottayam', 'KTM'), ('Idukki', 'IDK'),
  ('Ernakulam', 'EKM'), ('Thrissur', 'TSR'), ('Palakkad', 'PKD'),
  ('Malappuram', 'MPM'), ('Kozhikode', 'KKD'), ('Wayanad', 'WYD'),
  ('Kannur', 'KNR'), ('Kasaragod', 'KSR')
) AS v(name, abbr)
WHERE app.district.name = v.name;

-- ---- assembly: ASS-<district abbr>-<real official AC number, 3 digits> ----
UPDATE app.assembly a
SET prefix_code = 'ASS-' || split_part(d.prefix_code, '-', 1) || '-' || lpad(a.sort::text, 3, '0')
FROM app.district d
WHERE d.id = a.district_id;

-- ---- lsgd: COR-<district>-<code> / MUN-<name>-<code> / GP-<name>-<code> ---
-- Every row is expected to have a real assembly_id by the time this runs
-- (see the header note) — a row still NULL here (the seed step above was
-- skipped) is left at '' rather than guessed at, so it's obvious in a spot
-- check rather than silently wrong.
UPDATE app.lsgd l
SET prefix_code = CASE l.type
  WHEN 'corporation' THEN 'COR-' || split_part(d.prefix_code, '-', 1) || '-' || l.code
  WHEN 'municipality' THEN 'MUN-' || upper(l.name) || '-' || l.code
  ELSE 'GP-' || upper(l.name) || '-' || l.code
END
FROM app.assembly a
JOIN app.district d ON d.id = a.district_id
WHERE a.id = l.assembly_id;

-- ---- ward: WRD-<ward name>-<real ward code> ---------------------------
UPDATE app.ward w
SET prefix_code = 'WRD-' || upper(w.name) || '-' || w.code
WHERE w.code <> '';

-- Sanity — expect 0 blank rows for assembly/lsgd/ward once the seed step in
-- the header note has actually run (a blank lsgd/ward row means its parent
-- chain wasn't fully linked yet):
--   SELECT 'region' t, count(*) FILTER (WHERE prefix_code = '') FROM app.region
--   UNION ALL SELECT 'state', count(*) FILTER (WHERE prefix_code = '') FROM app.state
--   UNION ALL SELECT 'district', count(*) FILTER (WHERE prefix_code = '') FROM app.district
--   UNION ALL SELECT 'assembly', count(*) FILTER (WHERE prefix_code = '') FROM app.assembly
--   UNION ALL SELECT 'lsgd', count(*) FILTER (WHERE prefix_code = '') FROM app.lsgd
--   UNION ALL SELECT 'ward', count(*) FILTER (WHERE prefix_code = '') FROM app.ward;
