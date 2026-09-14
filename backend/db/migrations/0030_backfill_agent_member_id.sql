-- ============================================================================
--  0030 · backfill app.agent.member_id for rows approved before this existed
-- ============================================================================
--  shieldweb's agent_request approval path (src/api/agents.ts approveAgent)
--  never set member_id on the app.agent row it inserted -- only the separate
--  "convert member directly" path (src/api/users.ts) did. backend/api's
--  member-facing agent routes (GET /v1/agent/team, etc.) resolve the
--  signed-in agent by member_id, not phone, so every agent approved through
--  the normal request queue reads as "not an approved agent" there even
--  though the console shows them approved and the app's own home screen
--  used to show their agent card fine (it matched by phone against Neon
--  directly). approveAgent's INSERT is fixed going forward; this backfills
--  every row that already exists with member_id still NULL.
--
--  Only touches agent rows with no member_id and where exactly one app.users
--  row's phone matches -- an unmatched or ambiguous phone is left alone
--  rather than guessed at.
--
--  Idempotent -- safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0030_backfill_agent_member_id.sql --yes
-- ============================================================================

SET search_path TO app, public;

UPDATE agent
   SET member_id = u.id,
       updated_at = now()
  FROM users u
 WHERE agent.member_id IS NULL
   AND agent.phone = u.phone
   AND (SELECT count(*) FROM users u2 WHERE u2.phone = agent.phone) = 1;
