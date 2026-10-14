-- ============================================================================
--  0091 · Subject on the two SQL-side posting functions
-- ============================================================================
--  Migration 0090 added journal_line.subject_type/subject_id and backfilled
--  history. This wires it into the two posting functions that still write
--  journal_line directly in PL/pgSQL (migration 0075) — both already resolve
--  the agent/member in a local variable at the exact point they insert, so
--  this is a pure "write it down" change, no new lookups:
--
--  - app.review_agent_withdrawal (PAY): the payable line is this withdrawal's
--    own agent (`a.id`, already SELECTed FOR UPDATE at the top).
--  - app.move_agent_earnings_to_wallet: posts to TWO person-bearing accounts
--    for the SAME underlying person — the payable line as 'agent'
--    (`p_agent_id`), the member-wallet line as 'member' (`a.member_id`,
--    already resolved to find/create the wallet). This is exactly why the
--    subject lives on journal_line, not journal_entry: one entry, two
--    different subject_types on its two lines.
--
--  Everything else about these two functions — the business logic, the
--  guard clauses, the error tolerance — is unchanged; only the two
--  `INSERT INTO app.journal_line` statements gain two columns each.
--
--  pg-mem has no PL/pgSQL support — verified live against the dev database,
--  same as migration 0075 itself.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0091_journal_line_subject_sql_functions.sql --yes
-- ============================================================================

SET search_path TO app, public;

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

                -- subject_type/subject_id added (migration 0091): this
                -- payable line is this one withdrawal's own agent.
                INSERT INTO app.journal_line (entry_id, account_id, debit, credit, subject_type, subject_id) VALUES
                    (v_entry_id, v_acct_payable, r.amount, 0, 'agent', a.id),
                    (v_entry_id, v_acct_cash_out, 0, r.amount, NULL, NULL);

                PERFORM app.assert_journal_entry_balanced(v_entry_id);
            END IF;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Ledger posting skipped for agent_withdrawal %: %', p_id, SQLERRM;
    END;
  END IF;
END $$;

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

              -- subject_type/subject_id added (migration 0091): same
              -- underlying person, two different roles on the two lines —
              -- the payable side is them as an agent, the wallet side is
              -- them as a member.
              INSERT INTO app.journal_line (entry_id, account_id, debit, credit, subject_type, subject_id) VALUES
                  (v_entry_id, v_acct_payable, p_amount, 0, 'agent', a.id),
                  (v_entry_id, v_acct_wallet, 0, p_amount, 'member', a.member_id);

              PERFORM app.assert_journal_entry_balanced(v_entry_id);
          END IF;
      END IF;
  EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Ledger posting skipped for wallet_entry %: %', v_wallet_entry_id, SQLERRM;
  END;

  RETURN v_balance;
END $$;
