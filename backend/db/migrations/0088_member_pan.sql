-- ============================================================================
--  0088 · A member's own PAN, captured at registration
-- ============================================================================
--  `app.agent` / `app.agent_request` already carry a `pan` column (an
--  agent's own KYC detail) — `app.users` (the member) has never had one.
--  Registration is asking for it now, so a member can type their own PAN in
--  the same place every other registration detail goes, validated client-side
--  to the real format (`AAAAA9999A`) the same way `AgentService.validatePan`
--  already checks an agent's.
--
--  Same convention every other optional free-text profile column on this
--  table already uses (`email`, `address`, `place`) — nullable, no format
--  check in the database itself; the real validation is client-side
--  (`RegistrationService.validatePan` / `AgentService.validatePan`), and a
--  blank PAN is a member who simply hasn't filled it in, not an error.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0088_member_pan.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.users
    ADD COLUMN IF NOT EXISTS pan text;
