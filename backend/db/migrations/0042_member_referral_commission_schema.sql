-- ============================================================================
--  0042 · Member-to-member referral commission — schema
-- ============================================================================
--  Everything the "refer and earn" screen has promised but never actually
--  paid: a fellow member typed into the "Referral ID" field at registration
--  (`ReferralService.applySignupCode`, `app.referral.status = 'REGISTERED'`)
--  earns the person who referred them 2% of every Health Pass plan they go
--  on to activate, and the inviter's own referral ladder
--  (`lib/module/refer/referral_level.dart`'s `ReferralLadder.levels`) pays
--  real reward points on clearing a rung, not just a client-side number.
--
--  This migration only adds the schema for that — the actual crediting
--  logic lands in 0043's `app.approve_wallet_card_activation` (that's what
--  shieldweb's admin console really calls on approval — see this repo's own
--  established pattern of a Postgres function mirroring `wallet.service.ts`)
--  and in `order.service.ts`'s checkout. Split in two because a Postgres
--  enum value added with ALTER TYPE can't be used inside the same
--  transaction that adds it — this file's statements all run as one
--  implicit transaction (apply_migration.dart's simple-query protocol), so
--  0043 is the first migration allowed to actually write a
--  'REFERRAL_EARNINGS' wallet_entry.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0042_member_referral_commission_schema.sql --yes
-- ============================================================================

SET search_path TO app, public;

-- The commission money a referred member's plan activation pays their
-- inviter — parallel to the already-existing AGENT_EARNINGS, credited to a
-- different person's wallet than the one holding the card being approved.
ALTER TYPE app.wallet_entry_kind ADD VALUE IF NOT EXISTS 'REFERRAL_EARNINGS';

-- The published ladder (app.referral_level already existed, unwired) —
-- exact mirror of lib/module/refer/referral_level.dart's ReferralLadder.levels,
-- so the points a rung pays here can never drift from what the app tells a
-- member it pays.
INSERT INTO app.referral_level (level, name, referrals_required, points) VALUES
    (1, 'Starter',   2,  100),
    (2, 'Riser',     5,  200),
    (3, 'Achiever', 10,  500),
    (4, 'Champion', 20, 1500),
    (5, 'Legend',   40, 3000)
ON CONFLICT (level) DO NOTHING;

-- The highest referral_level.level already paid out in reward points to
-- this member as an inviter — so crossing a rung is credited exactly once,
-- from however many different places check it (a referred member's first
-- paid order, or any later plan activation).
ALTER TABLE app.users
    ADD COLUMN IF NOT EXISTS referral_level_awarded integer NOT NULL DEFAULT 0;
