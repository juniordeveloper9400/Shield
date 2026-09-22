-- ============================================================================
--  0060 · One permanent Member ID; two separate commission structures
-- ============================================================================
--  Two changes to how a Health Pass activation's money is split, both on
--  `app.approve_wallet_card_activation` (rewritten here on top of migration
--  0054's version, same function, same signature):
--
--  1. A member's own permanent Member ID (`SAHAKAR-####`) now also works as a
--     direct-sale link once its owner is a current, approved agent — see
--     `AgentCustomerRepository.linkCustomer` (root app) and
--     `ReferralService.applySignupCode` (backend/api, `shield agent_invester/`),
--     both updated alongside this migration to match an agent's own SHD-…
--     code OR their permanent Member ID. `ReferralRepository.recordSignup`
--     (root app) and the same backend method now also refuse to create a
--     plain member-referral edge for a code whose owner is currently an
--     approved agent, so a signup through that code is only ever one or the
--     other, never both. This migration itself needs no schema change for
--     that half — it is pure application-code routing into the tables that
--     already exist (`app.agent_customer` vs `app.referral`).
--
--  2. The flat 8% company-reserve share (migration 0053) is no longer taken
--     from every activation. It now applies only to the plain
--     member-refers-member case — the load's 10% commission pool splits
--     2% to the referrer's wallet and 8% to Reserved, same as it already did.
--     An agent-sold activation (`sold_by_agent_id`, or a matching
--     `app.agent_customer` link — either code now) goes back to exactly the
--     pre-0053 split instead: 60% of the pool to the direct-selling agent,
--     the decaying hop overrides up their real parent chain, and whatever
--     that leaves unspent is `POOL_LEFTOVER` — no flat 8% on top. An
--     activation with neither an agent nor a referrer reserves nothing, same
--     as before 0053 — there is no commission relationship on it for a
--     share to be a share *of*.
--
--  Needs 0043 (award_referral_level_points), 0053 (commission_reserve_entry.source)
--  and 0054 (pay_referral_commission, the version this rewrites).
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0060_separate_member_and_agent_commission.sql --yes
--
--  To undo: re-apply 0054_referral_commission_autocredit.sql, which restores
--  its own version of this same function (flat 8% on every activation).
-- ============================================================================

SET search_path TO app, public;

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

    -- Who this is: an agent-sold activation (sold_by_agent_id at submission,
    -- or a matching app.agent_customer direct-sale link — either the agent's
    -- own SHD-… code or, since this migration, their permanent Member ID)
    -- XOR a plain member-to-member referral. Never both — recordSignup /
    -- applySignupCode refuse to create the member-referral edge for a code
    -- whose owner is a current agent, so at most one of v_seller_level /
    -- v_referrer_id is ever set for the same buyer.
    SELECT COALESCE(
        v_sold_by_agent_id,
        (SELECT ac.agent_id FROM app.agent_customer ac WHERE ac.member_id = v_member_id LIMIT 1)
    ) INTO v_seller_id;

    IF v_seller_id IS NOT NULL THEN
        SELECT level INTO v_seller_level
        FROM app.agent
        WHERE id = v_seller_id AND approval_status = 'APPROVED';
    END IF;

    SELECT referred_by_member_id INTO v_referrer_id FROM app.users WHERE id = v_member_id;
    IF v_referrer_id IS NULL THEN
        SELECT inviter_member_id INTO v_referrer_id
        FROM app.referral
        WHERE invitee_member_id = v_member_id
        ORDER BY id DESC LIMIT 1;
    END IF;

    -- ---- Agent commission structure: 60% direct + hop overrides + leftover ----
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

    -- ---- Plain member-referral structure: 2% to the referrer + 8% reserved ----
    ELSIF v_referrer_id IS NOT NULL THEN
        v_company_share := ROUND(v_amount * 0.08, 2);
        IF v_company_share > 0 THEN
            INSERT INTO app.commission_reserve_entry (wallet_card_id, amount, source)
            VALUES (p_card_id, v_company_share, 'COMPANY_SHARE');
        END IF;
        -- The 2% itself is paid below, by app.pay_referral_commission, the
        -- same call every approval path already goes through.
    END IF;
    -- Neither an agent nor a referrer: nothing is reserved — there is no
    -- commission relationship on this activation for a share to be a share of.

    IF v_referrer_id IS NOT NULL THEN
        PERFORM app.pay_referral_commission(p_card_id, v_referrer_id);
    END IF;

    RETURN QUERY SELECT p_card_id;
END;
$$ LANGUAGE plpgsql;
