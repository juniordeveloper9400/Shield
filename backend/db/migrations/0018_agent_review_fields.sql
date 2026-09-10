-- ============================================================================
--  0018 · app.agent gets a review trail — reviewed_at + reviewer_note
-- ============================================================================
--  An agent registered from the app now lands as approval_status = 'PENDING'
--  (the app's insertAgent writes that literal; the column default stays
--  'APPROVED' so admin-console-created agents are unaffected). The Agent
--  approvals screen in shieldweb approves it — setting level / parent / area —
--  or rejects it with a reason the recruiter sees on the pending card.
--
--  This adds:
--    * reviewed_at    — when an admin last approved/rejected the row
--    * reviewer_note   — the rejection reason, shown in the app
--    * an index on (approval_status, created_at DESC) for the pending list
--
--  Idempotent: every statement is IF NOT EXISTS, so a re-run is harmless.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0018_agent_review_fields.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.agent
  ADD COLUMN IF NOT EXISTS reviewed_at   timestamptz,
  ADD COLUMN IF NOT EXISTS reviewer_note text NOT NULL DEFAULT '';

COMMENT ON COLUMN app.agent.reviewed_at IS
  'When an admin last approved or rejected this agent from the Agent approvals '
  'screen. NULL until reviewed.';
COMMENT ON COLUMN app.agent.reviewer_note IS
  'The rejection reason an admin gave — surfaced to the recruiter on the '
  'pending/rejected card in the app. Blank unless approval_status = ''REJECTED''.';

CREATE INDEX IF NOT EXISTS agent_approval_status_idx
  ON app.agent (approval_status, created_at DESC);
