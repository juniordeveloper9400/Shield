-- ============================================================================
--  0032 · commission reserve ledger
-- ============================================================================
--  A Health Pass activation's commission pool (10% of the loaded amount) is
--  split three ways once staff approve the card:
--    - 60% of the pool to the agent whose code the member gave at checkout
--      (their own direct-sale earnings, app.agent.earned) — or, when that
--      agent already is the one national agent, this is all they get;
--    - 10% of the pool to the one national agent, when the direct seller is
--      someone else — an override for sitting at the top of the whole tree;
--    - whatever is left (30% when a non-national agent sold directly, 40%
--      when the national agent did) is not owed to any agent at all. It is
--      the company's own share of the sale.
--
--  That last share was previously credited nowhere and tracked nowhere —
--  wallet.service.ts's approveCard simply stopped after paying the agent(s)
--  above. This ledger is where it lands instead: one row per approved card
--  that actually generated a reserve share, so the admin console has a real,
--  auditable "Reserved" total to show — company money, deliberately never
--  surfaced to a member or an agent anywhere in the app itself.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0032_commission_reserve.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.commission_reserve_entry (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    wallet_card_id bigint NOT NULL REFERENCES app.wallet_card(id),
    amount         numeric(12,2) NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS commission_reserve_entry_card_idx ON app.commission_reserve_entry(wallet_card_id);
