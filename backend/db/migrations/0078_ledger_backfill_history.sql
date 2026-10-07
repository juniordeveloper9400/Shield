-- ============================================================================
--  0078 · Ledger backfill: history from before migrations 0074–0077
-- ============================================================================
--  Everything posted by migrations 0075–0077 only covers transactions from
--  after they went live. This backfills what happened before, using the
--  exact figures already on record — commission_reserve_entry's historical
--  COMPANY_SHARE/POOL_LEFTOVER rows, wallet_entry's historical
--  REFERRAL_EARNINGS rows — rather than recomputing percentages against
--  data that may since have changed.
--
--  What this does NOT reconstruct, by design, not oversight:
--    - The agent commission PAYABLE split for an old activation (which
--      agents got how much of the 10% pool). app.agent.earned is only a
--      running total; there is no historical per-activation row to read
--      it back from. The gap lands in Suspense, same as every other
--      unexplained amount on the Head Office side — correctly reflecting
--      "we don't have a reliable source for this piece," not a guess.
--    - Agent withdrawals: none are PAID yet in this database as of writing
--      this migration, so there is nothing to backfill there. If some
--      exist by the time this runs, they backfill the same way
--      0075's PAY branch posts live (Dr payable / Cr bank).
--    - Wallet-transfer ("Add to wallet") history: wallet_entry rows exist
--      (kind = 'AGENT_EARNINGS') but carry no link back to which agent or
--      which request moved the money, so a backfill here could not be
--      verified against anything. Left undone rather than guessed.
--
--  Bills/lab bills already PAID backfill as ONE lump entry each, dated at
--  paid_at, from the bill's own final cash_collected/gpay_collected/
--  wallet_collected totals — the only granularity this data actually has;
--  any earlier partial-payment split is not recoverable.
--
--  Every block is idempotent: guarded by the same
--  (source_table, source_id, event, entity_id) uniqueness migration 0074
--  already enforces, so re-running this migration posts nothing twice.
--  Each row is wrapped in its own exception handler — one bad historical
--  row is skipped and logged (RAISE WARNING), not fatal to the backfill.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0078_ledger_backfill_history.sql --yes
-- ============================================================================

SET search_path TO app, public;

-- ---- 1. Activations already approved -----------------------------------------

DO $$
DECLARE
    r RECORD;
    v_received        numeric(12,2);
    v_entity_id       bigint;
    v_entry_id        uuid;
    v_acct_cash       bigint;
    v_acct_due        bigint;
    v_hq_entity_id    bigint;
    v_hq_entry_id     uuid;
    v_acct_due_from   bigint;
    v_acct_wallet     bigint;
    v_acct_reserve_co bigint;
    v_acct_reserve_po bigint;
    v_acct_suspense   bigint;
    v_company_share   numeric(12,2);
    v_pool_leftover   numeric(12,2);
    v_referral_amt    numeric(12,2);
    v_plug            numeric(12,2);
    v_posted_date     date;
