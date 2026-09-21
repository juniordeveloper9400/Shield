-- ============================================================================
--  0054 · Referral commission — paid into the referrer's wallet, exactly once
-- ============================================================================
--  A member's referral commission (2% of every Health Pass plan a referred
--  member activates) used to be paid only by `approve_wallet_card_activation`,
--  and only if the referral was already on file when the plan was approved. Two
--  ways that left money unpaid while the app still showed it as "earned":
--
--   * the plan was approved BEFORE the friend registered with the member's code
--     (the friend bought a plan, then entered a referral ID) — nothing was owed
--     at approval time and nothing was ever revisited;
--   * a card approved by any path that is not that one function.
--
--  This migration makes the payment a single idempotent step that every path
--  reaches:
--
--   app.pay_referral_commission(card, referrer)  credits the referrer's wallet
--       (a REFERRAL_EARNINGS ledger line + balance), records it on the referral
--       (PLAN_ACTIVATED, plan_amount, commission_amount), and pays any level
--       points that unlocks. One payment per card — guarded by the ledger line
--       itself and an advisory lock, so being called twice, or concurrently,
--       pays once.
--   wallet_card_pay_referral      (AFTER INSERT / UPDATE OF status on
--       app.wallet_card, when APPROVED) — every approval path pays.
--   referral_pay_earlier_plans    (AFTER INSERT on app.referral) — when a referral
--       is recorded for a member who already holds approved plans, those pay now.
--
--  It ends with a catch-up: every approved card whose owner has a referrer and
--  has not paid yet pays now (idempotent, so re-running pays nothing twice).
--
--  Needs 0043 (award_referral_level_points) and 0053_company_reserve_on_activation
--  (the previous version of app.approve_wallet_card_activation, which this rewrites
--  with the company-reserve step kept exactly as it is there).
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0054_referral_commission_autocredit.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE OR REPLACE FUNCTION app.pay_referral_commission(p_card_id bigint, p_referrer_id bigint)
RETURNS numeric AS $$
DECLARE
    v_wallet_id          bigint;
    v_amount             numeric(12,2);
    v_status             app.approval_status;
    v_member_id          bigint;
    v_commission         numeric(12,2);
    v_referrer_wallet_id bigint;
    v_referral_id        bigint;
BEGIN
    SELECT c.wallet_id, c.amount, c.status, w.member_id
      INTO v_wallet_id, v_amount, v_status, v_member_id
    FROM app.wallet_card c
    JOIN app.wallet w ON w.id = c.wallet_id
    WHERE c.id = p_card_id;

    -- Only an approved plan pays, and nobody is their own referrer.
    IF NOT FOUND OR v_status <> 'APPROVED' OR p_referrer_id IS NULL OR p_referrer_id = v_member_id THEN
        RETURN 0;
    END IF;

    -- Two callers reaching the same card at once must pay it once.
    PERFORM pg_advisory_xact_lock(hashtextextended('referral_commission:' || p_card_id::text, 0));

    IF EXISTS (
        SELECT 1
        FROM app.wallet_entry e
        JOIN app.wallet rw ON rw.id = e.wallet_id
        WHERE e.kind = 'REFERRAL_EARNINGS'
          AND e.wallet_card_id = p_card_id
          AND rw.member_id = p_referrer_id
    ) THEN
        RETURN 0; -- already paid
    END IF;

    v_commission := ROUND(v_amount * 0.02, 2);
    IF v_commission <= 0 THEN
        RETURN 0;
    END IF;

    SELECT id INTO v_referrer_wallet_id FROM app.wallet WHERE member_id = p_referrer_id;
    IF v_referrer_wallet_id IS NULL THEN
        INSERT INTO app.wallet (member_id) VALUES (p_referrer_id) RETURNING id INTO v_referrer_wallet_id;
    END IF;

    INSERT INTO app.wallet_entry (wallet_id, kind, label, amount, occurred_on, wallet_card_id)
    VALUES (v_referrer_wallet_id, 'REFERRAL_EARNINGS', 'Referral commission', v_commission, current_date, p_card_id);

    UPDATE app.wallet
       SET balance = balance + v_commission, updated_at = now()
     WHERE id = v_referrer_wallet_id;

    -- The most recent edge for this exact pair; a plan activation is also proof
    -- the friend transacted, so the edge moves all the way to PLAN_ACTIVATED.
    SELECT id INTO v_referral_id
    FROM app.referral
    WHERE inviter_member_id = p_referrer_id AND invitee_member_id = v_member_id
    ORDER BY id DESC
    LIMIT 1;

    IF v_referral_id IS NOT NULL THEN
        UPDATE app.referral
           SET status = 'PLAN_ACTIVATED',
               plan_amount = v_amount,
               commission_amount = commission_amount + v_commission,
               transacted_at = COALESCE(transacted_at, now()),
               plan_activated_at = now()
         WHERE id = v_referral_id;
    ELSE
        INSERT INTO app.referral (inviter_member_id, invitee_member_id, status, plan_amount, commission_amount, transacted_at, plan_activated_at)
        VALUES (p_referrer_id, v_member_id, 'PLAN_ACTIVATED', v_amount, v_commission, now(), now());
    END IF;

    PERFORM app.award_referral_level_points(p_referrer_id);

    RETURN v_commission;
