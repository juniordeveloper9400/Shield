-- ============================================================================
--  0069 · Banners beyond the home screen — starting with the Lab section
-- ============================================================================
--  `app.home_banner` has only ever fed one spot: the hero carousel at the top
--  of the app and web home screen (shieldweb's Banners → Home tab). The Lab
--  section wants the identical kind of banner — a staff-managed, swipeable
--  promotional strip right under its own search bar — and the two have
--  nothing placement-specific about their shape (image, title, note, button,
--  target, active, sort), so this is the same table with one more column
--  rather than a parallel `app.lab_banner` to keep in step forever.
--
--  `placement` says which strip a row belongs to:
--    'home' — the existing hero carousel (every row made before this
--             migration is backfilled to 'home', so nothing already
--             configured moves or disappears).
--    'lab'  — the new strip on the Lab section, added from shieldweb's
--             Banners → Lab tab. Empty until staff add one — the apps show
--             nothing there rather than a bundled default, unlike Home.
--
--  A plain `text` column with a CHECK rather than a Postgres ENUM: a new
--  placement later (Prescriptions, say) is one more value in the CHECK, not
--  an `ALTER TYPE ... ADD VALUE` outside a transaction.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0069_banner_placement.sql --yes
-- ============================================================================

SET search_path TO app, public;

ALTER TABLE app.home_banner
    ADD COLUMN IF NOT EXISTS placement text NOT NULL DEFAULT 'home';

ALTER TABLE app.home_banner
    DROP CONSTRAINT IF EXISTS home_banner_placement_check;

ALTER TABLE app.home_banner
    ADD CONSTRAINT home_banner_placement_check CHECK (placement IN ('home', 'lab'));

CREATE INDEX IF NOT EXISTS home_banner_placement_idx ON app.home_banner (placement, sort);