BEGIN
    SELECT id INTO v_hq_entity_id FROM app.legal_entity WHERE code = 'HQ';

    FOR r IN
        SELECT wc.id, wc.store_id, wc.amount, wc.bonus, wc.received_amount, wc.reviewed_at, wc.issued_on
        FROM app.wallet_card wc
        WHERE wc.status = 'APPROVED'
    LOOP
        BEGIN
            v_posted_date := COALESCE(r.reviewed_at::date, r.issued_on, current_date);
            v_received := COALESCE(r.received_amount, r.amount);

            -- Store side.
            IF r.store_id IS NOT NULL AND v_received > 0 THEN
                SELECT s.entity_id INTO v_entity_id FROM app.shield_store s WHERE s.id = r.store_id;
                IF v_entity_id IS NOT NULL
                   AND NOT EXISTS (
                       SELECT 1 FROM app.journal_entry je
                       WHERE je.source_table = 'wallet_card' AND je.source_id = r.id::text
                         AND je.event = 'activation_received' AND je.entity_id = v_entity_id
                   ) THEN
                    v_acct_cash := app.ledger_account('activation_received', 'cash_in');
                    v_acct_due  := app.ledger_account('activation_received', 'due_to_head_office');
                    IF v_acct_cash IS NOT NULL AND v_acct_due IS NOT NULL THEN
                        INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
                        VALUES (v_entity_id, v_posted_date, 'wallet_card', r.id::text, 'activation_received',
                                'Health Pass activation received at store (backfilled)')
                        RETURNING id INTO v_entry_id;
                        INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES
                            (v_entry_id, v_acct_cash, v_received, 0),
                            (v_entry_id, v_acct_due, 0, v_received);
                        PERFORM app.assert_journal_entry_balanced(v_entry_id);
                    END IF;
                END IF;
            END IF;

            -- Head Office side.
            IF v_hq_entity_id IS NOT NULL
               AND NOT EXISTS (
                   SELECT 1 FROM app.journal_entry je
                   WHERE je.source_table = 'wallet_card' AND je.source_id = r.id::text
                     AND je.event = 'activation_received' AND je.entity_id = v_hq_entity_id
               ) THEN
                v_acct_due_from   := app.ledger_account('activation_received', 'due_from_store');
                v_acct_wallet     := app.ledger_account('activation_received', 'member_wallet');
                v_acct_reserve_co := app.ledger_account('activation_received', 'reserve_company');
                v_acct_reserve_po := app.ledger_account('activation_received', 'reserve_pool');
                v_acct_suspense   := app.ledger_account('activation_received', 'suspense');

                IF v_acct_due_from IS NOT NULL AND v_acct_wallet IS NOT NULL AND v_acct_suspense IS NOT NULL THEN
                    SELECT COALESCE(SUM(amount), 0) INTO v_company_share
                      FROM app.commission_reserve_entry WHERE wallet_card_id = r.id AND source = 'COMPANY_SHARE';
                    SELECT COALESCE(SUM(amount), 0) INTO v_pool_leftover
                      FROM app.commission_reserve_entry WHERE wallet_card_id = r.id AND source = 'POOL_LEFTOVER';
                    SELECT COALESCE(SUM(amount), 0) INTO v_referral_amt
                      FROM app.wallet_entry WHERE wallet_card_id = r.id AND kind = 'REFERRAL_EARNINGS';

                    INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
                    VALUES (v_hq_entity_id, v_posted_date, 'wallet_card', r.id::text, 'activation_received',
                            'Health Pass activation booked at Head Office (backfilled) — provisional, pending revenue-recognition review')
                    RETURNING id INTO v_hq_entry_id;

                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_due_from, v_received, 0);

                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_wallet, 0, r.amount + r.bonus);

                    IF v_referral_amt > 0 THEN
                        INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                        VALUES (v_hq_entry_id, v_acct_wallet, 0, v_referral_amt);
                    END IF;
                    IF v_company_share > 0 AND v_acct_reserve_co IS NOT NULL THEN
                        INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                        VALUES (v_hq_entry_id, v_acct_reserve_co, 0, v_company_share);
                    END IF;
                    IF v_pool_leftover > 0 AND v_acct_reserve_po IS NOT NULL THEN
                        INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                        VALUES (v_hq_entry_id, v_acct_reserve_po, 0, v_pool_leftover);
                    END IF;

                    -- Everything else this activation's figures don't
                    -- explain (bonus, agent commissions actually paid,
                    -- rounding) — same Suspense treatment as the live
                    -- function, computed the same way: whatever balances it.
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
            RAISE WARNING 'Backfill skipped for wallet_card %: %', r.id, SQLERRM;
        END;
    END LOOP;
END $$;

-- ---- 2. Reward points already issued or redeemed ------------------------------

DO $$
DECLARE
    r RECORD;
    v_hq_entity_id   bigint;
    v_entry_id       uuid;
    v_acct_a         bigint;
    v_acct_b         bigint;
    v_rupees         numeric(12,2);
    v_event          text;
