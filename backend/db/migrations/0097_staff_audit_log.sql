-- The Super Admin's own audit trail: every staff login (success and
-- failure) and every mutating staff-console request (create/update/
-- delete), who did it, when, from where, and what was sent. See
-- backend/api's AuditInterceptor / AuditService / AuthService.loginStaff.
--
-- staff_id is ON DELETE SET NULL, not CASCADE — a deleted staff account's
-- own history is exactly what this table exists to keep. staff_login_id/
-- staff_name/staff_role are a point-in-time snapshot for the same reason,
-- so a row still reads sensibly once the live app.admin_user row is gone
-- or has since changed role/name.
--   dart run backend/db/apply_migration.dart backend/db/migrations/0097_staff_audit_log.sql --yes

CREATE TABLE IF NOT EXISTS app.staff_audit_log (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    staff_id        bigint REFERENCES app.admin_user(id) ON DELETE SET NULL,
    staff_login_id  text NOT NULL,
    staff_name      text NOT NULL,
    staff_role      text NOT NULL,
    store_id        bigint REFERENCES app.shield_store(id) ON DELETE SET NULL,
    action          text NOT NULL,
    method          text NOT NULL,
    path            text NOT NULL,
    status_code     integer NOT NULL,
    request_body    jsonb,
    ip              text,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS staff_audit_log_staff_idx ON app.staff_audit_log (staff_id, created_at DESC);
CREATE INDEX IF NOT EXISTS staff_audit_log_created_idx ON app.staff_audit_log (created_at DESC);
