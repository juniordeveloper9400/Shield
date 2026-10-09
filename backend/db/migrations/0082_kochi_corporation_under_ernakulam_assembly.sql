-- ============================================================================
--  0082 · Kochi Corporation moves under the Ernakulam assembly
-- ============================================================================
--  Kochi Corporation had been placed under the "Kochi" assembly (AC80),
--  alongside its two panchayats (Chellanam, Kumbalanghy). The Suvida LSG
--  file leaves Kochi Corporation's assembly blank — it genuinely spans
--  several assemblies in real life — so that placement was a judgment
--  call, not something the file dictated. Decided now: it belongs under
--  the "Ernakulam" assembly (AC82), alongside Cheranallur grama panchayat,
--  which until now was the assembly's only LSG.
--
--  After this: "Kochi" assembly (AC80) holds only Chellanam and
--  Kumbalanghy, matching the file exactly. "Ernakulam" assembly (AC82)
--  holds Kochi Corporation and Cheranallur.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0082_kochi_corporation_under_ernakulam_assembly.sql --yes
-- ============================================================================

SET search_path TO app, public;

UPDATE app.lsgd
   SET assembly_id = '01a089da-970b-7675-8d35-16c2be20bf96' -- Ernakulam assembly
 WHERE id = '01a089dc-8063-7c30-abc1-d1d2ed3e81c2' -- Kochi corporation
   AND assembly_id <> '01a089da-970b-7675-8d35-16c2be20bf96';
