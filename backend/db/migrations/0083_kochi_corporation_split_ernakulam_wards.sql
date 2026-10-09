-- ============================================================================
--  0083 · Kochi Corporation split: a second entry under Ernakulam assembly
-- ============================================================================
--  Kochi Corporation genuinely spans two assemblies — Kochi and Ernakulam —
--  which the Suvida file doesn't record (it leaves the corporation's
--  assembly blank entirely). Migration 0082 moved the whole corporation
--  under Ernakulam as a first pass; this replaces that with an actual
--  split, per the user's explicit instruction: two separate "Kochi"
--  corporation rows, one per assembly, each holding only its own wards.
--
--  This migration:
--    1. Moves the original corporation row back under the Kochi assembly
--       (where migration 0082 found it before).
--    2. Creates a new "Kochi" corporation row under the Ernakulam assembly.
--    3. Moves 44 specific wards (given by the user, ward numbers 1-8,
--       9-16, 18-28, 51-54, 64-76) from the original row onto the new one.
--
--  NOT yet covered — the remaining 32 wards (ward 17, 29-50, 55-63) stay
--  on the original (Kochi-assembly) row for now. The user said they will
--  send the Kochi-assembly-side ward list separately; until then, those 32
--  wards simply remain where they already were, not reassigned.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0083_kochi_corporation_split_ernakulam_wards.sql --yes
-- ============================================================================

SET search_path TO app, public;

DO $$
DECLARE
    v_kochi_assembly_id     uuid := '01a089da-97f5-792a-b1a6-5cc940235e73';
    v_ernakulam_assembly_id uuid := '01a089da-970b-7675-8d35-16c2be20bf96';
    v_original_lsgd_id      uuid := '01a089dc-8063-7c30-abc1-d1d2ed3e81c2';
    v_new_lsgd_id           uuid;
    v_ward_numbers          integer[] := ARRAY[
        1,2,3,4,5,6,7,8,
        9,10,11,12,13,14,15,16,
        18,19,20,21,22,23,24,25,26,27,28,
        51,52,53,54,
        64,65,66,67,68,69,70,71,72,73,74,75,76
    ];
BEGIN
    -- 1. Original row back under Kochi assembly.
    UPDATE app.lsgd SET assembly_id = v_kochi_assembly_id
     WHERE id = v_original_lsgd_id AND assembly_id <> v_kochi_assembly_id;

    -- 2. The new split row under Ernakulam, created once (idempotent on code).
    SELECT id INTO v_new_lsgd_id FROM app.lsgd WHERE code = 'C07003-EKM';
    IF v_new_lsgd_id IS NULL THEN
        INSERT INTO app.lsgd (id, assembly_id, type, name, code, sort)
        VALUES (gen_random_uuid(), v_ernakulam_assembly_id, 'corporation', 'Kochi', 'C07003-EKM', 0)
        RETURNING id INTO v_new_lsgd_id;
    END IF;

    -- 3. Move the 44 specified wards onto the new row.
    UPDATE app.ward
       SET lsgd_id = v_new_lsgd_id
     WHERE lsgd_id = v_original_lsgd_id
       AND ward_number = ANY(v_ward_numbers);
END $$;
