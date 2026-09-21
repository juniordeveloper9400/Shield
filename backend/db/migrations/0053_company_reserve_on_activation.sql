-- ============================================================================
--  0053 · Company reserve: 8% of every approved activation
-- ============================================================================
--  The Reserved page (admin console, Super Admin only) is the company's own
--  money: what is set aside from Health Pass plans and never credited to a
--  member or an agent. Until now it only ever held the *leftover* of the
--  agent-commission pool, and only when an approved agent had sold the plan --
--  so a member who bought a plan with no agent added nothing, and the page
--  read Rs 0.
--
--  From this migration, approving ANY activation also puts 8% of the loaded
--  amount into the Reserved ledger, whoever sold it and whether or not the
--  member was referred. The rest of the approval is untouched: the member's
--  wallet credit and bonus, the agent split (60% direct + up-line overrides),
--  the leftover-of-the-pool entry for agent sales, and the 2% member referral
--  commission.
--
--  So one approval can now leave two Reserved rows, told apart by the new
--  `source` column:
--    POOL_LEFTOVER  the unspent part of the agent pool   (agent sales only)
--    COMPANY_SHARE  8% of the load                        (every activation)
--
--  Also backfills: every already-approved card that has no COMPANY_SHARE row
--  gets one (8% of its amount, dated when it was reviewed). Safe to re-run --
--  a card that has its row is skipped, and the function is replaced in place.
--
--  Needs 0032 (the ledger) and 0043 (this function's previous version).
--    dart run backend/db/apply_migration.dart backend/db/migrations/0053_company_reserve_on_activation.sql --yes
--
--  To undo: DELETE FROM app.commission_reserve_entry WHERE source = 'COMPANY_SHARE';
--  and re-apply 0043 to restore the previous function.
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.commission_reserve_entry
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'POOL_LEFTOVER';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname = 'commission_reserve_entry_source_check'
    ) THEN
        ALTER TABLE app.commission_reserve_entry
          ADD CONSTRAINT commission_reserve_entry_source_check
          CHECK (source IN ('POOL_LEFTOVER', 'COMPANY_SHARE'));
    END IF;
END;
$$;

COMMENT ON COLUMN app.commission_reserve_entry.source IS
  'POOL_LEFTOVER = the unspent part of an agent sale''s commission pool; '
  'COMPANY_SHARE = the company''s 8% of the load, on every approved activation.';

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
    v_referral_commission numeric(12,2);
    v_referrer_wallet_id bigint;
    v_referral_id        bigint;
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

    -- Member-to-member referral commission -- every plan this member
    -- activates, not just their first, pays whoever referred them (if
    -- anyone did) 2% of the load. Independent of the agent split above.
    SELECT referred_by_member_id INTO v_referrer_id FROM app.users WHERE id = v_member_id;

    IF v_referrer_id IS NOT NULL THEN
        v_referral_commission := ROUND(v_amount * 0.02, 2);

        SELECT id INTO v_referrer_wallet_id FROM app.wallet WHERE member_id = v_referrer_id;
        IF v_referrer_wallet_id IS NULL THEN
            INSERT INTO app.wallet (member_id) VALUES (v_referrer_id) RETURNING id INTO v_referrer_wallet_id;
        END IF;

        INSERT INTO app.wallet_entry (wallet_id, kind, label, amount, occurred_on, wallet_card_id)
        VALUES (v_referrer_wallet_id, 'REFERRAL_EARNINGS', 'Referral commission', v_referral_commission, current_date, p_card_id);

        UPDATE app.wallet
           SET balance = balance + v_referral_commission, updated_at = now()
         WHERE id = v_referrer_wallet_id;

        -- The most recent edge for this exact pair, if one already exists
        -- (from apply-code REGISTERED, or an earlier order's TRANSACTED) --
        -- this activation is otherwise the first evidence of the edge.
        SELECT id INTO v_referral_id
        FROM app.referral
        WHERE inviter_member_id = v_referrer_id AND invitee_member_id = v_member_id
        ORDER BY id DESC
        LIMIT 1;

        IF v_referral_id IS NOT NULL THEN
            UPDATE app.referral
               SET status = 'PLAN_ACTIVATED',
                   plan_amount = v_amount,
                   commission_amount = commission_amount + v_referral_commission,
                   plan_activated_at = now()
             WHERE id = v_referral_id;
        ELSE
            INSERT INTO app.referral (inviter_member_id, invitee_member_id, status, plan_amount, commission_amount, plan_activated_at)
            VALUES (v_referrer_id, v_member_id, 'PLAN_ACTIVATED', v_amount, v_referral_commission, now());
        END IF;

        PERFORM app.award_referral_level_points(v_referrer_id);
    END IF;

    RETURN QUERY SELECT p_card_id;
END;
$$ LANGUAGE plpgsql;


-- ---- Backfill: activations approved before this migration ------------------

INSERT INTO app.commission_reserve_entry (wallet_card_id, amount, source, created_at)
SELECT wc.id, ROUND(wc.amount * 0.08, 2), 'COMPANY_SHARE', COALESCE(wc.reviewed_at, now())
  FROM app.wallet_card wc
 WHERE wc.status = 'APPROVED'
   AND ROUND(wc.amount * 0.08, 2) > 0
   AND NOT EXISTS (
       SELECT 1 FROM app.commission_reserve_entry cre
        WHERE cre.wallet_card_id = wc.id AND cre.source = 'COMPANY_SHARE'
   );
