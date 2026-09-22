-- Durable agent withdrawals. No historical payouts or balances are changed.
ALTER TABLE app.agent_withdrawal
  ADD COLUMN IF NOT EXISTS approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS approved_by text,
  ADD COLUMN IF NOT EXISTS verified_account text,
  ADD COLUMN IF NOT EXISTS verification_note text,
  ADD COLUMN IF NOT EXISTS payment_reference text,
  ADD COLUMN IF NOT EXISTS processed_by text;

CREATE OR REPLACE FUNCTION app.request_agent_withdrawal(p_agent_id bigint, p_amount numeric)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE a app.agent%ROWTYPE; held numeric; request_id bigint;
BEGIN
  SELECT * INTO a FROM app.agent WHERE id = p_agent_id FOR UPDATE;
  IF NOT FOUND OR a.approval_status <> 'APPROVED' OR NOT a.active THEN
    RAISE EXCEPTION 'Only an active approved agent can withdraw';
  END IF;
  IF p_amount IS NULL OR p_amount < 3000 OR p_amount <> round(p_amount, 2) THEN
    RAISE EXCEPTION 'Minimum withdrawal is Rs 3000; enter a valid amount';
  END IF;
  SELECT coalesce(sum(amount), 0) INTO held FROM app.agent_withdrawal
    WHERE agent_id = a.id AND status = 'PENDING';
  IF p_amount > a.earned - a.redeemed - held THEN
    RAISE EXCEPTION 'Amount exceeds available earnings after pending requests';
  END IF;
  IF trim(a.account_number) = '' THEN
    RAISE EXCEPTION 'Add your bank account before requesting a withdrawal';
  END IF;
  INSERT INTO app.agent_withdrawal(agent_id, amount) VALUES(a.id, p_amount)
    RETURNING id INTO request_id;
  RETURN request_id;
END $$;

-- APPROVE holds the existing reservation; PAY alone increases redeemed.
-- Both entry points lock the agent first, serializing requests and decisions.
CREATE OR REPLACE FUNCTION app.review_agent_withdrawal(
  p_id bigint, p_action text, p_reviewer text, p_account text,
  p_identity_verified boolean, p_earnings_verified boolean,
  p_note text, p_payment_reference text
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE r app.agent_withdrawal%ROWTYPE; a app.agent%ROWTYPE; held numeric;
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
  END IF;
END $$;
