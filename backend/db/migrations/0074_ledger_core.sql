-- ============================================================================
--  0074 · Ledger core: legal entities, chart of accounts, journal
-- ============================================================================
--  The company's money today is tracked as separate rows per module — wallet
--  entries, commission reserve entries, agent earnings, bills — with no place
--  that says "this money moved from this account to that one". This adds a
--  real double-entry journal underneath those existing tables, without
--  changing any of them.
--
--  Each shop is treated as its own legal entity: every journal entry belongs
--  to exactly one `legal_entity`, via `shield_store.entity_id`. One
--  provisional entity is created per existing store below, so today's stores
--  keep working with no further setup. An accountant has not yet reviewed
--  the chart of accounts or the account each event posts to — both
--  `chart_of_account` and `posting_rule` carry an `is_provisional` flag for
--  exactly that reason. Renaming or remapping an account later is a data
--  change to these two tables, not a code change.
--
--  Deliberately no database trigger enforces that an entry balances or that
--  a period is closed — pg-mem (this repo's e2e test double) does not run
--  this file's triggers the way the real database does, and every other
--  business rule in this schema is already enforced by the calling function
--  instead (see wallet.service.ts's own approval guards). The two guard
--  functions below (`assert_journal_entry_balanced`,
--  `assert_ledger_period_open`) exist for the posting functions added in a
--  later migration to call inside their own transaction, the same pattern
--  `resolveWithdrawal` already uses for its OTP check.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0074_ledger_core.sql --yes
-- ============================================================================

SET search_path TO app, public;

-- ---- legal entities -------------------------------------------------------

CREATE TABLE IF NOT EXISTS app.legal_entity (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          text NOT NULL UNIQUE,
    name          text NOT NULL,
    is_provisional boolean NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE app.shield_store
    ADD COLUMN IF NOT EXISTS entity_id bigint REFERENCES app.legal_entity(id);

-- One provisional entity per existing store that doesn't have one yet, so
-- the journal has somewhere to post today's stores' money. A store added
-- later needs an admin to assign (or create) its entity explicitly — this
-- is not auto-created going forward, only backfilled here once.
INSERT INTO app.legal_entity (code, name, is_provisional)
SELECT s.code, s.name || ' (provisional entity)', true
FROM app.shield_store s
WHERE s.entity_id IS NULL
  AND NOT EXISTS (SELECT 1 FROM app.legal_entity e WHERE e.code = s.code)
ON CONFLICT (code) DO NOTHING;

UPDATE app.shield_store s
SET entity_id = e.id
FROM app.legal_entity e
WHERE s.entity_id IS NULL AND e.code = s.code;

-- ---- chart of accounts -----------------------------------------------------

CREATE TABLE IF NOT EXISTS app.chart_of_account (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code           text NOT NULL UNIQUE,
    name           text NOT NULL,
    type           text NOT NULL CHECK (type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
    is_provisional boolean NOT NULL DEFAULT true,
    created_at     timestamptz NOT NULL DEFAULT now()
);

-- A starter chart covering every money event this codebase has today. Every
-- row here is provisional until an accountant reviews it.
INSERT INTO app.chart_of_account (code, name, type) VALUES
    ('1001', 'Cash — store',                               'ASSET'),
    ('1002', 'Bank',                                        'ASSET'),
    ('1003', 'GPay / UPI clearing',                         'ASSET'),
    ('2001', 'Member wallet liability',                     'LIABILITY'),
    ('2002', 'Agent commission payable',                    'LIABILITY'),
    ('2003', 'Reward points liability',                     'LIABILITY'),
    ('2004', 'Reserve payable to head office — company share', 'LIABILITY'),
    ('2005', 'Reserve payable to head office — agent pool leftover', 'LIABILITY'),
    ('4001', 'Sales revenue — orders',                      'REVENUE'),
    ('4002', 'Sales revenue — lab',                         'REVENUE'),
    ('4003', 'Consultation revenue — appointments',         'REVENUE'),
    ('5001', 'Agent commission expense',                    'EXPENSE'),
    ('5002', 'Discounts given',                              'EXPENSE'),
    ('5004', 'Reward points expense',                        'EXPENSE'),
    ('3001', 'Opening balance / retained earnings (backfill plug)', 'EQUITY')
ON CONFLICT (code) DO NOTHING;

-- ---- posting rules ---------------------------------------------------------

-- Maps one event's named lines to an account code, so the posting functions
-- (added in a later migration) look the account up by (event, line_role)
-- instead of having it hardcoded. Changing where an event posts is then an
-- UPDATE here, not a new migration.
CREATE TABLE IF NOT EXISTS app.posting_rule (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event          text NOT NULL,
    line_role      text NOT NULL,
    account_code   text NOT NULL REFERENCES app.chart_of_account(code),
    is_provisional boolean NOT NULL DEFAULT true,
    created_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (event, line_role)
);

INSERT INTO app.posting_rule (event, line_role, account_code) VALUES
    -- Health Pass activation received.
    ('activation_received', 'cash_in',           '1001'),
    ('activation_received', 'member_wallet',      '2001'),
    ('activation_received', 'reserve_company',    '2004'),
    ('activation_received', 'reserve_pool',       '2005'),
    ('activation_received', 'agent_commission',   '2002'),
    -- Agent commission accrual (the expense side of the payable above).
    ('agent_commission_accrued', 'expense',       '5001'),
    ('agent_commission_accrued', 'payable',       '2002'),
    -- Agent withdrawal paid out.
    ('withdrawal_paid', 'payable',                '2002'),
    ('withdrawal_paid', 'cash_out',                '1002'),
    -- Agent earnings moved to the agent's member wallet.
    ('wallet_transfer', 'payable',                '2002'),
    ('wallet_transfer', 'member_wallet',          '2001'),
    -- Shop order / bill collected.
    ('order_collected', 'cash_in',                '1001'),
    ('order_collected', 'wallet_in',              '2001'),
    ('order_collected', 'revenue',                '4001'),
    ('order_collected', 'discount',               '5002'),
    -- Lab bill collected.
    ('lab_bill_collected', 'cash_in',             '1001'),
    ('lab_bill_collected', 'wallet_in',           '2001'),
    ('lab_bill_collected', 'revenue',             '4002'),
    -- Appointment fee collected.
    ('appointment_fee_collected', 'cash_in',      '1001'),
    ('appointment_fee_collected', 'revenue',      '4003'),
    -- Reward points issued / redeemed.
    ('reward_points_issued', 'expense',           '5004'),
    ('reward_points_issued', 'liability',         '2003'),
    -- A redemption converts points into wallet balance, not revenue: the
    -- points liability falls and the member wallet liability rises by the
    -- same rupee figure (100 points = ₹1 — see RewardsService.redeem).
    ('reward_points_redeemed', 'liability',       '2003'),
    ('reward_points_redeemed', 'member_wallet',   '2001')
ON CONFLICT (event, line_role) DO NOTHING;

-- ---- journal ----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS app.journal_entry (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id     bigint NOT NULL REFERENCES app.legal_entity(id),
    posted_on     date NOT NULL DEFAULT current_date,
    source_table  text NOT NULL,
    source_id     text NOT NULL,
    event         text NOT NULL,
    description   text NOT NULL DEFAULT '',
    -- A correction is a reversing entry, never an edit to the original.
    reversal_of   uuid REFERENCES app.journal_entry(id),
    reversed_by   uuid REFERENCES app.journal_entry(id),
    created_at    timestamptz NOT NULL DEFAULT now(),
    -- One posting per source row per event per entity — a retried request
    -- can't post twice, while one event that genuinely has to post to two
    -- entities (an intercompany split) is two separate rows, not a conflict.
    UNIQUE (source_table, source_id, event, entity_id)
);
CREATE INDEX IF NOT EXISTS journal_entry_entity_idx ON app.journal_entry(entity_id, posted_on);

CREATE TABLE IF NOT EXISTS app.journal_line (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entry_id   uuid NOT NULL REFERENCES app.journal_entry(id) ON DELETE CASCADE,
    account_id bigint NOT NULL REFERENCES app.chart_of_account(id),
    debit      numeric(12,2) NOT NULL DEFAULT 0 CHECK (debit >= 0),
    credit     numeric(12,2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    -- Exactly one side of each line is non-zero.
    CHECK ((debit = 0) <> (credit = 0))
);
CREATE INDEX IF NOT EXISTS journal_line_entry_idx ON app.journal_line(entry_id);
CREATE INDEX IF NOT EXISTS journal_line_account_idx ON app.journal_line(account_id);

-- Raises if the lines posted so far for `p_entry_id` don't balance. A
-- posting function calls this right before its transaction commits, after
-- inserting every line for the entry.
CREATE OR REPLACE FUNCTION app.assert_journal_entry_balanced(p_entry_id uuid) RETURNS void AS $$
DECLARE
    v_debit  numeric(12,2);
    v_credit numeric(12,2);
BEGIN
    SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
      INTO v_debit, v_credit
      FROM app.journal_line WHERE entry_id = p_entry_id;

    IF v_debit <> v_credit THEN
        RAISE EXCEPTION 'Journal entry % does not balance: debit % <> credit %',
            p_entry_id, v_debit, v_credit;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ---- period close -----------------------------------------------------------

CREATE TABLE IF NOT EXISTS app.ledger_period (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_id  bigint NOT NULL REFERENCES app.legal_entity(id),
    -- The first day of the month this row covers.
    period     date NOT NULL,
    closed_at  timestamptz,
    closed_by  text,
    UNIQUE (entity_id, period)
);

-- Raises if `p_entity_id`'s period covering `p_on` is already closed. A
-- posting function calls this before writing a journal entry.
CREATE OR REPLACE FUNCTION app.assert_ledger_period_open(p_entity_id bigint, p_on date) RETURNS void AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM app.ledger_period
        WHERE entity_id = p_entity_id
          AND period = date_trunc('month', p_on)::date
          AND closed_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'The ledger period for entity % covering % is closed', p_entity_id, p_on;
    END IF;
END;
$$ LANGUAGE plpgsql;