BEGIN
    SELECT id INTO v_hq_entity_id FROM app.legal_entity WHERE code = 'HQ';
    IF v_hq_entity_id IS NULL THEN RETURN; END IF;

    FOR r IN SELECT id, points, reason, created_at FROM app.reward_point_transaction LOOP
        BEGIN
            v_event := CASE WHEN r.points >= 0 THEN 'reward_points_issued' ELSE 'reward_points_redeemed' END;
            IF NOT EXISTS (
                SELECT 1 FROM app.journal_entry je
                WHERE je.source_table = 'reward_point_transaction' AND je.source_id = r.id::text
                  AND je.event = v_event AND je.entity_id = v_hq_entity_id
            ) THEN
                IF v_event = 'reward_points_issued' THEN
                    v_acct_a := app.ledger_account('reward_points_issued', 'expense');
                    v_acct_b := app.ledger_account('reward_points_issued', 'liability');
                ELSE
                    v_acct_a := app.ledger_account('reward_points_redeemed', 'liability');
                    v_acct_b := app.ledger_account('reward_points_redeemed', 'member_wallet');
                END IF;

                IF v_acct_a IS NOT NULL AND v_acct_b IS NOT NULL AND r.points <> 0 THEN
                    v_rupees := ROUND(ABS(r.points) / 100.0, 2);
                    INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
                    VALUES (v_hq_entity_id, r.created_at::date, 'reward_point_transaction', r.id::text, v_event,
                            ABS(r.points) || ' reward points — ' || r.reason || ' (backfilled)')
                    RETURNING id INTO v_entry_id;
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES
                        (v_entry_id, v_acct_a, v_rupees, 0),
                        (v_entry_id, v_acct_b, 0, v_rupees);
                    PERFORM app.assert_journal_entry_balanced(v_entry_id);
                END IF;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Backfill skipped for reward_point_transaction %: %', r.id, SQLERRM;
        END;
    END LOOP;
END $$;

-- ---- 3. Shop bills already PAID (one lump entry per bill, final totals) ------

DO $$
DECLARE
    r RECORD;
    v_entity_id   bigint;
    v_entry_id    uuid;
    v_acct_cash   bigint;
    v_acct_wallet bigint;
    v_acct_rev    bigint;
    v_received    numeric(12,2);
BEGIN
    FOR r IN
        SELECT b.id, b.order_id, o.store_id, o.code,
               COALESCE(b.cash_collected, 0) + COALESCE(b.gpay_collected, 0) AS cash_in,
               COALESCE(b.wallet_collected, 0) AS wallet_in, b.paid_at
        FROM app.bill b JOIN app."order" o ON o.id = b.order_id
        WHERE b.status = 'PAID'
    LOOP
        BEGIN
            IF r.store_id IS NULL THEN CONTINUE; END IF;
            SELECT s.entity_id INTO v_entity_id FROM app.shield_store s WHERE s.id = r.store_id;
            IF v_entity_id IS NULL THEN CONTINUE; END IF;
            IF EXISTS (
                SELECT 1 FROM app.journal_entry je
                WHERE je.source_table = 'bill' AND je.source_id = r.id::text AND je.event = 'order_collected'
            ) THEN CONTINUE; END IF;

            v_acct_cash   := app.ledger_account('order_collected', 'cash_in');
            v_acct_wallet := app.ledger_account('order_collected', 'wallet_in');
            v_acct_rev    := app.ledger_account('order_collected', 'revenue');
            IF v_acct_cash IS NULL OR v_acct_wallet IS NULL OR v_acct_rev IS NULL THEN CONTINUE; END IF;

            v_received := r.cash_in + r.wallet_in;
            IF v_received <= 0 THEN CONTINUE; END IF;

            INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
            VALUES (v_entity_id, COALESCE(r.paid_at::date, current_date), 'bill', r.id::text, 'order_collected',
                    'Order ' || r.code || ' collected (backfilled, final totals only)')
            RETURNING id INTO v_entry_id;

            IF r.cash_in > 0 THEN
                INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES (v_entry_id, v_acct_cash, r.cash_in, 0);
            END IF;
            IF r.wallet_in > 0 THEN
                INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES (v_entry_id, v_acct_wallet, r.wallet_in, 0);
            END IF;
            INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES (v_entry_id, v_acct_rev, 0, v_received);

            PERFORM app.assert_journal_entry_balanced(v_entry_id);
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Backfill skipped for bill %: %', r.id, SQLERRM;
        END;
    END LOOP;
END $$;

-- ---- 4. Lab bills already PAID (same shape) -----------------------------------

DO $$
DECLARE
    r RECORD;
    v_entity_id   bigint;
    v_entry_id    uuid;
    v_acct_cash   bigint;
    v_acct_wallet bigint;
    v_acct_rev    bigint;
    v_received    numeric(12,2);
