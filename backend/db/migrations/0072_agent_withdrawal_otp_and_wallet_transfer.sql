-- ============================================================================
--  0072 · Agent withdrawal OTP audit trail + durable "Add to wallet"
-- ============================================================================
--  1. app.agent_withdrawal records WHEN an admin proved they were talking to
--     the agent (a Firebase phone OTP sent to the agent's registered number)
--     before approving, and which number was verified. The check itself is
--     enforced by backend/api (agent.service.ts resolveWithdrawal) — the
--     columns are the audit trail written in the same transaction as the
--     approval.
--
--  2. app.move_agent_earnings_to_wallet(agent, amount) — the agent portal's
--     "Add to wallet" used to be session-only memory in the Flutter app (the
--     money reappeared as withdrawable after a restart and never reached
--     app.wallet). It is now one atomic step: lock the agent, check the
--     amount against earned - redeemed - pending withdrawals, raise
--     `redeemed`, and credit the member's wallet with an AGENT_EARNINGS
--     ledger line plus the balance.
--
--  No historical balances are changed. Idempotent — safe to run twice:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0072_agent_withdrawal_otp_and_wallet_transfer.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.agent_withdrawal
  ADD COLUMN IF NOT EXISTS otp_verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS otp_verified_phone text;

CREATE OR REPLACE FUNCTION app.move_agent_earnings_to_wallet(p_agent_id bigint, p_amount numeric)
RETURNS numeric LANGUAGE plpgsql AS $$
DECLARE
  a app.agent%ROWTYPE;
  held numeric;
  v_wallet_id bigint;
  v_balance numeric;
BEGIN
  -- The agent row is the lock: a withdrawal request, a review and a wallet
  -- move for the same agent all serialize on it.
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
    VALUES (v_wallet_id, 'AGENT_EARNINGS', 'Agent commission · ' || a.code, p_amount, current_date);
  UPDATE app.wallet SET balance = balance + p_amount, updated_at = now()
    WHERE id = v_wallet_id RETURNING balance INTO v_balance;
  RETURN v_balance;
END $$;
