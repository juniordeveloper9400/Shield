-- ============================================================================
--  0046 · Lab test master — the LIS-style Test / Group Test / Package form
-- ============================================================================
--  The console's Lab Tests page used to edit only app.lab_package (the
--  member-facing packages: price, MRP, active). Lab staff also need the
--  laboratory's own catalogue -- every individual test with its department,
--  sample, container, turnaround, reference ranges and specifications, and the
--  group tests / packages built from them. This adds that master.
--
--    app.lab_test               one row per Test, Group Test or Package
--    app.lab_test_group_item    the tests inside a Group Test / Package
--    app.lab_test_special_rate  a referring lab's own rate for a test
--
--  It is deliberately separate from app.lab_package / app.lab_profile, which
--  still drive what a member can book in the app. Nothing here changes those.
--
--  Purely additive and idempotent (IF NOT EXISTS throughout), so it is safe to
--  re-run. Nothing is backfilled.
--    dart run backend/db/apply_migration.dart backend/db/migrations/0046_lab_test_master.sql --yes
-- ============================================================================

SET search_path TO app, public;

-- The "Lis Code" shown on the form (e.g. 2033): handed out by the database so
-- two staff saving at once never collide. Starts at 1001.
CREATE SEQUENCE IF NOT EXISTS app.lab_test_lis_code_seq START 1001;

CREATE TABLE IF NOT EXISTS app.lab_test (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid                  uuid NOT NULL DEFAULT gen_random_uuid(),
    lis_code              integer NOT NULL UNIQUE DEFAULT nextval('app.lab_test_lis_code_seq'),
    -- TEST = a single test; GROUP = a group test (Set Grouptest tab lists its
    -- members); PACKAGE = a health-check package built the same way.
    test_type             text NOT NULL DEFAULT 'TEST'
                          CHECK (test_type IN ('TEST', 'GROUP', 'PACKAGE')),
    name                  text NOT NULL,
    short_name            text NOT NULL DEFAULT '',
    calc_code             text NOT NULL DEFAULT '',

    division              text NOT NULL DEFAULT 'LAB',
    department            text NOT NULL DEFAULT '',
    method                text NOT NULL DEFAULT '',
    unit                  text NOT NULL DEFAULT '',

    rate                  numeric(12,2) NOT NULL DEFAULT 0 CHECK (rate >= 0),
    discount_percent      numeric(5,2)  NOT NULL DEFAULT 0
                          CHECK (discount_percent >= 0 AND discount_percent <= 100),
    -- What the patient pays: rate less the discount. Stored, not derived, so a
    -- later change to the rule never rewrites an old price.
    amount                numeric(12,2) NOT NULL DEFAULT 0 CHECK (amount >= 0),

    sample                text NOT NULL DEFAULT '',
    volume                text NOT NULL DEFAULT '',
    cut_of_time           text NOT NULL DEFAULT '',   -- the form's "Cut of time" field (e.g. RED CAP)
    technology            text NOT NULL DEFAULT '',
    test_mode             text NOT NULL DEFAULT '',
    report_on_value       integer NOT NULL DEFAULT 0 CHECK (report_on_value >= 0),
    report_on_unit        text NOT NULL DEFAULT 'Minutes'
                          CHECK (report_on_unit IN ('Minutes', 'Hours', 'Days')),
    perform_at            text NOT NULL DEFAULT 'In House',
    internal_note         text NOT NULL DEFAULT '',

    nabl_accredited       boolean NOT NULL DEFAULT false,
    send_sms              boolean NOT NULL DEFAULT false,
    sample_type_barcode   boolean NOT NULL DEFAULT false,
    free_test             boolean NOT NULL DEFAULT false,
    avoid_incentive       boolean NOT NULL DEFAULT false,
    alphanumeric_critical boolean NOT NULL DEFAULT false,
    common_technology     boolean NOT NULL DEFAULT false,
    avoid_result_entry    boolean NOT NULL DEFAULT false,
    hide_head             boolean NOT NULL DEFAULT false,
    edit_test_rate        boolean NOT NULL DEFAULT false,

    ref1                  text NOT NULL DEFAULT '',
    ref2                  text NOT NULL DEFAULT '',
    specification_1       text NOT NULL DEFAULT '',
    specification_2       text NOT NULL DEFAULT '',
    specification_3       text NOT NULL DEFAULT '',
    result_template       text NOT NULL DEFAULT '',

    is_active             boolean NOT NULL DEFAULT true,
    created_by            text NOT NULL DEFAULT '',
    updated_by            text NOT NULL DEFAULT '',
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

-- One name per test, ignoring case, so searching by name is never ambiguous.
CREATE UNIQUE INDEX IF NOT EXISTS lab_test_name_uidx ON app.lab_test (lower(name));
CREATE INDEX IF NOT EXISTS lab_test_type_idx ON app.lab_test (test_type, is_active);

-- The tests inside a Group Test / Package -- the form's "Set Grouptest" tab.
CREATE TABLE IF NOT EXISTS app.lab_test_group_item (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    group_id    bigint NOT NULL REFERENCES app.lab_test(id) ON DELETE CASCADE,
    -- RESTRICT: a test cannot be deleted while a group still lists it.
    test_id     bigint NOT NULL REFERENCES app.lab_test(id) ON DELETE RESTRICT,
    -- The member's price inside this group; starts at the test's own amount.
    amount      numeric(12,2) NOT NULL DEFAULT 0 CHECK (amount >= 0),
    set_order   integer NOT NULL DEFAULT 0,
    is_subhead  boolean NOT NULL DEFAULT false,
    CONSTRAINT lab_test_group_item_not_self CHECK (group_id <> test_id),
    CONSTRAINT lab_test_group_item_unique UNIQUE (group_id, test_id)
);
CREATE INDEX IF NOT EXISTS lab_test_group_item_test_idx ON app.lab_test_group_item (test_id);

-- A referring lab's own rate for a test -- the "Special Rate & Ref Lab" tab.
CREATE TABLE IF NOT EXISTS app.lab_test_special_rate (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_id   bigint NOT NULL REFERENCES app.lab_test(id) ON DELETE CASCADE,
    ref_lab   text NOT NULL,
    rate      numeric(12,2) NOT NULL DEFAULT 0 CHECK (rate >= 0),
    CONSTRAINT lab_test_special_rate_unique UNIQUE (test_id, ref_lab)
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'lab_test_touch'
    ) THEN
        CREATE TRIGGER lab_test_touch BEFORE UPDATE ON app.lab_test
            FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
    END IF;
END;
$$;

COMMENT ON TABLE app.lab_test IS
  'The laboratory''s own test master (LIS-style): single tests, group tests '
  'and packages. Separate from app.lab_package, which is what members book.';
COMMENT ON COLUMN app.lab_test.lis_code IS
  'Human-facing LIS code, handed out by app.lab_test_lis_code_seq.';
