-- ============================================================================
--  0084 · Kochi Corporation split, rebalanced
-- ============================================================================
--  Migration 0083's first-pass split put wards 1-8 and 64-76 on the
--  Ernakulam-side row. The user corrected this: those 21 wards (Fort
--  Kochi, Mattanchery, Palluruthy, Thoppumpady and the rest of the
--  southern peninsula) belong on the Kochi-assembly row instead. This
--  moves them there.
--
--  After this:
--    - Ernakulam assembly's "Kochi" corporation (C07003-EKM) holds exactly
--      23 wards: 9-16, 18-28, 51-54.
--    - Kochi assembly's "Kochi" corporation (C07003) holds the other 53:
--      its original 32 (17, 29-50, 55-63) plus these 21 (1-8, 64-76).
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0084_kochi_corporation_rebalance_split.sql --yes
-- ============================================================================

SET search_path TO app, public;

DO $$
DECLARE
    v_ernakulam_lsgd_id uuid;
    v_kochi_lsgd_id     uuid := '01a089dc-8063-7c30-abc1-d1d2ed3e81c2'; -- code C07003
    v_ward_numbers      integer[] := ARRAY[1,2,3,4,5,6,7,8,64,65,66,67,68,69,70,71,72,73,74,75,76];
BEGIN
    SELECT id INTO v_ernakulam_lsgd_id FROM app.lsgd WHERE code = 'C07003-EKM';
    IF v_ernakulam_lsgd_id IS NULL THEN
        RAISE EXCEPTION 'Ernakulam-side Kochi corporation row (C07003-EKM) not found — run migration 0083 first';
    END IF;

    UPDATE app.ward
       SET lsgd_id = v_kochi_lsgd_id
     WHERE lsgd_id = v_ernakulam_lsgd_id
       AND ward_number = ANY(v_ward_numbers);
END $$;
