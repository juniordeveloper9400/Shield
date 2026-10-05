-- ============================================================================
--  0073 · Contact settings the apps read: the admin WhatsApp number
-- ============================================================================
--  The Flutter apps' WhatsApp buttons need one number that is not a store's
--  own — the admin desk a member can reach before registering, or when they
--  have no store yet. It lives in a key/value settings table so the admin
--  console can change it without an app release.
--
--  Each store's own number is already `app.shield_store.phone`.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0073_app_contact_settings.sql --yes
-- ============================================================================

SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.app_setting (
    key        text PRIMARY KEY,
    value      text NOT NULL DEFAULT '',
    updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO app.app_setting (key, value)
VALUES ('admin_whatsapp', '')
ON CONFLICT (key) DO NOTHING;
