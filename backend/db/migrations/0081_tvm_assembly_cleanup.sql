-- ============================================================================
--  0081 · Thiruvananthapuram's 11 assemblies, cleaned up
-- ============================================================================
--  app.assembly under Thiruvananthapuram district had 12 rows for 11 real
--  assemblies: "Nedumangad" existed twice (AC130 and AC133), each with its
--  own real LSGDs underneath — AC130 had Nedumangad LSGD, AC133 had
--  Andoorkonam and Pothencode. Two more rows ("PARASSALA ", "KOVALAM ")
--  carried a trailing space, and casing was inconsistent (mostly ALL CAPS).
--  This merges the duplicate (keeping every LSGD, losing none — they move
--  to the surviving row), and normalises every name in the list to Title
--  Case, matching exactly what was asked for:
--    Aruvikkara, Attingal, Chirayinkeezhu, Kattakada, Kovalam, Nedumangad,
--    Neyyattinkara, Parassala, Thiruvananthapuram, Vamanapuram, Varkala
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0081_tvm_assembly_cleanup.sql --yes
-- ============================================================================

SET search_path TO app, public;

-- Merge the duplicate Nedumangad (AC133) into the original (AC130) before
-- deleting it, so its two LSGDs (Andoorkonam, Pothencode) keep a home.
UPDATE app.lsgd
   SET assembly_id = '01a089da-6638-79c7-9b08-047c817a37f4'
 WHERE assembly_id = '01a089da-5ff5-736d-997d-72f7538db6cd';

DELETE FROM app.assembly
 WHERE id = '01a089da-5ff5-736d-997d-72f7538db6cd'
   AND NOT EXISTS (SELECT 1 FROM app.lsgd WHERE assembly_id = '01a089da-5ff5-736d-997d-72f7538db6cd');

-- Normalise the remaining 11 to Title Case, trimmed.
UPDATE app.assembly SET name = 'Varkala'         WHERE id = '01a089da-6549-7ce5-9d8b-67ddacce5779' AND name <> 'Varkala';
UPDATE app.assembly SET name = 'Attingal'        WHERE id = '01a089da-6454-72b1-88c1-d9703103e817' AND name <> 'Attingal';
UPDATE app.assembly SET name = 'Chirayinkeezhu'  WHERE id = '01a089da-60e2-7693-b60e-312f982be40e' AND name <> 'Chirayinkeezhu';
UPDATE app.assembly SET name = 'Nedumangad'      WHERE id = '01a089da-6638-79c7-9b08-047c817a37f4' AND name <> 'Nedumangad';
UPDATE app.assembly SET name = 'Vamanapuram'     WHERE id = '01a089da-62cb-7458-8de6-f4c77b23f853' AND name <> 'Vamanapuram';
UPDATE app.assembly SET name = 'Thiruvananthapuram' WHERE id = '01a089da-5b18-717c-92a8-13c9f6e23c83' AND name <> 'Thiruvananthapuram';
UPDATE app.assembly SET name = 'Aruvikkara'      WHERE id = '01a089da-61cf-75ba-87a6-31475cb8a758' AND name <> 'Aruvikkara';
UPDATE app.assembly SET name = 'Parassala'       WHERE id = '01a089da-5c0c-7e3a-8889-b6322201d0b2' AND name <> 'Parassala';
UPDATE app.assembly SET name = 'Kovalam'         WHERE id = '01a089da-5df6-70b5-b950-1a9b29cf0f11' AND name <> 'Kovalam';
UPDATE app.assembly SET name = 'Kattakada'       WHERE id = '01a089da-5ef3-7c5a-a5d4-7c28edd86e11' AND name <> 'Kattakada';
UPDATE app.assembly SET name = 'Neyyattinkara'   WHERE id = '01a089da-5d05-7b35-92eb-67cfe5931b2f' AND name <> 'Neyyattinkara';
