-- ============================================================================
--  0080 · Ledger backfill: historical "Add to wallet" transfers
-- ============================================================================
--  Migration 0078's own header said wallet-transfer history couldn't be
--  backfilled — "wallet_entry rows exist (kind = 'AGENT_EARNINGS') but
--  carry no link back to which agent or which request moved the money".
--  That was wrong: the link exists, just not as an explicit foreign key —
--  app.move_agent_earnings_to_wallet (migration 0072) always writes the
--  transfer into the AGENT's OWN member wallet, so
--  wallet_entry.wallet_id -> app.wallet.member_id -> app.agent.member_id
--  resolves it exactly, with no ambiguity (an agent's member_id is unique
--  to that agent).
--
--  As of writing this migration, there are zero AGENT_EARNINGS wallet_entry
--  rows in this database — no agent has used "Add to wallet" yet — so this
--  is a no-op today. It is written anyway, both for correctness (the
--  Head Office ledger should be complete, not "complete except for one
--  case nobody checked") and in case any exist by the time it runs.
--
--  A row whose wallet cannot be resolved to exactly one agent (deleted
--  agent, or any future data shape change) is skipped and logged, not
--  guessed at.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0080_ledger_backfill_wallet_transfer.sql --yes
-- ============================================================================

SET search_path TO app, public;

DO $$
DECLARE
    r RECORD;
    v_hq_entity_id  bigint;
    v_entry_id      uuid;
    v_acct_payable  bigint;
    v_acct_wallet   bigint;
BEGIN
    SELECT id INTO v_hq_entity_id FROM app.legal_entity WHERE code = 'HQ';
    IF v_hq_entity_id IS NULL THEN RETURN; END IF;

    v_acct_payable := app.ledger_account('wallet_transfer', 'payable');
    v_acct_wallet  := app.ledger_account('wallet_transfer', 'member_wallet');
    IF v_acct_payable IS NULL OR v_acct_wallet IS NULL THEN RETURN; END IF;

    FOR r IN
        SELECT we.id, we.amount, we.occurred_on, a.code
        FROM app.wallet_entry we
        JOIN app.wallet w ON w.id = we.wallet_id
        JOIN app.agent a ON a.member_id = w.member_id
        WHERE we.kind = 'AGENT_EARNINGS'
    LOOP
        BEGIN
            IF EXISTS (
                SELECT 1 FROM app.journal_entry je
                WHERE je.source_table = 'wallet_entry' AND je.source_id = r.id::text
                  AND je.event = 'wallet_transfer' AND je.entity_id = v_hq_entity_id
            ) THEN CONTINUE; END IF;

            INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
            VALUES (v_hq_entity_id, r.occurred_on, 'wallet_entry', r.id::text, 'wallet_transfer',
                    'Agent earnings moved to wallet - ' || r.code || ' (backfilled)')
            RETURNING id INTO v_entry_id;

            INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES
                (v_entry_id, v_acct_payable, r.amount, 0),
                (v_entry_id, v_acct_wallet, 0, r.amount);

            PERFORM app.assert_journal_entry_balanced(v_entry_id);
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Backfill skipped for wallet_entry %: %', r.id, SQLERRM;
        END;
    END LOOP;
END $$;