END;
$$ LANGUAGE plpgsql;

-- ---- every path that approves a plan pays ----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.wallet_card_pay_referral() RETURNS trigger AS $$
DECLARE
    v_member_id   bigint;
    v_referrer_id bigint;
BEGIN
    SELECT w.member_id, u.referred_by_member_id
      INTO v_member_id, v_referrer_id
    FROM app.wallet w
    JOIN app.users u ON u.id = w.member_id
    WHERE w.id = NEW.wallet_id;

    IF v_referrer_id IS NULL AND v_member_id IS NOT NULL THEN
        SELECT inviter_member_id INTO v_referrer_id
        FROM app.referral
        WHERE invitee_member_id = v_member_id
        ORDER BY id DESC LIMIT 1;
    END IF;

    IF v_referrer_id IS NOT NULL THEN
        PERFORM app.pay_referral_commission(NEW.id, v_referrer_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS wallet_card_pay_referral ON app.wallet_card;
CREATE TRIGGER wallet_card_pay_referral
    AFTER INSERT OR UPDATE OF status ON app.wallet_card
    FOR EACH ROW
    WHEN (NEW.status = 'APPROVED')
    EXECUTE FUNCTION app.wallet_card_pay_referral();

-- ---- a referral recorded after the plan was bought pays for that plan ------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.referral_pay_earlier_plans() RETURNS trigger AS $$
DECLARE
    v_card_id bigint;
BEGIN
    FOR v_card_id IN
        SELECT c.id
        FROM app.wallet_card c
        JOIN app.wallet w ON w.id = c.wallet_id
        WHERE w.member_id = NEW.invitee_member_id AND c.status = 'APPROVED'
        ORDER BY c.id
    LOOP
        PERFORM app.pay_referral_commission(v_card_id, NEW.inviter_member_id);
    END LOOP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS referral_pay_earlier_plans ON app.referral;
CREATE TRIGGER referral_pay_earlier_plans
    AFTER INSERT ON app.referral
    FOR EACH ROW
    WHEN (NEW.invitee_member_id IS NOT NULL)
    EXECUTE FUNCTION app.referral_pay_earlier_plans();

-- ---- the approval function now delegates the referral step -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.approve_wallet_card_activation(p_card_id bigint)
RETURNS TABLE(approved_id bigint) AS $$
DECLARE
    v_wallet_id          bigint;
    v_member_id          bigint;
    v_tier_id            bigint;
    v_amount             numeric(12,2);
    v_bonus              numeric(12,2);
    v_tier_name          text;
    v_sold_by_agent_id   bigint;
    v_seller_id          bigint;
    v_seller_level       app.agent_level;
    v_pool               numeric(12,2);
    v_direct_share       numeric(12,2);
    v_distributed        numeric(12,2) := 0;
    v_ancestor_id        bigint;
    v_credit_id          bigint;
    v_hop_share          numeric(12,2);
    v_hop_rates          numeric[] := ARRAY[0.10, 0.06, 0.05, 0.04, 0.03, 0.02];
    v_hop                int;
    v_reserve            numeric(12,2);
    v_referrer_id        bigint;
    v_company_share      numeric(12,2);
BEGIN
    UPDATE app.wallet_card
       SET status = 'APPROVED', reviewed_at = now()
     WHERE id = p_card_id AND status IN ('PENDING', 'ON_HOLD')
     RETURNING wallet_id, tier_id, amount, bonus, sold_by_agent_id
       INTO v_wallet_id, v_tier_id, v_amount, v_bonus, v_sold_by_agent_id;

    IF NOT FOUND THEN
        RETURN; -- already decided, or not a real card id — no rows out
    END IF;

    SELECT member_id INTO v_member_id FROM app.wallet WHERE id = v_wallet_id;
    SELECT name INTO v_tier_name FROM app.membership_tier WHERE id = v_tier_id;

    INSERT INTO app.wallet_entry (wallet_id, kind, label, amount, occurred_on, wallet_card_id)
    VALUES (v_wallet_id, 'ACTIVATION', v_tier_name || ' activation', v_amount, current_date, p_card_id);

    IF v_bonus > 0 THEN
        INSERT INTO app.wallet_entry (wallet_id, kind, label, amount, occurred_on, wallet_card_id)
        VALUES (v_wallet_id, 'BONUS', v_tier_name || ' bonus · 10%', v_bonus, current_date, p_card_id);
    END IF;

    UPDATE app.wallet
       SET balance    = balance + v_amount + v_bonus,
           opened_at  = COALESCE(opened_at, now()),
           updated_at = now()
     WHERE id = v_wallet_id;

    -- Unchanged from the pre-existing behaviour: the agent portal's own
    -- "Direct sale" / "Team sales" screens are worked out from this table,
    -- independent of the commission money below.
    INSERT INTO app.agent_customer_plan (agent_customer_id, tier_id, amount, activated_on, wallet_card_id)
    SELECT ac.id, v_tier_id, v_amount, current_date, p_card_id
    FROM app.agent_customer ac
    WHERE ac.member_id = v_member_id;

    -- Agent commission split.
    SELECT COALESCE(
        v_sold_by_agent_id,
        (SELECT ac.agent_id FROM app.agent_customer ac WHERE ac.member_id = v_member_id LIMIT 1)
    ) INTO v_seller_id;

    IF v_seller_id IS NOT NULL THEN
        SELECT level INTO v_seller_level
        FROM app.agent
        WHERE id = v_seller_id AND approval_status = 'APPROVED';
    END IF;

    IF v_seller_level IS NOT NULL THEN
        v_pool := v_amount * 0.10;
        v_direct_share := ROUND(v_pool * 0.60, 2);

        UPDATE app.agent
           SET earned         = earned + v_direct_share,
               personal_sales = personal_sales + v_amount
         WHERE id = v_seller_id;

        v_distributed := v_direct_share;

        v_ancestor_id := v_seller_id;
        FOR v_hop IN 1..array_length(v_hop_rates, 1) LOOP
            SELECT parent_id INTO v_ancestor_id FROM app.agent WHERE id = v_ancestor_id;
            EXIT WHEN v_ancestor_id IS NULL;

            SELECT id INTO v_credit_id
            FROM app.agent
            WHERE id = v_ancestor_id AND approval_status = 'APPROVED';

            IF v_credit_id IS NOT NULL THEN
                v_hop_share := ROUND(v_pool * v_hop_rates[v_hop], 2);
                UPDATE app.agent SET earned = earned + v_hop_share WHERE id = v_credit_id;
                v_distributed := v_distributed + v_hop_share;
            END IF;
        END LOOP;

        v_reserve := ROUND(v_pool - v_distributed, 2);
        IF v_reserve > 0 THEN
            INSERT INTO app.commission_reserve_entry (wallet_card_id, amount, source)
            VALUES (p_card_id, v_reserve, 'POOL_LEFTOVER');
        END IF;
    END IF;

    -- The company's own 8% of the load, on EVERY approved activation -- whether
    -- or not an agent sold it, and whether or not the member was referred.
    -- Company money: it only lands in the Reserved ledger, never in a member's
    -- or an agent's wallet. Independent of the leftover entry above, which is
    -- the unspent part of the agent pool and exists only for agent sales.
    v_company_share := ROUND(v_amount * 0.08, 2);
    IF v_company_share > 0 THEN
        INSERT INTO app.commission_reserve_entry (wallet_card_id, amount, source)
        VALUES (p_card_id, v_company_share, 'COMPANY_SHARE');
    END IF;

    -- Member-to-member referral commission: 2% of the load to whoever referred
    -- this member, on every plan they activate. The paying itself lives in
    -- app.pay_referral_commission, which is idempotent (one payment per card) and
    -- is also fired by the wallet_card trigger below and when a referral is
    -- recorded — so a plan approved before the member was referred still pays.
    -- Calling it here as well keeps this function correct on its own.
    SELECT referred_by_member_id INTO v_referrer_id FROM app.users WHERE id = v_member_id;
    IF v_referrer_id IS NULL THEN
        SELECT inviter_member_id INTO v_referrer_id
        FROM app.referral
        WHERE invitee_member_id = v_member_id
        ORDER BY id DESC LIMIT 1;
    END IF;
    IF v_referrer_id IS NOT NULL THEN
        PERFORM app.pay_referral_commission(p_card_id, v_referrer_id);
    END IF;

    RETURN QUERY SELECT p_card_id;
END;
$$ LANGUAGE plpgsql;

-- ---- catch-up: plans already approved for a referred member that never paid ------------------------------------------------------
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT c.id AS card_id,
               COALESCE(u.referred_by_member_id,
                        (SELECT f.inviter_member_id FROM app.referral f
                          WHERE f.invitee_member_id = u.id ORDER BY f.id DESC LIMIT 1)) AS referrer_id
        FROM app.wallet_card c
        JOIN app.wallet w ON w.id = c.wallet_id
        JOIN app.users u ON u.id = w.member_id
        WHERE c.status = 'APPROVED'
        ORDER BY c.id
    LOOP
        IF r.referrer_id IS NOT NULL THEN
            PERFORM app.pay_referral_commission(r.card_id, r.referrer_id);
        END IF;
    END LOOP;
END $$;
