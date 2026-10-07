-- ============================================================================
--  0076 · Ledger posting: the Head Office side of an activation
-- ============================================================================
--  Migration 0075 posted only a store's own cash receipt on a Health Pass
--  activation, deferring the member wallet credit, the bonus, the agent
--  commissions and the reserves — none of them tied to one shop in this
--  schema. This posts those too, at the Head Office entity, alongside the
--  store's own entry (same source row, same event, two entities — see
--  0074's widened UNIQUE (source_table, source_id, event, entity_id)).
--
--  What funds the gap between the store's cash receipt and the bonus,
--  commissions and reserves this activation also commits to is a real,
--  open question: is the 10% bonus and the agent commission a day-1 cost,
--  or a provision funded by margin earned later when the member actually
--  spends their wallet at the pharmacy? That's a revenue-recognition
--  policy call for the accountant, not something to invent here. So the
--  gap is posted to a plainly named, provisional Suspense account instead
--  of being folded into any real account — see the function's own comment
--  below for exactly how it's computed.
--
--  Never blocks the real approval — same tolerance as 0075: wrapped in its
--  own BEGIN/EXCEPTION, separate from the store-side block, so one failing
--  never stops the other or the approval itself.
--
--  pg-mem has no PL/pgSQL support, so this function is verified live
--  against the dev database instead — see
--  scratchpad/verify_ledger_posting.mjs (not checked in; ask the author
--  for the current copy, or write a fresh one against this migration).
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0076_ledger_posting_activation_head_office.sql --yes
-- ============================================================================

SET search_path TO app, public;

INSERT INTO app.chart_of_account (code, name, type) VALUES
    ('5003', 'Member bonus expense — provisional', 'EXPENSE'),
    ('9000', 'Suspense — pending accountant classification (provisional)', 'EQUITY')
ON CONFLICT (code) DO NOTHING;

INSERT INTO app.posting_rule (event, line_role, account_code) VALUES
    ('activation_received', 'due_from_store', '1004'),
    ('activation_received', 'bonus_expense', '5003'),
    ('activation_received', 'agent_commission_expense', '5001'),
    ('activation_received', 'suspense', '9000')
