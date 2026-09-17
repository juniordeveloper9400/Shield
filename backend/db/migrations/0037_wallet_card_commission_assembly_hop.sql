-- ============================================================================
--  0037 · Health Pass commission split — extend the chain walk to 4 hops
-- ============================================================================
--  0036 introduced a single decaying rate table walked up each seller's real
--  parent_id chain (10% / 6% / 5% for hops 1-3), rather than a special case
--  per level. The assembly-level numbers just given (assembly 60% / district
--  10% / state 6% / region 5% / national 4% / reserved 15%) are that exact
--  same rule one hop further: an ASSEMBLY seller's hop 1 is a real district
--  agent, hop 2 a real state agent, hop 3 a real region agent, hop 4 the
--  national agent -> 600/100/60/50/40/150 on a 10,000 rupee plan, i.e. 15%
--  reserved — matching exactly what was specified. This migration only
--  extends v_hop_rates with that fourth entry; the walk logic itself
--  (0036) is unchanged.
--
--  Levels past assembly (lsgd, ward) still aren't specified — a seller 5+
--  hops below national pays out at most these 4 known hops and reserves the
--  rest. Extend v_hop_rates again in a later migration once those numbers
--  are given.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0037_wallet_card_commission_assembly_hop.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE OR REPLACE FUNCTION app.approve_wallet_card_activation(p_card_id bigint)
RETURNS TABLE(approved_id bigint) AS $$
DECLARE
    v_wallet_id        bigint;
    v_member_id        bigint;
    v_tier_id          bigint;
    v_amount           numeric(12,2);
    v_bonus            numeric(12,2);
    v_tier_name        text;
    v_sold_by_agent_id bigint;
    v_seller_id        bigint;
    v_seller_level     app.agent_level;
    v_pool             numeric(12,2);
    v_direct_share     numeric(12,2);
    v_distributed      numeric(12,2) := 0;
    v_ancestor_id      bigint;
    v_credit_id        bigint;
    v_hop_share        numeric(12,2);
    v_hop_rates        numeric[] := ARRAY[0.10, 0.06, 0.05, 0.04];
    v_hop              int;
    v_reserve          numeric(12,2);
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

    -- Commission split.
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
            INSERT INTO app.commission_reserve_entry (wallet_card_id, amount) VALUES (p_card_id, v_reserve);
        END IF;
    END IF;

    RETURN QUERY SELECT p_card_id;
END;
$$ LANGUAGE plpgsql;
