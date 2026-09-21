-- ============================================================================
--  0052 · Referral flow: an invite code for every member, and "transacted" the
--         moment a referred member's order is paid -- wherever it is paid.
-- ============================================================================
--  Two gaps kept a referrer's Refer & Earn screen from ever moving.
--
--  1. A referral only advances REGISTERED -> TRANSACTED when the referred
--     member's first paid order is placed *through the app or backend
--     checkout*. Orders paid later -- cash collected at the counter, a bill
--     collected from the wallet, a delivery's cash marked collected -- are
--     written by the admin console straight to app."order".payment_status
--     and never advanced anything. Those referrals sat at REGISTERED forever,
--     so the referrer never crossed a level.
--
--     A trigger on app."order" now advances the referral (and pays the level
--     points through app.award_referral_level_points, migration 0043) the
--     instant an order's payment_status becomes PAID, from any writer. The
--     app/backend checkout code that does the same is unchanged and harmless:
--     the update only ever moves a referral forward from REGISTERED.
--
--  2. app.users.referral_code -- the Member ID / invite code -- was filled in
--     lazily, the first time some screen asked for it. A member whose screen
--     never got that far (or whose row was created by another path) had no
--     code at all, and the app showed a placeholder that looked real. A
--     BEFORE INSERT trigger now assigns one when the row is created, and the
--     members who already have none get one here.
--
--  Also backfills: any referral still REGISTERED whose invitee already has a
--  paid order is advanced now, and the referrers' levels re-checked.
--
--  Idempotent. Needs 0043 (app.award_referral_level_points).
--    dart run backend/db/apply_migration.dart backend/db/migrations/0052_referral_flow_triggers.sql --yes
-- ============================================================================

SET search_path TO app, public;

-- ---- invite codes -------------------------------------------------------

-- SAHAKAR-#### with a free four-digit number; if that pool is crowded, five
-- digits. The column is UNIQUE, so a code is only ever handed out once.
CREATE OR REPLACE FUNCTION app.generate_referral_code() RETURNS text AS $$
DECLARE
    v_code text;
    v_try  integer := 0;
BEGIN
    LOOP
        v_try := v_try + 1;
        IF v_try <= 40 THEN
            v_code := 'SAHAKAR-' || (1000 + floor(random() * 9000))::int;
        ELSE
            v_code := 'SAHAKAR-' || (10000 + floor(random() * 90000))::int;
        END IF;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM app.users WHERE referral_code = v_code);
        IF v_try > 200 THEN
            RAISE EXCEPTION 'could not generate a free referral code';
        END IF;
    END LOOP;
    RETURN v_code;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION app.users_assign_referral_code() RETURNS trigger AS $$
BEGIN
    IF NEW.referral_code IS NULL OR NEW.referral_code = '' THEN
        NEW.referral_code := app.generate_referral_code();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS users_assign_referral_code ON app.users;
CREATE TRIGGER users_assign_referral_code
    BEFORE INSERT ON app.users
    FOR EACH ROW EXECUTE FUNCTION app.users_assign_referral_code();

-- Members who already have no code.
UPDATE app.users
   SET referral_code = app.generate_referral_code(), updated_at = now()
 WHERE referral_code IS NULL OR referral_code = '';

-- ---- REGISTERED -> TRANSACTED on a paid order --------------------------------

CREATE OR REPLACE FUNCTION app.advance_referral_on_paid_order() RETURNS trigger AS $$
DECLARE
    v_inviter_id bigint;
BEGIN
    -- The one referral this member was invited by; only ever moves forward.
    UPDATE app.referral
       SET status = 'TRANSACTED', transacted_at = now()
     WHERE invitee_member_id = NEW.member_id
       AND status = 'REGISTERED'
    RETURNING inviter_member_id INTO v_inviter_id;

    IF v_inviter_id IS NOT NULL THEN
        -- Pays every level the inviter has now crossed, once each.
        PERFORM app.award_referral_level_points(v_inviter_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS order_advance_referral ON app."order";
CREATE TRIGGER order_advance_referral
    AFTER INSERT OR UPDATE OF payment_status ON app."order"
    FOR EACH ROW
    WHEN (NEW.payment_status = 'PAID')
    EXECUTE FUNCTION app.advance_referral_on_paid_order();

-- Backfill: invitees who already had a paid order before this trigger existed.
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        UPDATE app.referral ref
           SET status = 'TRANSACTED', transacted_at = COALESCE(ref.transacted_at, now())
         WHERE ref.status = 'REGISTERED'
           AND EXISTS (
               SELECT 1 FROM app."order" o
                WHERE o.member_id = ref.invitee_member_id
                  AND o.payment_status = 'PAID'
           )
        RETURNING ref.inviter_member_id
    LOOP
        PERFORM app.award_referral_level_points(r.inviter_member_id);
    END LOOP;
END;
$$;