BEGIN
    FOR r IN
        SELECT lb.id, lb.lab_booking_id, lk.store_id,
               COALESCE(lb.cash_collected, 0) AS cash_in,
               COALESCE(lb.wallet_collected, 0) AS wallet_in, lb.paid_at
        FROM app.lab_bill lb JOIN app.lab_booking lk ON lk.id = lb.lab_booking_id
        WHERE lb.status = 'PAID'
    LOOP
        BEGIN
            IF r.store_id IS NULL THEN CONTINUE; END IF;
            SELECT s.entity_id INTO v_entity_id FROM app.shield_store s WHERE s.id = r.store_id;
            IF v_entity_id IS NULL THEN CONTINUE; END IF;
            IF EXISTS (
                SELECT 1 FROM app.journal_entry je
                WHERE je.source_table = 'lab_bill' AND je.source_id = r.id::text AND je.event = 'lab_bill_collected'
            ) THEN CONTINUE; END IF;

            v_acct_cash   := app.ledger_account('lab_bill_collected', 'cash_in');
            v_acct_wallet := app.ledger_account('lab_bill_collected', 'wallet_in');
            v_acct_rev    := app.ledger_account('lab_bill_collected', 'revenue');
            IF v_acct_cash IS NULL OR v_acct_wallet IS NULL OR v_acct_rev IS NULL THEN CONTINUE; END IF;

            v_received := r.cash_in + r.wallet_in;
            IF v_received <= 0 THEN CONTINUE; END IF;

            INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
            VALUES (v_entity_id, COALESCE(r.paid_at::date, current_date), 'lab_bill', r.id::text, 'lab_bill_collected',
                    'Lab booking LB-' || lpad(r.lab_booking_id::text, 4, '0') || ' collected (backfilled, final totals only)')
            RETURNING id INTO v_entry_id;

            IF r.cash_in > 0 THEN
                INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES (v_entry_id, v_acct_cash, r.cash_in, 0);
            END IF;
            IF r.wallet_in > 0 THEN
                INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES (v_entry_id, v_acct_wallet, r.wallet_in, 0);
            END IF;
            INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES (v_entry_id, v_acct_rev, 0, v_received);

            PERFORM app.assert_journal_entry_balanced(v_entry_id);
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Backfill skipped for lab_bill %: %', r.id, SQLERRM;
        END;
    END LOOP;
END $$;

-- ---- 5. Agent withdrawals already PAID (none exist as of writing this) -------

DO $$
DECLARE
    r RECORD;
    v_hq_entity_id  bigint;
    v_entry_id      uuid;
    v_acct_payable  bigint;
    v_acct_cash_out bigint;
BEGIN
    SELECT id INTO v_hq_entity_id FROM app.legal_entity WHERE code = 'HQ';
    IF v_hq_entity_id IS NULL THEN RETURN; END IF;

    FOR r IN SELECT id, amount, processed_on, agent_id FROM app.agent_withdrawal WHERE status = 'PAID' LOOP
        BEGIN
            IF EXISTS (
                SELECT 1 FROM app.journal_entry je
                WHERE je.source_table = 'agent_withdrawal' AND je.source_id = r.id::text AND je.event = 'withdrawal_paid'
            ) THEN CONTINUE; END IF;

            v_acct_payable  := app.ledger_account('withdrawal_paid', 'payable');
            v_acct_cash_out := app.ledger_account('withdrawal_paid', 'cash_out');
            IF v_acct_payable IS NULL OR v_acct_cash_out IS NULL THEN CONTINUE; END IF;

            INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
            VALUES (v_hq_entity_id, COALESCE(r.processed_on, current_date), 'agent_withdrawal', r.id::text, 'withdrawal_paid',
                    'Agent withdrawal paid (backfilled)')
            RETURNING id INTO v_entry_id;
            INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES
                (v_entry_id, v_acct_payable, r.amount, 0),
                (v_entry_id, v_acct_cash_out, 0, r.amount);
            PERFORM app.assert_journal_entry_balanced(v_entry_id);
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Backfill skipped for agent_withdrawal %: %', r.id, SQLERRM;
        END;
    END LOOP;
END $$;
