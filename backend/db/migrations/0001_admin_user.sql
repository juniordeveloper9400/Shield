-- ============================================================================
--  0001 · app.admin_user — logins for the SHIELD Admin console (shieldweb/)
-- ============================================================================
--  The admin console (React app under shieldweb/) signs staff in with Firebase
--  Email/Password. This table is the *profile* for each of those Firebase
--  identities: which role they hold and, for a Pharmacy Admin, which branch.
--
--  Idempotent — safe to run more than once:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0001_admin_user.sql --yes
-- ============================================================================

SET search_path TO app, public;

DO $$ BEGIN
    CREATE TYPE app.admin_role AS ENUM
        ('SUPERADMIN', 'PHARMACY', 'LAB', 'APPOINTMENTS');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS app.admin_user (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid          uuid NOT NULL DEFAULT gen_random_uuid(),
    -- Set once the matching Firebase user exists; the console fills it in on
    -- first sign-in if it was created before the Firebase account.
    firebase_uid  text UNIQUE,
    email         text NOT NULL UNIQUE,                 -- the sign-in identity
    name          text NOT NULL,
    role          app.admin_role NOT NULL DEFAULT 'PHARMACY',
    -- Set for a PHARMACY admin — the one branch they work. Null for every
    -- other role (they see all branches).
    store_id      bigint REFERENCES app.shield_store(id) ON DELETE SET NULL,
    avatar_color  text NOT NULL DEFAULT '#2c57a6',
    is_active     boolean NOT NULL DEFAULT true,
    last_login_at timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
    CREATE TRIGGER admin_user_touch BEFORE UPDATE ON app.admin_user
        FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
