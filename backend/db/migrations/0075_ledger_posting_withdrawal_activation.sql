-- ============================================================================
--  0075 · Ledger posting: agent withdrawals, "Add to wallet", and the
--         store's cash receipt on a Health Pass activation
-- ============================================================================
--  Adds real postings to three existing functions, each inside that
--  function's own transaction so the entry and the business change save
--  together or not at all. Deliberately scoped to what is unambiguous:
--
--  - app.review_agent_withdrawal (PAY): Dr agent commission payable,
--    Cr bank — a plain company-wide payout, no store involved.
--  - app.move_agent_earnings_to_wallet: Dr agent commission payable,
--    Cr member wallet liability — same company-wide money, moved to the
--    agent's own wallet instead of paid out.
--  - app.approve_wallet_card_activation: ONLY the store's own cash receipt
--    (Dr cash, Cr "due to head office"). The wallet credit, bonus, agent
--    commissions and reserves that function also writes are NOT posted
--    here — nothing in this schema ties a wallet, an agent or a reserve
--    entry to one shop (they are head-office-level money), and whether the
--    bonus/commission is a day-1 expense or a provision against future
--    margin is a revenue-recognition call for the accountant, not
--    something to guess at in a migration. That head-office-side entry is
--    its own later piece, once that policy is decided.
--
--  A ledger posting never blocks the real business change: each block is
--  wrapped in its own BEGIN/EXCEPTION, so an unconfigured entity or posting
--  rule is a RAISE WARNING, not a failed approval or payout. This mirrors
--  how `BackendSession`'s bridge in the Flutter apps rides alongside a
--  working path without blocking it.
--
--  pg-mem (this repo's e2e test double) has no PL/pgSQL support — these
--  three functions are verified live against the dev database instead, the
--  same way migration 0059's withdrawal functions already are.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0075_ledger_posting_withdrawal_activation.sql --yes
-- ============================================================================

SET search_path TO app, public;

-- ---- Head Office: the entity company-wide money (not tied to one shop) posts to

INSERT INTO app.legal_entity (code, name, is_provisional)
VALUES ('HQ', 'Head Office (provisional)', true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO app.chart_of_account (code, name, type) VALUES
    ('2006', 'Due to Head Office (clearing) — provisional', 'LIABILITY'),
    ('1004', 'Due from store (clearing) — provisional',     'ASSET')
ON CONFLICT (code) DO NOTHING;

INSERT INTO app.posting_rule (event, line_role, account_code) VALUES
    ('activation_received', 'due_to_head_office', '2006')
ON CONFLICT (event, line_role) DO NOTHING;

-- Looks an account up by (event, line_role) instead of a posting function
-- hardcoding the account id, so remapping an account is a posting_rule
-- UPDATE, not a new migration. Returns null — not an error — when nothing
-- is mapped yet, so a posting function can treat that as "not configured"
-- and skip, rather than fail.
CREATE OR REPLACE FUNCTION app.ledger_account(p_event text, p_line_role text) RETURNS bigint AS $$
    SELECT ca.id FROM app.posting_rule pr
    JOIN app.chart_of_account ca ON ca.code = pr.account_code
    WHERE pr.event = p_event AND pr.line_role = p_line_role;
$$ LANGUAGE sql STABLE;

-- ---- app.review_agent_withdrawal: post on PAY --------------------------------

CREATE OR REPLACE FUNCTION app.review_agent_withdrawal(
  p_id bigint, p_action text, p_reviewer text, p_account text,
  p_identity_verified boolean, p_earnings_verified boolean,
  p_note text, p_payment_reference text
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  r app.agent_withdrawal%ROWTYPE;
  a app.agent%ROWTYPE;
  held numeric;
  v_hq_entity_id bigint;
  v_entry_id uuid;
  v_acct_payable bigint;
  v_acct_cash_out bigint;
BEGIN
  SELECT * INTO r FROM app.agent_withdrawal WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Withdrawal request not found'; END IF;
  SELECT * INTO a FROM app.agent WHERE id = r.agent_id FOR UPDATE;
  SELECT * INTO r FROM app.agent_withdrawal WHERE id = p_id FOR UPDATE;
  IF r.status <> 'PENDING' THEN RAISE EXCEPTION 'This request is already processed'; END IF;
  IF coalesce(trim(p_reviewer), '') = '' THEN RAISE EXCEPTION 'Reviewer is required'; END IF;
  IF p_action = 'REJECT' THEN
    IF coalesce(trim(p_note), '') = '' THEN RAISE EXCEPTION 'Enter a rejection reason'; END IF;
    UPDATE app.agent_withdrawal SET status = 'REJECTED', processed_on = current_date,
      processed_by = p_reviewer, verification_note = trim(p_note) WHERE id = p_id;
    RETURN;
  END IF;
  IF p_action NOT IN ('APPROVE', 'PAY') THEN RAISE EXCEPTION 'Invalid review action'; END IF;
  SELECT coalesce(sum(amount), 0) INTO held FROM app.agent_withdrawal
    WHERE agent_id = a.id AND status = 'PENDING';
  IF a.approval_status <> 'APPROVED' OR NOT a.active OR r.amount < 3000
     OR held > a.earned - a.redeemed THEN
    RAISE EXCEPTION 'Agent eligibility or available earnings changed; recheck this request';
  END IF;
  IF p_action = 'APPROVE' THEN
    IF r.approved_at IS NOT NULL THEN RAISE EXCEPTION 'Request is already approved'; END IF;
    IF p_identity_verified IS DISTINCT FROM true OR p_earnings_verified IS DISTINCT FROM true
       OR coalesce(trim(p_account), '') = '' OR trim(p_account) <> trim(a.account_number)
       OR coalesce(trim(p_note), '') = '' THEN
      RAISE EXCEPTION 'Verify identity, earnings and the matching bank account; enter your review note';
    END IF;
    UPDATE app.agent_withdrawal SET approved_at = now(), approved_by = p_reviewer,
      verified_account = trim(p_account), verification_note = trim(p_note) WHERE id = p_id;
  ELSE
    IF r.approved_at IS NULL THEN RAISE EXCEPTION 'Approve the request before recording payment'; END IF;
    IF r.verified_account IS DISTINCT FROM trim(a.account_number) THEN
      RAISE EXCEPTION 'Bank account changed after approval; reject and request again';
    END IF;
    IF coalesce(trim(p_payment_reference), '') = '' THEN RAISE EXCEPTION 'Payment reference is required'; END IF;
    UPDATE app.agent SET redeemed = redeemed + r.amount WHERE id = a.id;
    UPDATE app.agent_withdrawal SET status = 'PAID', processed_on = current_date,
      processed_by = p_reviewer, payment_reference = trim(p_payment_reference) WHERE id = p_id;

    -- ---- ledger posting (migration 0075; provisional) ----------------------
    BEGIN
        SELECT id INTO v_hq_entity_id FROM app.legal_entity WHERE code = 'HQ';
        IF v_hq_entity_id IS NOT NULL THEN
            v_acct_payable := app.ledger_account('withdrawal_paid', 'payable');
            v_acct_cash_out := app.ledger_account('withdrawal_paid', 'cash_out');
            IF v_acct_payable IS NOT NULL AND v_acct_cash_out IS NOT NULL THEN
                PERFORM app.assert_ledger_period_open(v_hq_entity_id, current_date);

                INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
                VALUES (v_hq_entity_id, current_date, 'agent_withdrawal', p_id::text, 'withdrawal_paid',
                        'Agent withdrawal paid - ' || a.code)
                RETURNING id INTO v_entry_id;

                INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES
                    (v_entry_id, v_acct_payable, r.amount, 0),
                    (v_entry_id, v_acct_cash_out, 0, r.amount);

                PERFORM app.assert_journal_entry_balanced(v_entry_id);
            END IF;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Ledger posting skipped for agent_withdrawal %: %', p_id, SQLERRM;
    END;
  END IF;
END $$;

-- ---- app.move_agent_earnings_to_wallet: post every transfer ------------------

CREATE OR REPLACE FUNCTION app.move_agent_earnings_to_wallet(p_agent_id bigint, p_amount numeric)
RETURNS numeric LANGUAGE plpgsql AS $$
DECLARE
  a app.agent%ROWTYPE;
  held numeric;
  v_wallet_id bigint;
  v_balance numeric;
  v_wallet_entry_id bigint;
  v_hq_entity_id bigint;
  v_entry_id uuid;
  v_acct_payable bigint;
  v_acct_wallet bigint;
BEGIN
  SELECT * INTO a FROM app.agent WHERE id = p_agent_id FOR UPDATE;
  IF NOT FOUND OR a.approval_status <> 'APPROVED' OR NOT a.active THEN
    RAISE EXCEPTION 'Only an active approved agent can add earnings to a wallet';
  END IF;
  IF a.member_id IS NULL THEN
    RAISE EXCEPTION 'This agent has no member account to hold a wallet';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount <> round(p_amount, 2) THEN
    RAISE EXCEPTION 'Enter a valid amount to add';
  END IF;
  SELECT coalesce(sum(amount), 0) INTO held FROM app.agent_withdrawal
    WHERE agent_id = a.id AND status = 'PENDING';
  IF p_amount > a.earned - a.redeemed - held THEN
    RAISE EXCEPTION 'Amount exceeds your available earnings after pending withdrawals';
  END IF;

  SELECT id INTO v_wallet_id FROM app.wallet WHERE member_id = a.member_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    INSERT INTO app.wallet (member_id) VALUES (a.member_id) RETURNING id INTO v_wallet_id;
  END IF;

  UPDATE app.agent SET redeemed = redeemed + p_amount WHERE id = a.id;
  INSERT INTO app.wallet_entry (wallet_id, kind, label, amount, occurred_on)
    VALUES (v_wallet_id, 'AGENT_EARNINGS', 'Agent commission · ' || a.code, p_amount, current_date)
    RETURNING id INTO v_wallet_entry_id;
  UPDATE app.wallet SET balance = balance + p_amount, updated_at = now()
    WHERE id = v_wallet_id RETURNING balance INTO v_balance;

  -- ---- ledger posting (migration 0075; provisional) ------------------------
  BEGIN
      SELECT id INTO v_hq_entity_id FROM app.legal_entity WHERE code = 'HQ';
      IF v_hq_entity_id IS NOT NULL THEN
          v_acct_payable := app.ledger_account('wallet_transfer', 'payable');
          v_acct_wallet := app.ledger_account('wallet_transfer', 'member_wallet');
          IF v_acct_payable IS NOT NULL AND v_acct_wallet IS NOT NULL THEN
              PERFORM app.assert_ledger_period_open(v_hq_entity_id, current_date);

              INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
              VALUES (v_hq_entity_id, current_date, 'wallet_entry', v_wallet_entry_id::text, 'wallet_transfer',
                      'Agent earnings moved to wallet - ' || a.code)
              RETURNING id INTO v_entry_id;

              INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES
                  (v_entry_id, v_acct_payable, p_amount, 0),
                  (v_entry_id, v_acct_wallet, 0, p_amount);

              PERFORM app.assert_journal_entry_balanced(v_entry_id);
          END IF;
      END IF;
  EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Ledger posting skipped for wallet_entry %: %', v_wallet_entry_id, SQLERRM;
  END;

  RETURN v_balance;
END $$;

-- ---- app.approve_wallet_card_activation: post the store's cash receipt only --

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

    RETURN QUERY SELECT p_card_id;
END;
$$ LANGUAGE plpgsql;
