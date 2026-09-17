-- ============================================================================
--  0035 · Health Pass commission split — walk the real reporting line
-- ============================================================================
--  Extends 0033's split from "seller + a flat national override" to a real
--  upline chain, using each agent's actual `parent_id` (confirmed live: a
--  REGION agent's parent is the national agent, a STATE agent's parent is a
--  real REGION agent, a DISTRICT agent's parent is a real STATE agent, and
--  so on — this is a real reporting tree, not just a level label).
--
--  The rule, once a seller resolves to a real APPROVED agent and their
--  level isn't NATIONAL (a national agent's own direct sale gets no
--  overrides — nothing sits above them):
--    - 60% of the pool to the seller, as before;
--    - 10% of the pool to the seller's own immediate parent agent (their
--      real upline, via `parent_id`), when that parent resolves to a real
--      APPROVED agent;
--    - 6% of the pool to the one national agent, but only when the
--      national agent isn't ALREADY the one who was just paid the 10%
--      immediate-parent share above (a REGION seller's parent already IS
--      the national agent in this tree, so they are not paid twice for
--      the same sale);
--    - whatever is left over (40% for a national agent's own sale, 30%
--      when the immediate parent IS the national agent, 24% when the
--      immediate parent and the national agent are two different agents,
--      more still if the seller has no resolvable parent at all) is
--      logged to app.commission_reserve_entry (migration 0032) as the
--      company's own share, same as before.
--
--  Worked examples this reproduces exactly:
--    national sells directly  -> 600 direct / 0 / 0        / 400 reserved
--    region sells directly    -> 600 direct / 100 (parent = national) / 0 / 300 reserved
--    state sells directly     -> 600 direct / 100 (parent = region)   / 60 national / 240 reserved
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0035_wallet_card_commission_parent_chain.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE OR REPLACE FUNCTION app.approve_wallet_card_activation(p_card_id bigint)
RETURNS TABLE(approved_id bigint) AS $$
DECLARE
    v_wallet_id         bigint;
    v_member_id         bigint;
    v_tier_id           bigint;
    v_amount            numeric(12,2);
    v_bonus             numeric(12,2);
    v_tier_name         text;
    v_sold_by_agent_id  bigint;
    v_seller_id         bigint;
    v_seller_level      app.agent_level;
    v_pool              numeric(12,2);
    v_direct_share      numeric(12,2);
    v_distributed       numeric(12,2) := 0;
    v_parent_id         bigint;
    v_resolved_parent_id bigint;
    v_parent_share      numeric(12,2);
    v_national_id       bigint;
    v_national_share    numeric(12,2);
    v_reserve           numeric(12,2);
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

        IF v_seller_level <> 'NATIONAL' THEN
            -- Immediate parent override — the seller's own real upline.
            SELECT parent_id INTO v_parent_id FROM app.agent WHERE id = v_seller_id;

            IF v_parent_id IS NOT NULL THEN
                SELECT id INTO v_resolved_parent_id
                FROM app.agent
                WHERE id = v_parent_id AND approval_status = 'APPROVED';
            END IF;

            IF v_resolved_parent_id IS NOT NULL THEN
                v_parent_share := ROUND(v_pool * 0.10, 2);
                UPDATE app.agent SET earned = earned + v_parent_share WHERE id = v_resolved_parent_id;
                v_distributed := v_distributed + v_parent_share;
            END IF;

            -- National top-up — skipped when national IS the immediate
            -- parent just credited above, so they are never paid twice.
            SELECT id INTO v_national_id
            FROM app.agent
            WHERE level = 'NATIONAL' AND approval_status = 'APPROVED'
            LIMIT 1;

            IF v_national_id IS NOT NULL
               AND (v_resolved_parent_id IS NULL OR v_national_id <> v_resolved_parent_id) THEN
                v_national_share := ROUND(v_pool * 0.06, 2);
                UPDATE app.agent SET earned = earned + v_national_share WHERE id = v_national_id;
                v_distributed := v_distributed + v_national_share;
            END IF;
        END IF;

        v_reserve := ROUND(v_pool - v_distributed, 2);
        IF v_reserve > 0 THEN
            INSERT INTO app.commission_reserve_entry (wallet_card_id, amount) VALUES (p_card_id, v_reserve);
        END IF;
    END IF;

    RETURN QUERY SELECT p_card_id;
END;
$$ LANGUAGE plpgsql;