ON CONFLICT (event, line_role) DO NOTHING;

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
    v_pool                numeric(12,2);
    v_direct_share        numeric(12,2);
    v_distributed          numeric(12,2) := 0;
    v_ancestor_id         bigint;
    v_credit_id           bigint;
    v_hop_share           numeric(12,2);
    v_hop_rates           numeric[] := ARRAY[0.10, 0.06, 0.05, 0.04, 0.03, 0.02];
    v_hop                 int;
    v_reserve             numeric(12,2);
    v_referrer_id         bigint;
    v_referral_commission numeric(12,2);
    v_referrer_wallet_id  bigint;
    v_referral_id         bigint;
    v_company_share       numeric(12,2);
    -- ledger posting (migration 0075)
    v_received            numeric(12,2);
    v_entity_id            bigint;
    v_entry_id             uuid;
    v_acct_cash            bigint;
    v_acct_due             bigint;
    -- ledger posting (migration 0076; provisional) — Head Office side
    v_hq_entity_id         bigint;
    v_hq_entry_id          uuid;
    v_acct_due_from        bigint;
    v_acct_wallet          bigint;
    v_acct_agent_payable   bigint;
    v_acct_reserve_company bigint;
    v_acct_reserve_pool    bigint;
    v_acct_bonus_expense   bigint;
    v_acct_commission_exp  bigint;
    v_acct_suspense        bigint;
    v_plug                 numeric(12,2);
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

    -- ---- ledger posting (migration 0075; provisional) --------------------
    -- Only the store's own cash receipt: Dr Cash — store, Cr Due to Head
    -- Office, for whatever was actually received (received_amount, falling
    -- back to the load amount when no receipt figure was recorded). See
    -- this migration's header for why nothing else from this function is
    -- posted yet.
    BEGIN
        SELECT s.entity_id, COALESCE(wc.received_amount, v_amount)
          INTO v_entity_id, v_received
          FROM app.wallet_card wc
          JOIN app.shield_store s ON s.id = wc.store_id
         WHERE wc.id = p_card_id;

        IF v_entity_id IS NOT NULL AND v_received > 0 THEN
            v_acct_cash := app.ledger_account('activation_received', 'cash_in');
            v_acct_due  := app.ledger_account('activation_received', 'due_to_head_office');

            IF v_acct_cash IS NOT NULL AND v_acct_due IS NOT NULL THEN
                PERFORM app.assert_ledger_period_open(v_entity_id, current_date);

                INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
                VALUES (v_entity_id, current_date, 'wallet_card', p_card_id::text, 'activation_received',
                        'Health Pass activation received at store')
                RETURNING id INTO v_entry_id;

                INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES
                    (v_entry_id, v_acct_cash, v_received, 0),
                    (v_entry_id, v_acct_due, 0, v_received);

                PERFORM app.assert_journal_entry_balanced(v_entry_id);
            END IF;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Ledger posting skipped for wallet_card %: %', p_card_id, SQLERRM;
    END;

    -- ---- ledger posting (migration 0076; provisional) ----------------------
    -- The Head Office side deferred in migration 0075: the member wallet
    -- credit, the bonus, the agent commissions and the reserves this
    -- activation creates — none of them tied to one shop (see that
    -- migration's own header). Whatever is left after those known pieces
    -- and the store's own cash receipt (v_received) is posted to Suspense,
    -- not guessed at: that gap is exactly the revenue-recognition question
    -- (is the bonus/commission a day-1 cost, or funded from margin earned
    -- later when the member spends their wallet?) that needs the
    -- accountant's answer before this account can be reclassified. Never
    -- blocks the real approval — see migration 0075's header for why.
    BEGIN
        SELECT id INTO v_hq_entity_id FROM app.legal_entity WHERE code = 'HQ';
        -- Independent of the store block above: known from the card alone,
        -- so this still posts even when the card has no store/entity.
        SELECT COALESCE(received_amount, v_amount) INTO v_received FROM app.wallet_card WHERE id = p_card_id;

        IF v_hq_entity_id IS NOT NULL THEN
            v_acct_due_from        := app.ledger_account('activation_received', 'due_from_store');
            v_acct_wallet          := app.ledger_account('activation_received', 'member_wallet');
            v_acct_agent_payable   := app.ledger_account('activation_received', 'agent_commission');
            v_acct_reserve_company := app.ledger_account('activation_received', 'reserve_company');
            v_acct_reserve_pool    := app.ledger_account('activation_received', 'reserve_pool');
            v_acct_bonus_expense   := app.ledger_account('activation_received', 'bonus_expense');
            v_acct_commission_exp  := app.ledger_account('activation_received', 'agent_commission_expense');
            v_acct_suspense        := app.ledger_account('activation_received', 'suspense');

            IF v_acct_due_from IS NOT NULL AND v_acct_wallet IS NOT NULL AND v_acct_suspense IS NOT NULL THEN
                PERFORM app.assert_ledger_period_open(v_hq_entity_id, current_date);

                INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
                VALUES (v_hq_entity_id, current_date, 'wallet_card', p_card_id::text, 'activation_received',
                        'Health Pass activation booked at Head Office — provisional, pending revenue-recognition review')
                RETURNING id INTO v_hq_entry_id;

                INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                VALUES (v_hq_entry_id, v_acct_due_from, v_received, 0);

                IF v_bonus > 0 AND v_acct_bonus_expense IS NOT NULL THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_bonus_expense, v_bonus, 0);
                END IF;

                IF v_distributed > 0 AND v_acct_commission_exp IS NOT NULL THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_commission_exp, v_distributed, 0);
                END IF;

                INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                VALUES (v_hq_entry_id, v_acct_wallet, 0, v_amount + v_bonus);

                IF v_referral_commission > 0 THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_wallet, 0, v_referral_commission);
                END IF;

                IF v_distributed > 0 AND v_acct_agent_payable IS NOT NULL THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_agent_payable, 0, v_distributed);
                END IF;

                IF v_company_share > 0 AND v_acct_reserve_company IS NOT NULL THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_reserve_company, 0, v_company_share);
                END IF;

                IF v_reserve > 0 AND v_acct_reserve_pool IS NOT NULL THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_reserve_pool, 0, v_reserve);
                END IF;

                SELECT COALESCE(SUM(credit), 0) - COALESCE(SUM(debit), 0) INTO v_plug
                  FROM app.journal_line WHERE entry_id = v_hq_entry_id;

                IF v_plug > 0 THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_suspense, v_plug, 0);
                ELSIF v_plug < 0 THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_suspense, 0, -v_plug);
                END IF;

                PERFORM app.assert_journal_entry_balanced(v_hq_entry_id);
            END IF;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Head Office ledger posting skipped for wallet_card %: %', p_card_id, SQLERRM;
    END;

    RETURN QUERY SELECT p_card_id;
END;
$$ LANGUAGE plpgsql;
