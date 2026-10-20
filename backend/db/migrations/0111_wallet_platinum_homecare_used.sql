-- ============================================================================
--  0111 · Platinum Health Pass free home-care visit counter
-- ============================================================================
--  Platinum carries 6 complimentary home-collection visits (see
--  privilege_tier.dart's own "Free home care × 6" benefit text) — unlike
--  Silver (flat ₹50/visit) and Gold (flat ₹20/visit), which need no counter
--  at all. This tracks how many of those 6 a member has used, so the lab
--  order editor can show "X of 6 used" and stop crediting a free visit once
--  they are gone.
--
--  Per member (one counter on app.wallet), not per wallet_card — a renewed
--  Platinum card does not reset this; it is a lifetime complimentary-visit
--  count, the same way the figure was described when this was specified.
--
--  Idempotent — safe to run more than once. Apply this BEFORE deploying the
--  backend that reads it:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0111_wallet_platinum_homecare_used.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.wallet
    ADD COLUMN IF NOT EXISTS platinum_homecare_used integer NOT NULL DEFAULT 0;
