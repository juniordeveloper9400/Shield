-- ============================================================================
--  0051 · Member ID prefix: SHIELD-#### -> SAHAKAR-####
-- ============================================================================
--  A member's Member ID is their own referral / invite code
--  (`app.users.referral_code`). It was issued as `SHIELD-1234`; the apps now
--  issue `SAHAKAR-1234`, and this moves every member already holding the old
--  form onto the new one, so the account screen, Refer & Earn and the console
--  all read the same.
--
--  The four digits are kept, so the code keeps its identity. The API and the
--  app still accept an old `SHIELD-1234` typed at registration (they map it to
--  `SAHAKAR-1234`), so a code that was already shared keeps working.
--
--  Deliberately NOT touched: agent / investor codes (`SHD-AGT-…`, `SHD-INV-…`),
--  store codes (`SHD-MEL`, …), order numbers and promo codes (`SHIELD20`).
--
--  A row is skipped if its `SAHAKAR-` twin is already taken (only possible if
--  a new-style code was issued before this ran); it keeps its old code, which
--  still works for lookups.
--
--  Idempotent — a re-run finds nothing left to convert:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0051_member_id_sahakar_prefix.sql --yes
--
--  To undo, replace 'SAHAKAR-' with 'SHIELD-' in the same column.
-- ============================================================================

SET search_path TO app, public;

UPDATE app.users AS u
SET referral_code = 'SAHAKAR-' || substr(u.referral_code, length('SHIELD-') + 1),
    updated_at    = now()
WHERE u.referral_code LIKE 'SHIELD-%'
  AND NOT EXISTS (
    SELECT 1
    FROM app.users AS other
    WHERE other.referral_code = 'SAHAKAR-' || substr(u.referral_code, length('SHIELD-') + 1)
  );
