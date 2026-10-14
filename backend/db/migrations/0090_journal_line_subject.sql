-- ============================================================================
--  0090 · A subject on every journal line, and the historical backfill
-- ============================================================================
--  `app.journal_line` (where every Debit/Credit actually lives) has no
--  person column at all today — only `account_id`. This adds one: a bare
--  (subject_type, subject_id) pair, since one line can only ever belong to
--  one person. Nullable by design — store-level lines (cash in, revenue,
--  discounts, reserves) have no person and stay NULL.
--
--  Then backfills every existing journal_line on a person-bearing account
--  (2001 member wallet, 2002 agent commission payable, 2003 reward points
--  liability), tracing back through journal_entry.source_table/source_id to
--  the member/agent the entry's own business row belongs to — see the join
--  paths below, each confirmed against backend/db/app_schema.sql this
--  session. Only wallet_card's agent side needs more than a plain join (its
--  sold_by_agent_id is nullable, falling back to an agent_customer lookup —
--  the exact same COALESCE approve_wallet_card_activation itself already
--  uses), so that one is its own block.
--
--  Safe to re-run: every UPDATE below only touches rows where subject_id is
--  still NULL.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0090_journal_line_subject.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.journal_line
    ADD COLUMN IF NOT EXISTS subject_type text
        CHECK (subject_type IS NULL OR subject_type IN ('member', 'agent', 'investor')),
    ADD COLUMN IF NOT EXISTS subject_id   bigint;

CREATE INDEX IF NOT EXISTS journal_line_subject_idx
    ON app.journal_line(subject_type, subject_id, account_id);

-- ---- 2001 member wallet liability ------------------------------------------

-- via wallet_card (activation_received's Head Office 'member_wallet' line)
UPDATE app.journal_line jl
SET subject_type = 'member', subject_id = w.member_id
FROM app.journal_entry je
JOIN app.chart_of_account ca ON ca.id = jl.account_id
JOIN app.wallet_card wc ON wc.id = je.source_id::bigint
JOIN app.wallet w ON w.id = wc.wallet_id
WHERE jl.entry_id = je.id
  AND ca.code = '2001'
  AND je.source_table = 'wallet_card'
  AND jl.subject_id IS NULL;

-- via bill (order_collected's 'wallet_in' line — OrderService.postOrderCollection
-- writes source_id as "<orderId>-<random>", the order id is the part before
-- the dash; sourceTable is 'bill' but no bill row needs to be reached)
UPDATE app.journal_line jl
SET subject_type = 'member', subject_id = o.member_id
FROM app.journal_entry je
JOIN app.chart_of_account ca ON ca.id = jl.account_id
JOIN app."order" o ON o.id = split_part(je.source_id, '-', 1)::bigint
WHERE jl.entry_id = je.id
  AND ca.code = '2001'
  AND je.source_table = 'bill'
  AND jl.subject_id IS NULL;

-- via lab_bill (lab_bill_collected's 'wallet_in' line — booking.service.ts's
-- postLabBillCollection writes source_id as the plain booking id, no suffix)
UPDATE app.journal_line jl
SET subject_type = 'member', subject_id = lb.member_id
FROM app.journal_entry je
JOIN app.chart_of_account ca ON ca.id = jl.account_id
JOIN app.lab_booking lb ON lb.id = je.source_id::bigint
WHERE jl.entry_id = je.id
  AND ca.code = '2001'
  AND je.source_table = 'lab_bill'
  AND jl.subject_id IS NULL;

-- via reward_point_transaction (reward_points_redeemed's 'member_wallet' line,
-- and wallet_transfer's 'member_wallet' line, resolved via wallet_entry below)
UPDATE app.journal_line jl
SET subject_type = 'member', subject_id = rpt.member_id
FROM app.journal_entry je
JOIN app.chart_of_account ca ON ca.id = jl.account_id
JOIN app.reward_point_transaction rpt ON rpt.id = je.source_id::bigint
WHERE jl.entry_id = je.id
  AND ca.code = '2001'
  AND je.source_table = 'reward_point_transaction'
  AND jl.subject_id IS NULL;

-- via wallet_entry (wallet_transfer's 'member_wallet' line — an agent's own
-- earnings moved into their own member wallet; the subject is that same
-- person, as a member, on this specific line)
UPDATE app.journal_line jl
SET subject_type = 'member', subject_id = w.member_id
FROM app.journal_entry je
JOIN app.chart_of_account ca ON ca.id = jl.account_id
JOIN app.wallet_entry we ON we.id = je.source_id::bigint
JOIN app.wallet w ON w.id = we.wallet_id
WHERE jl.entry_id = je.id
  AND ca.code = '2001'
  AND je.source_table = 'wallet_entry'
  AND jl.subject_id IS NULL;

-- ---- 2003 reward points liability ------------------------------------------

UPDATE app.journal_line jl
SET subject_type = 'member', subject_id = rpt.member_id
FROM app.journal_entry je
JOIN app.chart_of_account ca ON ca.id = jl.account_id
JOIN app.reward_point_transaction rpt ON rpt.id = je.source_id::bigint
WHERE jl.entry_id = je.id
  AND ca.code = '2003'
  AND je.source_table = 'reward_point_transaction'
  AND jl.subject_id IS NULL;

-- ---- 2002 agent commission payable -----------------------------------------

-- via agent_withdrawal (withdrawal_paid's 'payable' line) — direct FK
UPDATE app.journal_line jl
SET subject_type = 'agent', subject_id = aw.agent_id
FROM app.journal_entry je
JOIN app.chart_of_account ca ON ca.id = jl.account_id
JOIN app.agent_withdrawal aw ON aw.id = je.source_id::bigint
WHERE jl.entry_id = je.id
  AND ca.code = '2002'
  AND je.source_table = 'agent_withdrawal'
  AND jl.subject_id IS NULL;

-- via wallet_entry (wallet_transfer's 'payable' line — the agent's own
-- earnings being moved; the agent is found by reversing member_id -> agent)
UPDATE app.journal_line jl
SET subject_type = 'agent', subject_id = a.id
FROM app.journal_entry je
JOIN app.chart_of_account ca ON ca.id = jl.account_id
JOIN app.wallet_entry we ON we.id = je.source_id::bigint
JOIN app.wallet w ON w.id = we.wallet_id
JOIN app.agent a ON a.member_id = w.member_id
WHERE jl.entry_id = je.id
  AND ca.code = '2002'
  AND je.source_table = 'wallet_entry'
  AND jl.subject_id IS NULL;

-- via wallet_card (activation_received's combined 'agent_commission' line) —
-- this line is a MULTI-agent total (migration 0076 posts one combined
-- figure for every agent the activation credited), so it cannot carry one
-- subject_id. Left NULL here on purpose; a per-agent breakdown for these
-- historical rows comes from app.agent_commission (migration 0079) joined
-- on journal_entry_id instead, exactly as LedgerService.agentCommissions
-- already reads it. Going forward (this migration's TypeScript-side
-- companion change), a newly posted activation splits this line per agent
-- instead of combining it, so this gap only applies to pre-existing rows.
