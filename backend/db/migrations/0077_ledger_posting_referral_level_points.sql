-- ============================================================================
--  0077 · Ledger posting: the SQL-side referral ladder award
-- ============================================================================
--  app.award_referral_level_points (migration 0043) is a second, PL/pgSQL
--  copy of referral.service.ts's own award logic — called from inside
--  app.approve_wallet_card_activation (migration 0053) when a referred
--  member activates a plan, not from a TypeScript request. The TypeScript
--  path already posts (see backend/api/src/modules/ledger/
--  reward-points-ledger.ts, called from referral.service.ts,
--  identity.service.ts, order.service.ts and rewards.service.ts) — this is
--  the one place reward points were still issued without a ledger entry.
--
--  Same event, same account mapping, same amount (points / 100, matching
--  reward-points-ledger.ts's POINTS_PER_RUPEE — keep both in sync if that
--  rate ever changes) as the TypeScript path, so a trial balance doesn't
--  care which path issued a given award.
--
--  Never blocks the real award — same tolerance as every other posting
--  function since migration 0075: wrapped in its own BEGIN/EXCEPTION.
--
--  pg-mem has no PL/pgSQL support, so this function is verified live
--  against the dev database instead, the same way migrations 0075/0076
--  are (see scratchpad/verify_ledger_posting.mjs — not checked in).
--
--  Needs migrations 0074 and 0075 applied first (app.legal_entity,
--  app.ledger_account, app.assert_ledger_period_open,
--  app.assert_journal_entry_balanced, and the 'HQ' entity row).
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0077_ledger_posting_referral_level_points.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE OR REPLACE FUNCTION app.award_referral_level_points(p_inviter_id bigint)
RETURNS void AS $$
DECLARE
    v_direct_referrals integer;
    v_already_awarded  integer;
    v_new_points       integer;
    v_new_level        integer;
    -- ledger posting (migration 0077; provisional)
    v_reward_txn_id    bigint;
    v_hq_entity_id     bigint;
    v_entry_id         uuid;
    v_acct_expense     bigint;
    v_acct_liability   bigint;
    v_rupees           numeric(12,2);
BEGIN
    SELECT COUNT(*) INTO v_direct_referrals
    FROM app.referral
    WHERE inviter_member_id = p_inviter_id
      AND status IN ('TRANSACTED', 'PLAN_ACTIVATED');

    SELECT COALESCE(referral_level_awarded, 0) INTO v_already_awarded
    FROM app.users WHERE id = p_inviter_id;

    SELECT COALESCE(SUM(points), 0), COALESCE(MAX(level), v_already_awarded)
      INTO v_new_points, v_new_level
    FROM app.referral_level
    WHERE level > v_already_awarded AND referrals_required <= v_direct_referrals;

    IF v_new_points > 0 THEN
        INSERT INTO app.reward_point_transaction (member_id, points, reason, note)
        VALUES (p_inviter_id, v_new_points, 'REFERRAL_LEVEL', 'Referral ladder — level ' || v_new_level)
        RETURNING id INTO v_reward_txn_id;

        UPDATE app.users
           SET reward_points = reward_points + v_new_points,
               referral_level_awarded = v_new_level
         WHERE id = p_inviter_id;

        -- ---- ledger posting (migration 0077; provisional) --------------------
        BEGIN
            SELECT id INTO v_hq_entity_id FROM app.legal_entity WHERE code = 'HQ';
            IF v_hq_entity_id IS NOT NULL THEN
                v_acct_expense   := app.ledger_account('reward_points_issued', 'expense');
                v_acct_liability := app.ledger_account('reward_points_issued', 'liability');

                IF v_acct_expense IS NOT NULL AND v_acct_liability IS NOT NULL THEN
                    PERFORM app.assert_ledger_period_open(v_hq_entity_id, current_date);
                    v_rupees := ROUND(v_new_points / 100.0, 2);

                    INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
                    VALUES (v_hq_entity_id, current_date, 'reward_point_transaction', v_reward_txn_id::text, 'reward_points_issued',
                            v_new_points || ' reward points awarded — referral ladder level ' || v_new_level)
                    RETURNING id INTO v_entry_id;

                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES
                        (v_entry_id, v_acct_expense, v_rupees, 0),
                        (v_entry_id, v_acct_liability, 0, v_rupees);

                    PERFORM app.assert_journal_entry_balanced(v_entry_id);
                END IF;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Ledger posting skipped for reward_point_transaction %: %', v_reward_txn_id, SQLERRM;
        END;
    END IF;
END;
$$ LANGUAGE plpgsql;
