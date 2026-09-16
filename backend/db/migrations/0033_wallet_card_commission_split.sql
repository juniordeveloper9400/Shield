-- ============================================================================
--  0033 · Health Pass commission split, folded into activation approval
-- ============================================================================
--  shieldweb's admin console approves a Health Pass activation with its own
--  direct-Neon SQL (src/api/activations.ts's approveActivation) — it never
--  calls backend/api at all, so backend/api's own commission logic
--  (wallet.service.ts's approveCard, migration 0032) never actually runs for
--  a real admin approval. This migration puts the same split where it can
--  actually take effect: a Postgres function shieldweb calls in one
--  statement, which is also the only way to keep this atomic with
--  shieldweb's HTTP-per-call Neon driver (no cross-statement transactions).
--
--  Who the direct seller is: `wallet_card.sold_by_agent_id` (the "Agent
--  code" a member types in at Health Pass checkout — `shield agent_invester`,
--  the newer app) when set, else whichever agent `app.agent_customer` links
--  this member to (set once at registration — the root SHIELD app's own,
--  older mechanism). Either app's own way of recording "who sold this"
--  works without either app needing to know about the other's.
--
--  The split itself, once a seller resolves to a real APPROVED agent:
--    - 10% of the loaded amount is the whole commission pool;
--    - 60% of the pool to the seller (their own direct-sale earnings);
--    - 10% of the pool additionally to the one national agent, but only
--      when the seller is someone else — the national agent's own direct
--      sale already got the 60% above, nothing on top of it;
--    - whatever is left (30% normally, 40% when the national agent sold
--      directly, the full pool when no seller resolves at all) is not owed
--      to any agent — logged to app.commission_reserve_entry (migration
--      0032) as the company's own share, never surfaced to a member or an
--      agent anywhere in the app.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0033_wallet_card_commission_split.sql --yes
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
    v_national_id      bigint;
    v_override_share   numeric(12,2);
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

        IF v_seller_level <> 'NATIONAL' THEN
            SELECT id INTO v_national_id
            FROM app.agent
            WHERE level = 'NATIONAL' AND approval_status = 'APPROVED'
            LIMIT 1;

            IF v_national_id IS NOT NULL THEN
                v_override_share := ROUND(v_pool * 0.10, 2);
                UPDATE app.agent SET earned = earned + v_override_share WHERE id = v_national_id;
                v_distributed := v_distributed + v_override_share;
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
