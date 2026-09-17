-- ============================================================================
--  0036 · Health Pass commission split — decaying override up the real chain
-- ============================================================================
--  0035 special-cased "the seller's immediate parent (10%), plus a top-up to
--  national (6%) unless national already IS that parent". The district-level
--  numbers just given (district 60% / state 10% / region 6% / national 5% /
--  reserved 19%) show that isn't a special case at all — it is a single
--  decaying rate table applied to however many real hops separate the
--  seller from the top, via each agent's actual parent_id:
--
--      hop 1 up (the seller's real immediate parent) -> 10% of the pool
--      hop 2 up                                       ->  6% of the pool
--      hop 3 up                                       ->  5% of the pool
--
--  0035's numbers were this same rule, just truncated by how short the real
--  chain happens to be: a REGION seller's hop 1 IS the national agent (only
--  one hop exists) -> 600/100/0/300; a STATE seller's hop 1 is a real region
--  agent and hop 2 is national (chain ends there) -> 600/100/60/240; a
--  DISTRICT seller's hop 1 is a real state agent, hop 2 a real region agent,
--  hop 3 the national agent -> 600/100/60/50/190 on a 10,000 rupee plan
--  (i.e. 19% reserved, matching exactly what was just specified).
--
--  Each hop is credited only when that specific ancestor resolves to a real
--  APPROVED agent (walking through an unapproved one to keep looking further
--  up is fine — only the payment itself is gated on approval, same as the
--  seller's own direct share always has been). A seller with no resolvable
--  parent at all (the national agent's own sale, or a real but disconnected
--  agent with no parent on file) simply stops the walk at hop 1 and the rest
--  goes to reserve — nobody is paid a guess.
--
--  Levels past district (assembly, lsgd, ward) aren't specified yet — the
--  table above only has 3 entries, so a seller 4+ hops below national pays
--  out at most those first 3 hops and reserves the rest. Extend
--  v_hop_rates in a later migration once those numbers are given.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0036_wallet_card_commission_chain_walk.sql --yes
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
    v_hop_rates        numeric[] := ARRAY[0.10, 0.06, 0.05];
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
