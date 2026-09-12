-- ============================================================================
--  0026 · app.agent_customer gets a UNIQUE (agent_id, member_id)
-- ============================================================================
--  A member links to at most one agent as their "sold by" — the referral
--  code entered once at registration. The unique constraint is what makes
--  linking idempotent: registering the code twice (a retry, a duplicate
--  network call) inserts the row once via ON CONFLICT DO NOTHING rather
--  than creating a second customer row for the same agent/member pair.
--
--  Idempotent itself: the constraint is only added if missing, so a re-run
--  of this migration is harmless.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0026_agent_customer_unique_member.sql --yes
-- ============================================================================

SET search_path TO app, public;

DO $$ BEGIN
    ALTER TABLE app.agent_customer
      ADD CONSTRAINT agent_customer_agent_member_key UNIQUE (agent_id, member_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
