-- ============================================================================
--  app schema — regenerated from the live database by
aadhaar--  `dart run backend/db/dump_app_schema.dart --write` on 2026-10-19.
--
--  Machine-generated — do not hand-edit. The prose explaining *why* each
--  table/column exists lives in backend/db/APP_SCHEMA.md instead, which
--  doesn't drift from reality the way inline DDL comments silently did
--  here for a long time (see this file's own doc comment in git log for
--  exactly how far). Edit a migration under backend/db/migrations/, apply
--  it, then re-run this to pick the change up — never this file directly.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS app;
SET search_path TO app, public;

-- ---- Extensions --------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA app;

-- ---- Enums -----------------------------------------------------------------
CREATE TYPE app.address_label AS ENUM ('HOME', 'WORK', 'OTHER');
CREATE TYPE app.admin_role AS ENUM ('SUPERADMIN', 'PHARMACY', 'LAB', 'APPOINTMENTS', 'ADMIN', 'DELIVERY', 'LAB_TECHNICIAN');
CREATE TYPE app.agent_approval AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
CREATE TYPE app.agent_level AS ENUM ('NATIONAL', 'REGION', 'STATE', 'DISTRICT', 'ASSEMBLY', 'LSGD', 'WARD');
CREATE TYPE app.appointment_kind AS ENUM ('CLINIC', 'TELE', 'DENTAL', 'DIETITIAN');
CREATE TYPE app.appointment_status AS ENUM ('REQUESTED', 'CONFIRMED', 'COMPLETED', 'CANCELLED');
CREATE TYPE app.approval_status AS ENUM ('PENDING', 'APPROVED', 'PARTIALLY_APPROVED', 'REJECTED', 'CANCELLED', 'ON_HOLD');
CREATE TYPE app.cart_line_source AS ENUM ('SHOP', 'PRESCRIPTION');
CREATE TYPE app.fulfillment_type AS ENUM ('HOME_DELIVERY', 'STORE_PICKUP');
CREATE TYPE app.gender AS ENUM ('FEMALE', 'MALE', 'OTHER');
CREATE TYPE app.investor_plan_type AS ENUM ('YEARLY', 'MONTHLY');
CREATE TYPE app.lab_booking_fulfillment AS ENUM ('HOME_COLLECTION', 'STORE_VISIT');
CREATE TYPE app.lab_booking_status AS ENUM ('REQUESTED', 'CONFIRMED', 'SAMPLE_COLLECTED', 'REPORT_READY', 'CANCELLED');
CREATE TYPE app.lsgd_type AS ENUM ('corporation', 'municipality', 'grama_panchayat');
CREATE TYPE app.medicine_duration AS ENUM ('ONE_WEEK', 'FIFTEEN_DAYS', 'ONE_MONTH', 'TWO_MONTHS', 'THREE_MONTHS');
CREATE TYPE app.notification_status AS ENUM ('QUEUED', 'SENT', 'READ');
CREATE TYPE app.order_kind AS ENUM ('STANDARD', 'PRESCRIPTION');
CREATE TYPE app.order_line_status AS ENUM ('AVAILABLE', 'OUT_OF_STOCK', 'NOT_POSSIBLE', 'CUSTOMER_NOT_NEEDED');
CREATE TYPE app.order_payment_status AS ENUM ('PENDING', 'PAID');
CREATE TYPE app.order_status AS ENUM ('PROCESSING', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED');
CREATE TYPE app.patient_relation AS ENUM ('SELF', 'SPOUSE', 'CHILD', 'PARENT', 'OTHER');
CREATE TYPE app.plan_change_status AS ENUM ('REQUESTED', 'APPROVED', 'REJECTED');
CREATE TYPE app.prescription_medicine_status AS ENUM ('AVAILABLE', 'OUT_OF_STOCK', 'NOT_POSSIBLE', 'ORDERED');
CREATE TYPE app.prescription_status AS ENUM ('AWAITING_REVIEW', 'READ', 'IN_CART', 'ORDERED');
CREATE TYPE app.privilege_card_kind AS ENUM ('SILVER', 'GOLD', 'PLATINUM');
CREATE TYPE app.push_platform AS ENUM ('ANDROID', 'IOS', 'WEB');
CREATE TYPE app.referral_status AS ENUM ('SHARED', 'REGISTERED', 'TRANSACTED', 'PLAN_ACTIVATED');
CREATE TYPE app.reward_txn_reason AS ENUM ('REGISTRATION', 'REFERRAL_LEVEL', 'ORDER', 'REDEMPTION', 'ADJUSTMENT');
CREATE TYPE app.store_type AS ENUM ('PHARMACY', 'LAB', 'PHARMACY_LAB');
CREATE TYPE app.track_state AS ENUM ('DONE', 'CURRENT', 'UPCOMING');
CREATE TYPE app.wallet_entry_kind AS ENUM ('ACTIVATION', 'BONUS', 'TOPUP', 'SPEND', 'POINTS_REDEEMED', 'AGENT_EARNINGS', 'REFERRAL_EARNINGS');
CREATE TYPE app.withdrawal_status AS ENUM ('PENDING', 'PAID', 'REJECTED');

-- ---- Tables ------------------------------------------------------------------
CREATE TABLE app.legal_entity (
    id bigint GENERATED ALWAYS AS IDENTITY,
    code text NOT NULL,
    name text NOT NULL,
    is_provisional boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT legal_entity_pkey PRIMARY KEY (id),
    CONSTRAINT legal_entity_code_key UNIQUE (code)
);

CREATE TABLE app.shield_store (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    code text NOT NULL,
    name text NOT NULL,
    area text NOT NULL,
    city text NOT NULL,
    state text NOT NULL,
    pincode text NOT NULL,
    phone text NOT NULL DEFAULT ''::text,
    hours text NOT NULL DEFAULT '8:00 AM – 10:00 PM'::text,
    is_active boolean NOT NULL DEFAULT true,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    latitude numeric(9,6),
    longitude numeric(9,6),
    maps_url text NOT NULL DEFAULT ''::text,
    bank_account_name text NOT NULL DEFAULT ''::text,
    bank_account_number text NOT NULL DEFAULT ''::text,
    bank_ifsc text NOT NULL DEFAULT ''::text,
    bank_name text NOT NULL DEFAULT ''::text,
    offers_lab_collection boolean NOT NULL DEFAULT true,
    entity_id bigint,
    store_type app.store_type NOT NULL DEFAULT 'PHARMACY_LAB'::app.store_type,
    CONSTRAINT shield_store_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES app.legal_entity(id),
    CONSTRAINT shield_store_pkey PRIMARY KEY (id),
    CONSTRAINT shield_store_code_key UNIQUE (code)
);

CREATE TABLE app.admin_user (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    firebase_uid text,
    login_id text NOT NULL,
    name text NOT NULL,
    role app.admin_role NOT NULL DEFAULT 'PHARMACY'::app.admin_role,
    store_id bigint,
    avatar_color text NOT NULL DEFAULT '#2c57a6'::text,
    is_active boolean NOT NULL DEFAULT true,
    last_login_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    password_hash text,
    modules text[],
    CONSTRAINT admin_user_store_id_fkey FOREIGN KEY (store_id) REFERENCES app.shield_store(id) ON DELETE SET NULL,
    CONSTRAINT admin_user_pkey PRIMARY KEY (id),
    CONSTRAINT admin_user_email_key UNIQUE (login_id),
    CONSTRAINT admin_user_firebase_uid_key UNIQUE (firebase_uid)
);

CREATE TABLE app.users (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    phone text NOT NULL,
    name text NOT NULL,
    firebase_uid text,
    email text,
    gender app.gender,
    dob date,
    address text,
    place text,
    pincode text,
    state text,
    home_store_id bigint,
    reward_points integer NOT NULL DEFAULT 0,
    referral_code text,
    referred_by_member_id bigint,
    registration_completed_at timestamptz,
    registration_prompt_dismissed boolean NOT NULL DEFAULT false,
    last_login_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    referral_level_awarded integer NOT NULL DEFAULT 0,
    pan text,
    CONSTRAINT member_home_store_id_fkey FOREIGN KEY (home_store_id) REFERENCES app.shield_store(id) ON DELETE SET NULL,
    CONSTRAINT member_referred_by_member_id_fkey FOREIGN KEY (referred_by_member_id) REFERENCES app.users(id) ON DELETE SET NULL,
    CONSTRAINT member_pkey PRIMARY KEY (id),
    CONSTRAINT member_firebase_uid_key UNIQUE (firebase_uid),
    CONSTRAINT member_phone_key UNIQUE (phone),
    CONSTRAINT member_referral_code_key UNIQUE (referral_code)
);

CREATE TABLE app.agent (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    member_id bigint,
    code text NOT NULL,
    name text NOT NULL,
    phone text NOT NULL,
    level app.agent_level NOT NULL,
    parent_id bigint,
    active boolean NOT NULL DEFAULT true,
    area text NOT NULL DEFAULT ''::text,
    first_name text NOT NULL DEFAULT ''::text,
    middle_name text NOT NULL DEFAULT ''::text,
    last_name text NOT NULL DEFAULT ''::text,
    dob date,
    aadhaar text NOT NULL DEFAULT ''::text,
    pan text NOT NULL DEFAULT ''::text,
    address text NOT NULL DEFAULT ''::text,
    pincode text NOT NULL DEFAULT ''::text,
    place text NOT NULL DEFAULT ''::text,
    account_number text NOT NULL DEFAULT ''::text,
    photo_path text,
    approval_status app.agent_approval NOT NULL DEFAULT 'APPROVED'::app.agent_approval,
    earned numeric(12,2) NOT NULL DEFAULT 0,
    redeemed numeric(12,2) NOT NULL DEFAULT 0,
    personal_sales numeric(12,2) NOT NULL DEFAULT 0,
    moved_to_wallet numeric(12,2) NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    area_id uuid,
    reviewed_at timestamptz,
    reviewer_note text NOT NULL DEFAULT ''::text,
    CONSTRAINT agent_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE SET NULL,
    CONSTRAINT agent_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES app.agent(id) ON DELETE SET NULL,
    CONSTRAINT agent_pkey PRIMARY KEY (id),
    CONSTRAINT agent_code_key UNIQUE (code)
);

CREATE TABLE app.wallet (
    id bigint GENERATED ALWAYS AS IDENTITY,
    member_id bigint NOT NULL,
    balance numeric(12,2) NOT NULL DEFAULT 0,
    reward_points integer NOT NULL DEFAULT 0,
    redeemed_this_month numeric(12,2) NOT NULL DEFAULT 0,
    opened_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT wallet_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT wallet_pkey PRIMARY KEY (id),
    CONSTRAINT wallet_member_id_key UNIQUE (member_id)
);

CREATE TABLE app.membership_tier (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    kind app.privilege_card_kind NOT NULL,
    name text NOT NULL,
    bin text NOT NULL,
    blurb text NOT NULL DEFAULT ''::text,
    bonus_rate numeric(4,3) NOT NULL DEFAULT 0.100,
    validity_months integer NOT NULL DEFAULT 12,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT membership_tier_pkey PRIMARY KEY (id),
    CONSTRAINT membership_tier_kind_key UNIQUE (kind)
);

CREATE TABLE app.wallet_card (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    wallet_id bigint NOT NULL,
    tier_id bigint NOT NULL,
    amount numeric(12,2) NOT NULL,
    bonus numeric(12,2) NOT NULL,
    recharged_extra numeric(12,2) NOT NULL DEFAULT 0,
    card_number text,
    store_id bigint,
    issued_on date NOT NULL DEFAULT CURRENT_DATE,
    recharged_on date NOT NULL DEFAULT CURRENT_DATE,
    expires_on date NOT NULL,
    sold_by_agent_id bigint,
    created_at timestamptz NOT NULL DEFAULT now(),
    status app.approval_status NOT NULL DEFAULT 'PENDING'::app.approval_status,
    submitted_at timestamptz NOT NULL DEFAULT now(),
    reviewed_at timestamptz,
    reviewer_note text NOT NULL DEFAULT ''::text,
    receipt_reference text,
    receipt_file_name text,
    receipt_image text,
    verified_reference text,
    received_on date,
    receipt_verified boolean NOT NULL DEFAULT false,
    received_amount numeric(12,2),
    CONSTRAINT wallet_card_sold_by_agent_fk FOREIGN KEY (sold_by_agent_id) REFERENCES app.agent(id) ON DELETE SET NULL,
    CONSTRAINT wallet_card_store_id_fkey FOREIGN KEY (store_id) REFERENCES app.shield_store(id) ON DELETE SET NULL,
    CONSTRAINT wallet_card_tier_id_fkey FOREIGN KEY (tier_id) REFERENCES app.membership_tier(id) ON DELETE RESTRICT,
    CONSTRAINT wallet_card_wallet_id_fkey FOREIGN KEY (wallet_id) REFERENCES app.wallet(id) ON DELETE CASCADE,
    CONSTRAINT wallet_card_pkey PRIMARY KEY (id)
);

CREATE TABLE app.journal_entry (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    entity_id bigint NOT NULL,
    posted_on date NOT NULL DEFAULT CURRENT_DATE,
    source_table text NOT NULL,
    source_id text NOT NULL,
    event text NOT NULL,
    description text NOT NULL DEFAULT ''::text,
    reversal_of uuid,
    reversed_by uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT journal_entry_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES app.legal_entity(id),
    CONSTRAINT journal_entry_reversal_of_fkey FOREIGN KEY (reversal_of) REFERENCES app.journal_entry(id),
    CONSTRAINT journal_entry_reversed_by_fkey FOREIGN KEY (reversed_by) REFERENCES app.journal_entry(id),
    CONSTRAINT journal_entry_pkey PRIMARY KEY (id),
    CONSTRAINT journal_entry_source_table_source_id_event_entity_id_key UNIQUE (source_table, source_id, event, entity_id)
);

CREATE TABLE app.agent_commission (
    id bigint GENERATED ALWAYS AS IDENTITY,
    wallet_card_id bigint NOT NULL,
    agent_id bigint NOT NULL,
    hop smallint NOT NULL,
    rate numeric(5,4) NOT NULL,
    amount numeric(12,2) NOT NULL,
    journal_entry_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT agent_commission_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES app.agent(id),
    CONSTRAINT agent_commission_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES app.journal_entry(id),
    CONSTRAINT agent_commission_wallet_card_id_fkey FOREIGN KEY (wallet_card_id) REFERENCES app.wallet_card(id),
    CONSTRAINT agent_commission_pkey PRIMARY KEY (id)
);

CREATE TABLE app.agent_customer (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    agent_id bigint NOT NULL,
    member_id bigint,
    name text NOT NULL,
    phone text NOT NULL DEFAULT ''::text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT agent_customer_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES app.agent(id) ON DELETE CASCADE,
    CONSTRAINT agent_customer_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE SET NULL,
    CONSTRAINT agent_customer_pkey PRIMARY KEY (id),
    CONSTRAINT agent_customer_agent_member_key UNIQUE (agent_id, member_id)
);

CREATE TABLE app.agent_customer_plan (
    id bigint GENERATED ALWAYS AS IDENTITY,
    agent_customer_id bigint NOT NULL,
    tier_id bigint NOT NULL,
    amount numeric(12,2) NOT NULL,
    activated_on date NOT NULL,
    wallet_card_id bigint,
    CONSTRAINT agent_customer_plan_agent_customer_id_fkey FOREIGN KEY (agent_customer_id) REFERENCES app.agent_customer(id) ON DELETE CASCADE,
    CONSTRAINT agent_customer_plan_tier_id_fkey FOREIGN KEY (tier_id) REFERENCES app.membership_tier(id) ON DELETE RESTRICT,
    CONSTRAINT agent_customer_plan_wallet_card_id_fkey FOREIGN KEY (wallet_card_id) REFERENCES app.wallet_card(id) ON DELETE SET NULL,
    CONSTRAINT agent_customer_plan_pkey PRIMARY KEY (id)
);

CREATE TABLE app.agent_request (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    parent_agent_id bigint,
    requested_level app.agent_level NOT NULL,
    requested_area text NOT NULL DEFAULT ''::text,
    requested_area_id uuid,
    name text NOT NULL,
    phone text NOT NULL,
    first_name text NOT NULL DEFAULT ''::text,
    middle_name text NOT NULL DEFAULT ''::text,
    last_name text NOT NULL DEFAULT ''::text,
    dob date,
    aadhaar text NOT NULL DEFAULT ''::text,
    pan text NOT NULL DEFAULT ''::text,
    address text NOT NULL DEFAULT ''::text,
    pincode text NOT NULL DEFAULT ''::text,
    place text NOT NULL DEFAULT ''::text,
    account_number text NOT NULL DEFAULT ''::text,
    photo_path text,
    status app.agent_approval NOT NULL DEFAULT 'PENDING'::app.agent_approval,
    reviewer_note text NOT NULL DEFAULT ''::text,
    reviewed_at timestamptz,
    agent_id bigint,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT agent_request_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES app.agent(id) ON DELETE SET NULL,
    CONSTRAINT agent_request_parent_agent_id_fkey FOREIGN KEY (parent_agent_id) REFERENCES app.agent(id) ON DELETE SET NULL,
    CONSTRAINT agent_request_pkey PRIMARY KEY (id)
);

CREATE TABLE app.patient (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    member_id bigint NOT NULL,
    name text NOT NULL,
    phone text NOT NULL DEFAULT ''::text,
    address text NOT NULL DEFAULT ''::text,
    dob date NOT NULL,
    gender app.gender NOT NULL DEFAULT 'OTHER'::app.gender,
    abha_id text NOT NULL DEFAULT ''::text,
    relation app.patient_relation NOT NULL DEFAULT 'SELF'::app.patient_relation,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT patient_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT patient_pkey PRIMARY KEY (id)
);

CREATE TABLE app.member_address (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    member_id bigint NOT NULL,
    label app.address_label NOT NULL DEFAULT 'HOME'::app.address_label,
    house text NOT NULL,
    area text NOT NULL,
    landmark text NOT NULL DEFAULT ''::text,
    pincode text NOT NULL,
    city text,
    state text,
    first_name text NOT NULL DEFAULT ''::text,
    last_name text NOT NULL DEFAULT ''::text,
    phone text NOT NULL DEFAULT ''::text,
    patient_id bigint,
    is_default boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT member_address_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT member_address_patient_fk FOREIGN KEY (patient_id) REFERENCES app.patient(id) ON DELETE SET NULL,
    CONSTRAINT member_address_pkey PRIMARY KEY (id)
);

CREATE TABLE app.payment_method (
    id bigint GENERATED ALWAYS AS IDENTITY,
    code text NOT NULL,
    name text NOT NULL,
    blurb text NOT NULL DEFAULT ''::text,
    is_live boolean NOT NULL DEFAULT false,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT payment_method_pkey PRIMARY KEY (id),
    CONSTRAINT payment_method_code_key UNIQUE (code)
);

CREATE TABLE app."order" (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    member_id bigint NOT NULL,
    code text NOT NULL,
    kind app.order_kind NOT NULL DEFAULT 'STANDARD'::app.order_kind,
    status app.order_status NOT NULL DEFAULT 'PROCESSING'::app.order_status,
    item_count integer NOT NULL DEFAULT 0,
    mrp_total numeric(12,2) NOT NULL DEFAULT 0,
    paid_total numeric(12,2) NOT NULL DEFAULT 0,
    delivery_fee numeric(12,2) NOT NULL DEFAULT 0,
    delivery_address_id bigint,
    store_id bigint,
    payment_method_id bigint,
    billed_wallet_card_id bigint,
    reference text,
    placed_on date NOT NULL DEFAULT CURRENT_DATE,
    placed_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    fulfillment_type app.fulfillment_type NOT NULL DEFAULT 'HOME_DELIVERY'::app.fulfillment_type,
    payment_status app.order_payment_status NOT NULL DEFAULT 'PENDING'::app.order_payment_status,
    delivery_boy_id bigint,
    paid_at timestamptz,
    reviewed_at timestamptz,
    converted_to_bill_at timestamptz,
    store_contacted_at timestamptz,
    CONSTRAINT order_billed_wallet_card_fk FOREIGN KEY (billed_wallet_card_id) REFERENCES app.wallet_card(id) ON DELETE SET NULL,
    CONSTRAINT order_delivery_address_id_fkey FOREIGN KEY (delivery_address_id) REFERENCES app.member_address(id) ON DELETE SET NULL,
    CONSTRAINT order_delivery_boy_id_fkey FOREIGN KEY (delivery_boy_id) REFERENCES app.admin_user(id) ON DELETE SET NULL,
    CONSTRAINT order_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT order_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES app.payment_method(id) ON DELETE SET NULL,
    CONSTRAINT order_store_id_fkey FOREIGN KEY (store_id) REFERENCES app.shield_store(id) ON DELETE SET NULL,
    CONSTRAINT order_pkey PRIMARY KEY (id),
    CONSTRAINT order_code_key UNIQUE (code)
);

CREATE TABLE app.lab_category (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    image text,
    sort integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT lab_category_pkey PRIMARY KEY (id)
);

CREATE TABLE app.lab_test (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    lis_code integer NOT NULL,
    test_type text NOT NULL DEFAULT 'TEST'::text,
    name text NOT NULL,
    short_name text NOT NULL DEFAULT ''::text,
    calc_code text NOT NULL DEFAULT ''::text,
    division text NOT NULL DEFAULT 'LAB'::text,
    department text NOT NULL DEFAULT ''::text,
    method text NOT NULL DEFAULT ''::text,
    unit text NOT NULL DEFAULT ''::text,
    rate numeric(12,2) NOT NULL DEFAULT 0,
    discount_percent numeric(5,2) NOT NULL DEFAULT 0,
    amount numeric(12,2) NOT NULL DEFAULT 0,
    sample text NOT NULL DEFAULT ''::text,
    volume text NOT NULL DEFAULT ''::text,
    cut_of_time text NOT NULL DEFAULT ''::text,
    technology text NOT NULL DEFAULT ''::text,
    test_mode text NOT NULL DEFAULT ''::text,
    report_on_value integer NOT NULL DEFAULT 0,
    report_on_unit text NOT NULL DEFAULT 'Minutes'::text,
    perform_at text NOT NULL DEFAULT 'In House'::text,
    internal_note text NOT NULL DEFAULT ''::text,
    nabl_accredited boolean NOT NULL DEFAULT false,
    send_sms boolean NOT NULL DEFAULT false,
    sample_type_barcode boolean NOT NULL DEFAULT false,
    free_test boolean NOT NULL DEFAULT false,
    avoid_incentive boolean NOT NULL DEFAULT false,
    alphanumeric_critical boolean NOT NULL DEFAULT false,
    common_technology boolean NOT NULL DEFAULT false,
    avoid_result_entry boolean NOT NULL DEFAULT false,
    hide_head boolean NOT NULL DEFAULT false,
    edit_test_rate boolean NOT NULL DEFAULT false,
    ref1 text NOT NULL DEFAULT ''::text,
    ref2 text NOT NULL DEFAULT ''::text,
    specification_1 text NOT NULL DEFAULT ''::text,
    specification_2 text NOT NULL DEFAULT ''::text,
    specification_3 text NOT NULL DEFAULT ''::text,
    result_template text NOT NULL DEFAULT ''::text,
    is_active boolean NOT NULL DEFAULT true,
    created_by text NOT NULL DEFAULT ''::text,
    updated_by text NOT NULL DEFAULT ''::text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    scheduled_days text NOT NULL DEFAULT ''::text,
    reporting_time text NOT NULL DEFAULT ''::text,
    lab_rate numeric(12,2) NOT NULL DEFAULT 0,
    source text NOT NULL DEFAULT 'ADMIN'::text,
    category_id bigint,
    show_in_app boolean NOT NULL DEFAULT false,
    is_most_common boolean NOT NULL DEFAULT false,
    description text NOT NULL DEFAULT ''::text,
    fasting text NOT NULL DEFAULT ''::text,
    symptoms text[] NOT NULL DEFAULT '{}'::text[],
    CONSTRAINT lab_test_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT lab_test_discount_percent_check CHECK (((discount_percent >= (0)::numeric) AND (discount_percent <= (100)::numeric))),
    CONSTRAINT lab_test_lab_rate_check CHECK ((lab_rate >= (0)::numeric)),
    CONSTRAINT lab_test_rate_check CHECK ((rate >= (0)::numeric)),
    CONSTRAINT lab_test_report_on_unit_check CHECK ((report_on_unit = ANY (ARRAY['Minutes'::text, 'Hours'::text, 'Days'::text]))),
    CONSTRAINT lab_test_report_on_value_check CHECK ((report_on_value >= 0)),
    CONSTRAINT lab_test_source_check CHECK ((source = ANY (ARRAY['ADMIN'::text, 'RATE_LIST'::text]))),
    CONSTRAINT lab_test_test_type_check CHECK ((test_type = ANY (ARRAY['TEST'::text, 'GROUP'::text, 'PACKAGE'::text]))),
    CONSTRAINT lab_test_category_id_fkey FOREIGN KEY (category_id) REFERENCES app.lab_category(id) ON DELETE SET NULL,
    CONSTRAINT lab_test_pkey PRIMARY KEY (id),
    CONSTRAINT lab_test_lis_code_key UNIQUE (lis_code)
);

CREATE TABLE app.lab_package (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    slug text NOT NULL,
    name text NOT NULL,
    test_count integer NOT NULL DEFAULT 0,
    profile_count integer NOT NULL DEFAULT 0,
    rating text,
    booked text,
    report_in text,
    price numeric(12,2) NOT NULL DEFAULT 0,
    mrp numeric(12,2) NOT NULL DEFAULT 0,
    saved numeric(12,2) NOT NULL DEFAULT 0,
    inherits_from text,
    inherits_summary text,
    extras_label text,
    for_whom text,
    age_range text,
    preparation text,
    sample text,
    organs text[] NOT NULL DEFAULT '{}'::text[],
    about text NOT NULL DEFAULT ''::text,
    is_active boolean NOT NULL DEFAULT true,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    category_id bigint,
    source_test_id bigint,
    is_most_common boolean NOT NULL DEFAULT false,
    fasting text NOT NULL DEFAULT ''::text,
    symptoms text[] NOT NULL DEFAULT '{}'::text[],
    short_name text NOT NULL DEFAULT ''::text,
    why_this_test text NOT NULL DEFAULT ''::text,
    CONSTRAINT lab_package_category_id_fkey FOREIGN KEY (category_id) REFERENCES app.lab_category(id) ON DELETE SET NULL,
    CONSTRAINT lab_package_source_test_id_fkey FOREIGN KEY (source_test_id) REFERENCES app.lab_test(id) ON DELETE CASCADE,
    CONSTRAINT lab_package_pkey PRIMARY KEY (id),
    CONSTRAINT lab_package_slug_key UNIQUE (slug),
    CONSTRAINT lab_package_source_test_id_key UNIQUE (source_test_id)
);

CREATE TABLE app.lab_booking (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    member_id bigint NOT NULL,
    lab_package_id bigint NOT NULL,
    patients_count integer NOT NULL DEFAULT 1,
    unit_price numeric(12,2) NOT NULL DEFAULT 0,
    total_price numeric(12,2) NOT NULL DEFAULT 0,
    status app.lab_booking_status NOT NULL DEFAULT 'REQUESTED'::app.lab_booking_status,
    scheduled_for timestamptz,
    address_id bigint,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    note text,
    report_uploaded_at timestamptz,
    store_id bigint,
    fulfillment_type app.lab_booking_fulfillment NOT NULL DEFAULT 'HOME_COLLECTION'::app.lab_booking_fulfillment,
    assigned_staff_id bigint,
    address_override text,
    contact_name text,
    contact_phone text,
    address_phone_override text,
    fix_charge numeric(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT lab_booking_address_id_fkey FOREIGN KEY (address_id) REFERENCES app.member_address(id) ON DELETE SET NULL,
    CONSTRAINT lab_booking_assigned_staff_id_fkey FOREIGN KEY (assigned_staff_id) REFERENCES app.admin_user(id) ON DELETE SET NULL,
    CONSTRAINT lab_booking_lab_package_id_fkey FOREIGN KEY (lab_package_id) REFERENCES app.lab_package(id) ON DELETE RESTRICT,
    CONSTRAINT lab_booking_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT lab_booking_store_id_fkey FOREIGN KEY (store_id) REFERENCES app.shield_store(id) ON DELETE SET NULL,
    CONSTRAINT lab_booking_pkey PRIMARY KEY (id)
);

CREATE TABLE app.wallet_entry (
    id bigint GENERATED ALWAYS AS IDENTITY,
    wallet_id bigint NOT NULL,
    kind app.wallet_entry_kind NOT NULL,
    label text NOT NULL,
    amount numeric(12,2) NOT NULL,
    occurred_on date NOT NULL DEFAULT CURRENT_DATE,
    wallet_card_id bigint,
    order_id bigint,
    created_at timestamptz NOT NULL DEFAULT now(),
    lab_booking_id bigint,
    CONSTRAINT wallet_entry_lab_booking_id_fkey FOREIGN KEY (lab_booking_id) REFERENCES app.lab_booking(id),
    CONSTRAINT wallet_entry_order_id_fkey FOREIGN KEY (order_id) REFERENCES app."order"(id) ON DELETE SET NULL,
    CONSTRAINT wallet_entry_wallet_card_id_fkey FOREIGN KEY (wallet_card_id) REFERENCES app.wallet_card(id) ON DELETE SET NULL,
    CONSTRAINT wallet_entry_wallet_id_fkey FOREIGN KEY (wallet_id) REFERENCES app.wallet(id) ON DELETE CASCADE,
    CONSTRAINT wallet_entry_pkey PRIMARY KEY (id)
);

CREATE TABLE app.agent_wallet_transfer (
    id bigint GENERATED ALWAYS AS IDENTITY,
    agent_id bigint NOT NULL,
    amount numeric(12,2) NOT NULL,
    wallet_entry_id bigint,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT agent_wallet_transfer_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES app.agent(id) ON DELETE CASCADE,
    CONSTRAINT agent_wallet_transfer_wallet_entry_id_fkey FOREIGN KEY (wallet_entry_id) REFERENCES app.wallet_entry(id) ON DELETE SET NULL,
    CONSTRAINT agent_wallet_transfer_pkey PRIMARY KEY (id)
);

CREATE TABLE app.agent_withdrawal (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    agent_id bigint NOT NULL,
    amount numeric(12,2) NOT NULL,
    status app.withdrawal_status NOT NULL DEFAULT 'PENDING'::app.withdrawal_status,
    requested_on date NOT NULL DEFAULT CURRENT_DATE,
    processed_on date,
    created_at timestamptz NOT NULL DEFAULT now(),
    approved_at timestamptz,
    approved_by text,
    verified_account text,
    verification_note text,
    payment_reference text,
    processed_by text,
    CONSTRAINT agent_withdrawal_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES app.agent(id) ON DELETE CASCADE,
    CONSTRAINT agent_withdrawal_pkey PRIMARY KEY (id)
);

CREATE TABLE app.app_setting (
    key text NOT NULL,
    value text NOT NULL DEFAULT ''::text,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT app_setting_pkey PRIMARY KEY (key)
);

CREATE TABLE app.clinic (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    type text,
    location text,
    phone text,
    description text NOT NULL DEFAULT ''::text,
    tint text,
    is_verified boolean NOT NULL DEFAULT false,
    specialities text[] NOT NULL DEFAULT '{}'::text[],
    is_active boolean NOT NULL DEFAULT true,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT clinic_pkey PRIMARY KEY (id)
);

CREATE TABLE app.dietitian (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    qualification text,
    focus text[] NOT NULL DEFAULT '{}'::text[],
    experience_years integer NOT NULL DEFAULT 0,
    languages text[] NOT NULL DEFAULT '{}'::text[],
    fee numeric(12,2) NOT NULL DEFAULT 0,
    next_slot text,
    is_active boolean NOT NULL DEFAULT true,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT dietitian_pkey PRIMARY KEY (id)
);

CREATE TABLE app.appointment (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    member_id bigint NOT NULL,
    kind app.appointment_kind NOT NULL DEFAULT 'CLINIC'::app.appointment_kind,
    clinic_id bigint,
    dietitian_id bigint,
    patient_id bigint,
    doctor_name text,
    fee numeric(12,2),
    status app.appointment_status NOT NULL DEFAULT 'REQUESTED'::app.appointment_status,
    scheduled_for timestamptz,
    remarks text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT appointment_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES app.clinic(id) ON DELETE SET NULL,
    CONSTRAINT appointment_dietitian_id_fkey FOREIGN KEY (dietitian_id) REFERENCES app.dietitian(id) ON DELETE SET NULL,
    CONSTRAINT appointment_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT appointment_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES app.patient(id) ON DELETE SET NULL,
    CONSTRAINT appointment_pkey PRIMARY KEY (id)
);

CREATE TABLE app.prescription (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    member_id bigint NOT NULL,
    patient_id bigint NOT NULL,
    code text NOT NULL,
    file_name text NOT NULL DEFAULT ''::text,
    storage_path text,
    doctor text NOT NULL DEFAULT ''::text,
    duration app.medicine_duration,
    custom_days integer,
    recurring_from date,
    recurring_until date,
    status app.prescription_status NOT NULL DEFAULT 'AWAITING_REVIEW'::app.prescription_status,
    reviewed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    store_id bigint,
    image text,
    image_rotation smallint NOT NULL DEFAULT 0,
    CONSTRAINT prescription_image_rotation_check CHECK ((image_rotation = ANY (ARRAY[0, 90, 180, 270]))),
    CONSTRAINT prescription_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT prescription_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES app.patient(id) ON DELETE RESTRICT,
    CONSTRAINT prescription_store_id_fkey FOREIGN KEY (store_id) REFERENCES app.shield_store(id) ON DELETE SET NULL,
    CONSTRAINT prescription_pkey PRIMARY KEY (id),
    CONSTRAINT prescription_code_key UNIQUE (code)
);

CREATE TABLE app.approval (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    member_id bigint NOT NULL,
    order_id bigint,
    prescription_id bigint,
    code text NOT NULL,
    order_ref text,
    patient_name text,
    pharmacist_note text NOT NULL DEFAULT ''::text,
    status app.approval_status NOT NULL DEFAULT 'PENDING'::app.approval_status,
    raised_on date NOT NULL DEFAULT CURRENT_DATE,
    responded_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT approval_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT approval_order_id_fkey FOREIGN KEY (order_id) REFERENCES app."order"(id) ON DELETE SET NULL,
    CONSTRAINT approval_prescription_id_fkey FOREIGN KEY (prescription_id) REFERENCES app.prescription(id) ON DELETE SET NULL,
    CONSTRAINT approval_pkey PRIMARY KEY (id),
    CONSTRAINT approval_code_key UNIQUE (code)
);

CREATE TABLE app.approval_item (
    id bigint GENERATED ALWAYS AS IDENTITY,
    approval_id bigint NOT NULL,
    name text NOT NULL,
    pack text NOT NULL DEFAULT ''::text,
    quantity integer NOT NULL DEFAULT 1,
    price numeric(12,2) NOT NULL DEFAULT 0,
    note text NOT NULL DEFAULT ''::text,
    is_accepted boolean,
    CONSTRAINT approval_item_approval_id_fkey FOREIGN KEY (approval_id) REFERENCES app.approval(id) ON DELETE CASCADE,
    CONSTRAINT approval_item_pkey PRIMARY KEY (id)
);

CREATE TABLE app.region (
    id uuid NOT NULL DEFAULT uuidv7(),
    national_agent_id bigint,
    name text NOT NULL,
    code text NOT NULL DEFAULT ''::text,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    agent_id bigint,
    prefix_code text NOT NULL DEFAULT ''::text,
    CONSTRAINT region_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES app.agent(id) ON DELETE SET NULL,
    CONSTRAINT region_national_agent_id_fkey FOREIGN KEY (national_agent_id) REFERENCES app.agent(id) ON DELETE SET NULL,
    CONSTRAINT region_pkey PRIMARY KEY (id),
    CONSTRAINT region_agent_id_key UNIQUE (agent_id),
    CONSTRAINT region_name_key UNIQUE (name)
);

CREATE TABLE app.state (
    id uuid NOT NULL DEFAULT uuidv7(),
    region_id uuid NOT NULL,
    name text NOT NULL,
    code text NOT NULL DEFAULT ''::text,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    agent_id bigint,
    prefix_code text NOT NULL DEFAULT ''::text,
    CONSTRAINT state_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES app.agent(id) ON DELETE SET NULL,
    CONSTRAINT state_region_id_fkey FOREIGN KEY (region_id) REFERENCES app.region(id) ON DELETE RESTRICT,
    CONSTRAINT state_pkey PRIMARY KEY (id),
    CONSTRAINT state_agent_id_key UNIQUE (agent_id),
    CONSTRAINT state_parent_name_key UNIQUE (region_id, name)
);

CREATE TABLE app.district (
    id uuid NOT NULL DEFAULT uuidv7(),
    state_id uuid NOT NULL,
    name text NOT NULL,
    code text NOT NULL DEFAULT ''::text,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    agent_id bigint,
    prefix_code text NOT NULL DEFAULT ''::text,
    CONSTRAINT district_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES app.agent(id) ON DELETE SET NULL,
    CONSTRAINT district_state_id_fkey FOREIGN KEY (state_id) REFERENCES app.state(id) ON DELETE RESTRICT,
    CONSTRAINT district_pkey PRIMARY KEY (id),
    CONSTRAINT district_agent_id_key UNIQUE (agent_id),
    CONSTRAINT district_parent_name_key UNIQUE (state_id, name)
);

CREATE TABLE app.assembly (
    id uuid NOT NULL DEFAULT uuidv7(),
    district_id uuid NOT NULL,
    name text NOT NULL,
    code text NOT NULL DEFAULT ''::text,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    agent_id bigint,
    prefix_code text NOT NULL DEFAULT ''::text,
    CONSTRAINT assembly_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES app.agent(id) ON DELETE SET NULL,
    CONSTRAINT assembly_district_id_fkey FOREIGN KEY (district_id) REFERENCES app.district(id) ON DELETE RESTRICT,
    CONSTRAINT assembly_pkey PRIMARY KEY (id),
    CONSTRAINT assembly_agent_id_key UNIQUE (agent_id),
    CONSTRAINT assembly_parent_code_key UNIQUE (district_id, code)
);

CREATE TABLE app.bill (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    order_id bigint NOT NULL,
    image text NOT NULL,
    sent_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    amount numeric(12,2) NOT NULL DEFAULT 0,
    status app.order_payment_status NOT NULL DEFAULT 'PENDING'::app.order_payment_status,
    paid_at timestamptz,
    wallet_collected numeric(12,2) NOT NULL DEFAULT 0,
    cash_collected numeric(12,2) NOT NULL DEFAULT 0,
    discount_amount numeric(12,2) NOT NULL DEFAULT 0,
    gpay_collected numeric(12,2) NOT NULL DEFAULT 0,
    bill_number text,
    CONSTRAINT bill_order_id_fkey FOREIGN KEY (order_id) REFERENCES app."order"(id) ON DELETE CASCADE,
    CONSTRAINT bill_pkey PRIMARY KEY (id),
    CONSTRAINT bill_order_id_key UNIQUE (order_id)
);

CREATE TABLE app.bill_line (
    id bigint GENERATED ALWAYS AS IDENTITY,
    bill_id bigint NOT NULL,
    name text NOT NULL,
    pack text NOT NULL DEFAULT ''::text,
    unit_price numeric(12,2) NOT NULL DEFAULT 0,
    qty integer NOT NULL DEFAULT 1,
    CONSTRAINT bill_line_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES app.bill(id) ON DELETE CASCADE,
    CONSTRAINT bill_line_pkey PRIMARY KEY (id)
);

CREATE TABLE app.brand (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT brand_pkey PRIMARY KEY (id)
);

CREATE TABLE app.cart (
    id bigint GENERATED ALWAYS AS IDENTITY,
    member_id bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT cart_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT cart_pkey PRIMARY KEY (id),
    CONSTRAINT cart_member_id_key UNIQUE (member_id)
);

CREATE TABLE app.product_category (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    slug text NOT NULL,
    title text NOT NULL,
    tab_label text NOT NULL,
    icon_name text,
    image text,
    banner_image text,
    panel_tint text,
    offer text NOT NULL DEFAULT ''::text,
    sort integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT product_category_pkey PRIMARY KEY (id),
    CONSTRAINT product_category_slug_key UNIQUE (slug)
);

CREATE TABLE app.product_subcategory (
    id bigint GENERATED ALWAYS AS IDENTITY,
    category_id bigint NOT NULL,
    label text NOT NULL,
    icon_name text,
    image text,
    offer text NOT NULL DEFAULT ''::text,
    sort integer NOT NULL DEFAULT 0,
    CONSTRAINT product_subcategory_category_id_fkey FOREIGN KEY (category_id) REFERENCES app.product_category(id) ON DELETE CASCADE,
    CONSTRAINT product_subcategory_pkey PRIMARY KEY (id)
);

CREATE TABLE app.product (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    code text,
    name text NOT NULL,
    pack text NOT NULL DEFAULT ''::text,
    brand text,
    category_id bigint,
    subcategory_id bigint,
    price numeric(12,2) NOT NULL DEFAULT 0,
    mrp numeric(12,2) NOT NULL DEFAULT 0,
    discount_label text,
    icon_name text,
    image text,
    is_prescription_only boolean NOT NULL DEFAULT false,
    status text NOT NULL DEFAULT 'ACTIVE'::text,
    stock_quantity numeric(12,2) NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    is_popular boolean NOT NULL DEFAULT false,
    is_deal boolean NOT NULL DEFAULT false,
    is_offer_of_day boolean NOT NULL DEFAULT false,
    popular_until timestamptz,
    deal_until timestamptz,
    offer_of_day_until timestamptz,
    CONSTRAINT product_category_id_fkey FOREIGN KEY (category_id) REFERENCES app.product_category(id) ON DELETE SET NULL,
    CONSTRAINT product_subcategory_id_fkey FOREIGN KEY (subcategory_id) REFERENCES app.product_subcategory(id) ON DELETE SET NULL,
    CONSTRAINT product_pkey PRIMARY KEY (id),
    CONSTRAINT product_code_key UNIQUE (code)
);

CREATE TABLE app.cart_line (
    id bigint GENERATED ALWAYS AS IDENTITY,
    cart_id bigint NOT NULL,
    product_id bigint,
    name text NOT NULL,
    pack text NOT NULL DEFAULT ''::text,
    price numeric(12,2) NOT NULL DEFAULT 0,
    mrp numeric(12,2) NOT NULL DEFAULT 0,
    image text,
    qty integer NOT NULL DEFAULT 1,
    source app.cart_line_source NOT NULL DEFAULT 'SHOP'::app.cart_line_source,
    prescription_id bigint,
    added_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT cart_line_qty_check CHECK (((qty >= 1) AND (qty <= 999))),
    CONSTRAINT cart_line_cart_id_fkey FOREIGN KEY (cart_id) REFERENCES app.cart(id) ON DELETE CASCADE,
    CONSTRAINT cart_line_prescription_fk FOREIGN KEY (prescription_id) REFERENCES app.prescription(id) ON DELETE SET NULL,
    CONSTRAINT cart_line_product_id_fkey FOREIGN KEY (product_id) REFERENCES app.product(id) ON DELETE SET NULL,
    CONSTRAINT cart_line_pkey PRIMARY KEY (id)
);

CREATE TABLE app.chart_of_account (
    id bigint GENERATED ALWAYS AS IDENTITY,
    code text NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    is_provisional boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chart_of_account_type_check CHECK ((type = ANY (ARRAY['ASSET'::text, 'LIABILITY'::text, 'EQUITY'::text, 'REVENUE'::text, 'EXPENSE'::text]))),
    CONSTRAINT chart_of_account_pkey PRIMARY KEY (id),
    CONSTRAINT chart_of_account_code_key UNIQUE (code)
);

CREATE TABLE app.clinic_doctor (
    id bigint GENERATED ALWAYS AS IDENTITY,
    clinic_id bigint NOT NULL,
    name text NOT NULL,
    speciality text,
    fee text,
    sort integer NOT NULL DEFAULT 0,
    CONSTRAINT clinic_doctor_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES app.clinic(id) ON DELETE CASCADE,
    CONSTRAINT clinic_doctor_pkey PRIMARY KEY (id)
);

CREATE TABLE app.commission_reserve_entry (
    id bigint GENERATED ALWAYS AS IDENTITY,
    wallet_card_id bigint NOT NULL,
    amount numeric(12,2) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    source text NOT NULL DEFAULT 'POOL_LEFTOVER'::text,
    CONSTRAINT commission_reserve_entry_source_check CHECK ((source = ANY (ARRAY['POOL_LEFTOVER'::text, 'COMPANY_SHARE'::text]))),
    CONSTRAINT commission_reserve_entry_wallet_card_id_fkey FOREIGN KEY (wallet_card_id) REFERENCES app.wallet_card(id),
    CONSTRAINT commission_reserve_entry_pkey PRIMARY KEY (id)
);

CREATE TABLE app.customer_review (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    subtitle text,
    video_url text,
    duration_seconds integer,
    is_active boolean NOT NULL DEFAULT true,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT customer_review_pkey PRIMARY KEY (id)
);

CREATE TABLE app.customer_review_video (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    subtitle text NOT NULL DEFAULT ''::text,
    video_url text NOT NULL,
    thumbnail text,
    is_active boolean NOT NULL DEFAULT true,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT customer_review_video_pkey PRIMARY KEY (id)
);

CREATE TABLE app.customer_review_video_media (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    content_type text NOT NULL,
    byte_length bigint NOT NULL,
    sha256 text NOT NULL,
    data bytea NOT NULL DEFAULT '\x'::bytea,
    next_chunk integer NOT NULL DEFAULT 0,
    upload_complete boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    CONSTRAINT customer_review_video_media_byte_length_check CHECK ((byte_length > 0)),
    CONSTRAINT customer_review_video_media_content_type_check CHECK ((content_type = ANY (ARRAY['video/mp4'::text, 'video/webm'::text, 'video/quicktime'::text]))),
    CONSTRAINT customer_review_video_media_next_chunk_check CHECK ((next_chunk >= 0)),
    CONSTRAINT customer_review_video_media_pkey PRIMARY KEY (id)
);

CREATE TABLE app.device_push_token (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    member_id bigint NOT NULL,
    token text NOT NULL,
    platform app.push_platform NOT NULL,
    device_label text,
    is_active boolean NOT NULL DEFAULT true,
    last_seen_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT device_push_token_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT device_push_token_pkey PRIMARY KEY (id),
    CONSTRAINT device_push_token_token_key UNIQUE (token)
);

CREATE TABLE app.health_article (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    slug text NOT NULL,
    title text NOT NULL,
    topics text[] NOT NULL DEFAULT '{}'::text[],
    author text,
    published_on date,
    hero_kicker text,
    intro text[] NOT NULL DEFAULT '{}'::text[],
    icon_name text,
    tint text,
    is_published boolean NOT NULL DEFAULT true,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT health_article_pkey PRIMARY KEY (id),
    CONSTRAINT health_article_slug_key UNIQUE (slug)
);

CREATE TABLE app.health_article_section (
    id bigint GENERATED ALWAYS AS IDENTITY,
    article_id bigint NOT NULL,
    sort integer NOT NULL DEFAULT 0,
    heading text NOT NULL,
    paragraphs text[] NOT NULL DEFAULT '{}'::text[],
    CONSTRAINT health_article_section_article_id_fkey FOREIGN KEY (article_id) REFERENCES app.health_article(id) ON DELETE CASCADE,
    CONSTRAINT health_article_section_pkey PRIMARY KEY (id)
);

CREATE TABLE app.home_banner (
    id bigint GENERATED ALWAYS AS IDENTITY,
    title text,
    subtitle text,
    image text,
    cta text,
    target text,
    is_active boolean NOT NULL DEFAULT true,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    placement text NOT NULL DEFAULT 'home'::text,
    CONSTRAINT home_banner_placement_check CHECK ((placement = ANY (ARRAY['home'::text, 'lab'::text]))),
    CONSTRAINT home_banner_pkey PRIMARY KEY (id)
);

CREATE TABLE app.investment_plan_point (
    id bigint GENERATED ALWAYS AS IDENTITY,
    kind text NOT NULL DEFAULT 'PLAN'::text,
    title text NOT NULL,
    body text NOT NULL DEFAULT ''::text,
    icon_name text,
    sort integer NOT NULL DEFAULT 0,
    CONSTRAINT investment_plan_point_pkey PRIMARY KEY (id)
);

CREATE TABLE app.investor (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    member_id bigint,
    code text NOT NULL,
    name text NOT NULL,
    phone text NOT NULL,
    invested_store_id bigint,
    total_units integer NOT NULL DEFAULT 0,
    unit_price numeric(12,2) NOT NULL DEFAULT 150000,
    invested_since date NOT NULL,
    roi_percent numeric(6,2) NOT NULL DEFAULT 0,
    plan_type app.investor_plan_type NOT NULL DEFAULT 'YEARLY'::app.investor_plan_type,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT investor_invested_store_id_fkey FOREIGN KEY (invested_store_id) REFERENCES app.shield_store(id) ON DELETE SET NULL,
    CONSTRAINT investor_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE SET NULL,
    CONSTRAINT investor_pkey PRIMARY KEY (id),
    CONSTRAINT investor_code_key UNIQUE (code)
);

CREATE TABLE app.investor_plan_change_request (
    id bigint GENERATED ALWAYS AS IDENTITY,
    investor_id bigint NOT NULL,
    requested_plan_type app.investor_plan_type NOT NULL,
    status app.plan_change_status NOT NULL DEFAULT 'REQUESTED'::app.plan_change_status,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CONSTRAINT investor_plan_change_request_investor_id_fkey FOREIGN KEY (investor_id) REFERENCES app.investor(id) ON DELETE CASCADE,
    CONSTRAINT investor_plan_change_request_pkey PRIMARY KEY (id)
);

CREATE TABLE app.journal_line (
    id bigint GENERATED ALWAYS AS IDENTITY,
    entry_id uuid NOT NULL,
    account_id bigint NOT NULL,
    debit numeric(12,2) NOT NULL DEFAULT 0,
    credit numeric(12,2) NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    subject_type text,
    subject_id bigint,
    CONSTRAINT journal_line_check CHECK (((debit = (0)::numeric) <> (credit = (0)::numeric))),
    CONSTRAINT journal_line_credit_check CHECK ((credit >= (0)::numeric)),
    CONSTRAINT journal_line_debit_check CHECK ((debit >= (0)::numeric)),
    CONSTRAINT journal_line_subject_type_check CHECK (((subject_type IS NULL) OR (subject_type = ANY (ARRAY['member'::text, 'agent'::text, 'investor'::text])))),
    CONSTRAINT journal_line_account_id_fkey FOREIGN KEY (account_id) REFERENCES app.chart_of_account(id),
    CONSTRAINT journal_line_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES app.journal_entry(id) ON DELETE CASCADE,
    CONSTRAINT journal_line_pkey PRIMARY KEY (id)
);

CREATE TABLE app.lab_bill (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    lab_booking_id bigint NOT NULL,
    image text NOT NULL,
    amount numeric(12,2) NOT NULL DEFAULT 0,
    discount_amount numeric(12,2) NOT NULL DEFAULT 0,
    status app.order_payment_status NOT NULL DEFAULT 'PENDING'::app.order_payment_status,
    paid_at timestamptz,
    wallet_collected numeric(12,2) NOT NULL DEFAULT 0,
    cash_collected numeric(12,2) NOT NULL DEFAULT 0,
    sent_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT lab_bill_lab_booking_id_fkey FOREIGN KEY (lab_booking_id) REFERENCES app.lab_booking(id) ON DELETE CASCADE,
    CONSTRAINT lab_bill_pkey PRIMARY KEY (id),
    CONSTRAINT lab_bill_lab_booking_id_key UNIQUE (lab_booking_id)
);

CREATE TABLE app.lab_bill_line (
    id bigint GENERATED ALWAYS AS IDENTITY,
    lab_bill_id bigint NOT NULL,
    name text NOT NULL,
    pack text NOT NULL DEFAULT ''::text,
    unit_price numeric(12,2) NOT NULL DEFAULT 0,
    qty integer NOT NULL DEFAULT 1,
    CONSTRAINT lab_bill_line_lab_bill_id_fkey FOREIGN KEY (lab_bill_id) REFERENCES app.lab_bill(id) ON DELETE CASCADE,
    CONSTRAINT lab_bill_line_pkey PRIMARY KEY (id)
);

CREATE TABLE app.lab_booking_patient (
    id bigint GENERATED ALWAYS AS IDENTITY,
    lab_booking_id bigint NOT NULL,
    patient_id bigint,
    name text,
    age integer,
    address_id bigint,
    address_override text,
    details jsonb,
    CONSTRAINT lab_booking_patient_address_id_fkey FOREIGN KEY (address_id) REFERENCES app.member_address(id),
    CONSTRAINT lab_booking_patient_lab_booking_id_fkey FOREIGN KEY (lab_booking_id) REFERENCES app.lab_booking(id) ON DELETE CASCADE,
    CONSTRAINT lab_booking_patient_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES app.patient(id) ON DELETE SET NULL,
    CONSTRAINT lab_booking_patient_pkey PRIMARY KEY (id)
);

CREATE TABLE app.lab_booking_report (
    id bigint GENERATED ALWAYS AS IDENTITY,
    lab_booking_id bigint NOT NULL,
    name text NOT NULL DEFAULT ''::text,
    image text NOT NULL,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT lab_booking_report_lab_booking_id_fkey FOREIGN KEY (lab_booking_id) REFERENCES app.lab_booking(id) ON DELETE CASCADE,
    CONSTRAINT lab_booking_report_pkey PRIMARY KEY (id)
);

CREATE TABLE app.lab_charge (
    id bigint NOT NULL,
    name text NOT NULL,
    kind text NOT NULL,
    config jsonb NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    CONSTRAINT lab_charge_kind_check CHECK ((kind = ANY (ARRAY['TECHNICIAN'::text, 'DISTANCE'::text, 'KM'::text]))),
    CONSTRAINT lab_charge_pkey PRIMARY KEY (id)
);

CREATE TABLE app.lab_package_extra_category (
    package_id bigint NOT NULL,
    category_id bigint NOT NULL,
    CONSTRAINT lab_package_extra_category_category_id_fkey FOREIGN KEY (category_id) REFERENCES app.lab_category(id) ON DELETE CASCADE,
    CONSTRAINT lab_package_extra_category_package_id_fkey FOREIGN KEY (package_id) REFERENCES app.lab_package(id) ON DELETE CASCADE,
    CONSTRAINT lab_package_extra_category_pkey PRIMARY KEY (package_id, category_id)
);

CREATE TABLE app.lab_package_test_item (
    id bigint GENERATED ALWAYS AS IDENTITY,
    package_id bigint NOT NULL,
    test_id bigint NOT NULL,
    sort integer NOT NULL DEFAULT 0,
    CONSTRAINT lab_package_test_item_package_id_fkey FOREIGN KEY (package_id) REFERENCES app.lab_package(id) ON DELETE CASCADE,
    CONSTRAINT lab_package_test_item_test_id_fkey FOREIGN KEY (test_id) REFERENCES app.lab_test(id) ON DELETE RESTRICT,
    CONSTRAINT lab_package_test_item_pkey PRIMARY KEY (id),
    CONSTRAINT lab_package_test_item_unique UNIQUE (package_id, test_id)
);

CREATE TABLE app.lab_profile (
    id bigint GENERATED ALWAYS AS IDENTITY,
    lab_package_id bigint NOT NULL,
    emoji text NOT NULL DEFAULT ''::text,
    name text NOT NULL,
    parameters integer NOT NULL DEFAULT 0,
    is_extra boolean NOT NULL DEFAULT false,
    sort integer NOT NULL DEFAULT 0,
    test_id bigint,
    short_name text NOT NULL DEFAULT ''::text,
    CONSTRAINT lab_profile_lab_package_id_fkey FOREIGN KEY (lab_package_id) REFERENCES app.lab_package(id) ON DELETE CASCADE,
    CONSTRAINT lab_profile_test_id_fkey FOREIGN KEY (test_id) REFERENCES app.lab_test(id) ON DELETE SET NULL,
    CONSTRAINT lab_profile_pkey PRIMARY KEY (id)
);

CREATE TABLE app.lab_test_field_option (
    id bigint GENERATED ALWAYS AS IDENTITY,
    field_key text NOT NULL,
    value text NOT NULL,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT lab_test_field_option_pkey PRIMARY KEY (id)
);

CREATE TABLE app.lab_test_group_item (
    id bigint GENERATED ALWAYS AS IDENTITY,
    group_id bigint NOT NULL,
    test_id bigint NOT NULL,
    amount numeric(12,2) NOT NULL DEFAULT 0,
    set_order integer NOT NULL DEFAULT 0,
    is_subhead boolean NOT NULL DEFAULT false,
    CONSTRAINT lab_test_group_item_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT lab_test_group_item_not_self CHECK ((group_id <> test_id)),
    CONSTRAINT lab_test_group_item_group_id_fkey FOREIGN KEY (group_id) REFERENCES app.lab_test(id) ON DELETE CASCADE,
    CONSTRAINT lab_test_group_item_test_id_fkey FOREIGN KEY (test_id) REFERENCES app.lab_test(id) ON DELETE RESTRICT,
    CONSTRAINT lab_test_group_item_pkey PRIMARY KEY (id),
    CONSTRAINT lab_test_group_item_unique UNIQUE (group_id, test_id)
);

CREATE TABLE app.lab_test_special_rate (
    id bigint GENERATED ALWAYS AS IDENTITY,
    test_id bigint NOT NULL,
    ref_lab text NOT NULL,
    rate numeric(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT lab_test_special_rate_rate_check CHECK ((rate >= (0)::numeric)),
    CONSTRAINT lab_test_special_rate_test_id_fkey FOREIGN KEY (test_id) REFERENCES app.lab_test(id) ON DELETE CASCADE,
    CONSTRAINT lab_test_special_rate_pkey PRIMARY KEY (id),
    CONSTRAINT lab_test_special_rate_unique UNIQUE (test_id, ref_lab)
);

CREATE TABLE app.ledger_period (
    id bigint GENERATED ALWAYS AS IDENTITY,
    entity_id bigint NOT NULL,
    period date NOT NULL,
    closed_at timestamptz,
    closed_by text,
    CONSTRAINT ledger_period_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES app.legal_entity(id),
    CONSTRAINT ledger_period_pkey PRIMARY KEY (id),
    CONSTRAINT ledger_period_entity_id_period_key UNIQUE (entity_id, period)
);

CREATE TABLE app.lsgd (
    id uuid NOT NULL DEFAULT uuidv7(),
    assembly_id uuid,
    type app.lsgd_type NOT NULL,
    name text NOT NULL,
    code text NOT NULL DEFAULT ''::text,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    agent_id bigint,
    prefix_code text NOT NULL DEFAULT ''::text,
    CONSTRAINT lsgd_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES app.agent(id) ON DELETE SET NULL,
    CONSTRAINT lsgd_assembly_id_fkey FOREIGN KEY (assembly_id) REFERENCES app.assembly(id) ON DELETE RESTRICT,
    CONSTRAINT lsgd_pkey PRIMARY KEY (id),
    CONSTRAINT lsgd_agent_id_key UNIQUE (agent_id),
    CONSTRAINT lsgd_parent_name_key UNIQUE (assembly_id, name)
);

CREATE TABLE app.membership_tier_load (
    id bigint GENERATED ALWAYS AS IDENTITY,
    tier_id bigint NOT NULL,
    amount numeric(12,2) NOT NULL,
    sort integer NOT NULL DEFAULT 0,
    CONSTRAINT membership_tier_load_tier_id_fkey FOREIGN KEY (tier_id) REFERENCES app.membership_tier(id) ON DELETE CASCADE,
    CONSTRAINT membership_tier_load_pkey PRIMARY KEY (id),
    CONSTRAINT membership_tier_load_tier_id_amount_key UNIQUE (tier_id, amount)
);

CREATE TABLE app.notification (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    member_id bigint NOT NULL,
    title text NOT NULL,
    body text NOT NULL DEFAULT ''::text,
    channel text NOT NULL DEFAULT 'PUSH'::text,
    status app.notification_status NOT NULL DEFAULT 'QUEUED'::app.notification_status,
    deep_link text,
    sent_at timestamptz,
    read_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT notification_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT notification_pkey PRIMARY KEY (id)
);

CREATE TABLE app.order_line (
    id bigint GENERATED ALWAYS AS IDENTITY,
    order_id bigint NOT NULL,
    product_id bigint,
    name text NOT NULL,
    pack text NOT NULL DEFAULT ''::text,
    unit_price numeric(12,2) NOT NULL DEFAULT 0,
    mrp numeric(12,2) NOT NULL DEFAULT 0,
    qty integer NOT NULL DEFAULT 1,
    stock_status app.order_line_status NOT NULL DEFAULT 'AVAILABLE'::app.order_line_status,
    CONSTRAINT order_line_order_id_fkey FOREIGN KEY (order_id) REFERENCES app."order"(id) ON DELETE CASCADE,
    CONSTRAINT order_line_product_id_fkey FOREIGN KEY (product_id) REFERENCES app.product(id) ON DELETE SET NULL,
    CONSTRAINT order_line_pkey PRIMARY KEY (id)
);

CREATE TABLE app.order_receipt (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    order_id bigint NOT NULL,
    payer_name text,
    reference text,
    amount numeric(12,2),
    storage_path text,
    file_name text,
    mime_type text,
    uploaded_at timestamptz NOT NULL DEFAULT now(),
    verified_at timestamptz,
    image text,
    CONSTRAINT order_receipt_order_id_fkey FOREIGN KEY (order_id) REFERENCES app."order"(id) ON DELETE CASCADE,
    CONSTRAINT order_receipt_pkey PRIMARY KEY (id)
);

CREATE TABLE app.order_track_step (
    id bigint GENERATED ALWAYS AS IDENTITY,
    order_id bigint NOT NULL,
    sort integer NOT NULL DEFAULT 0,
    title text NOT NULL,
    detail text,
    state app.track_state NOT NULL DEFAULT 'UPCOMING'::app.track_state,
    occurred_at timestamptz,
    CONSTRAINT order_track_step_order_id_fkey FOREIGN KEY (order_id) REFERENCES app."order"(id) ON DELETE CASCADE,
    CONSTRAINT order_track_step_pkey PRIMARY KEY (id)
);

CREATE TABLE app.posting_rule (
    id bigint GENERATED ALWAYS AS IDENTITY,
    event text NOT NULL,
    line_role text NOT NULL,
    account_code text NOT NULL,
    is_provisional boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT posting_rule_account_code_fkey FOREIGN KEY (account_code) REFERENCES app.chart_of_account(code),
    CONSTRAINT posting_rule_pkey PRIMARY KEY (id),
    CONSTRAINT posting_rule_event_line_role_key UNIQUE (event, line_role)
);

CREATE TABLE app.prescription_image (
    id bigint GENERATED ALWAYS AS IDENTITY,
    prescription_id bigint NOT NULL,
    sort integer NOT NULL DEFAULT 0,
    image text NOT NULL,
    image_rotation smallint NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT prescription_image_prescription_id_fkey FOREIGN KEY (prescription_id) REFERENCES app.prescription(id) ON DELETE CASCADE,
    CONSTRAINT prescription_image_pkey PRIMARY KEY (id)
);

CREATE TABLE app.prescription_medicine (
    id bigint GENERATED ALWAYS AS IDENTITY,
    prescription_id bigint NOT NULL,
    sort integer NOT NULL DEFAULT 0,
    name text NOT NULL,
    pack text NOT NULL DEFAULT ''::text,
    dose_morning integer NOT NULL DEFAULT 0,
    dose_afternoon integer NOT NULL DEFAULT 0,
    dose_night integer NOT NULL DEFAULT 0,
    product_id bigint,
    total_units integer NOT NULL DEFAULT 0,
    route_time text NOT NULL DEFAULT ''::text,
    status app.prescription_medicine_status NOT NULL DEFAULT 'AVAILABLE'::app.prescription_medicine_status,
    CONSTRAINT prescription_medicine_prescription_id_fkey FOREIGN KEY (prescription_id) REFERENCES app.prescription(id) ON DELETE CASCADE,
    CONSTRAINT prescription_medicine_product_id_fkey FOREIGN KEY (product_id) REFERENCES app.product(id) ON DELETE SET NULL,
    CONSTRAINT prescription_medicine_pkey PRIMARY KEY (id)
);

CREATE TABLE app.prescription_order (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    prescription_id bigint NOT NULL,
    order_id bigint,
    store_id bigint,
    status text NOT NULL DEFAULT 'SUBMITTED'::text,
    customer_notes text,
    submitted_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT prescription_order_order_id_fkey FOREIGN KEY (order_id) REFERENCES app."order"(id) ON DELETE SET NULL,
    CONSTRAINT prescription_order_prescription_id_fkey FOREIGN KEY (prescription_id) REFERENCES app.prescription(id) ON DELETE CASCADE,
    CONSTRAINT prescription_order_store_id_fkey FOREIGN KEY (store_id) REFERENCES app.shield_store(id) ON DELETE SET NULL,
    CONSTRAINT prescription_order_pkey PRIMARY KEY (id)
);

CREATE TABLE app.product_detail (
    product_id bigint NOT NULL,
    form text,
    manufacturer text,
    description text NOT NULL DEFAULT ''::text,
    ingredients text NOT NULL DEFAULT ''::text,
    storage text NOT NULL DEFAULT ''::text,
    highlights text[] NOT NULL DEFAULT '{}'::text[],
    benefits text[] NOT NULL DEFAULT '{}'::text[],
    directions text[] NOT NULL DEFAULT '{}'::text[],
    safety text[] NOT NULL DEFAULT '{}'::text[],
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT product_detail_product_id_fkey FOREIGN KEY (product_id) REFERENCES app.product(id) ON DELETE CASCADE,
    CONSTRAINT product_detail_pkey PRIMARY KEY (product_id)
);

CREATE TABLE app.product_faq (
    id bigint GENERATED ALWAYS AS IDENTITY,
    product_id bigint NOT NULL,
    question text NOT NULL,
    answer text NOT NULL,
    sort integer NOT NULL DEFAULT 0,
    CONSTRAINT product_faq_product_id_fkey FOREIGN KEY (product_id) REFERENCES app.product(id) ON DELETE CASCADE,
    CONSTRAINT product_faq_pkey PRIMARY KEY (id)
);

CREATE TABLE app.product_image (
    id bigint GENERATED ALWAYS AS IDENTITY,
    product_id bigint NOT NULL,
    image text NOT NULL,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT product_image_product_id_fkey FOREIGN KEY (product_id) REFERENCES app.product(id) ON DELETE CASCADE,
    CONSTRAINT product_image_pkey PRIMARY KEY (id)
);

CREATE TABLE app.promo (
    id bigint GENERATED ALWAYS AS IDENTITY,
    title_top text,
    title_middle text,
    title_accent text,
    title_tail text,
    cta text,
    code text,
    percent text,
    background text,
    starts_on date,
    ends_on date,
    is_active boolean NOT NULL DEFAULT true,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT promo_pkey PRIMARY KEY (id)
);

CREATE TABLE app.referral (
    id bigint GENERATED ALWAYS AS IDENTITY,
    uuid uuid NOT NULL DEFAULT gen_random_uuid(),
    inviter_member_id bigint NOT NULL,
    invitee_member_id bigint,
    invitee_phone text,
    code_used text,
    status app.referral_status NOT NULL DEFAULT 'SHARED'::app.referral_status,
    plan_amount numeric(12,2),
    commission_amount numeric(12,2) NOT NULL DEFAULT 0,
    registered_at timestamptz,
    transacted_at timestamptz,
    plan_activated_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT referral_invitee_member_id_fkey FOREIGN KEY (invitee_member_id) REFERENCES app.users(id) ON DELETE SET NULL,
    CONSTRAINT referral_inviter_member_id_fkey FOREIGN KEY (inviter_member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT referral_pkey PRIMARY KEY (id)
);

CREATE TABLE app.referral_level (
    id bigint GENERATED ALWAYS AS IDENTITY,
    level integer NOT NULL,
    name text NOT NULL,
    referrals_required integer NOT NULL,
    points integer NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT referral_level_pkey PRIMARY KEY (id),
    CONSTRAINT referral_level_level_key UNIQUE (level)
);

CREATE TABLE app.reward_point_transaction (
    id bigint GENERATED ALWAYS AS IDENTITY,
    member_id bigint NOT NULL,
    points integer NOT NULL,
    reason app.reward_txn_reason NOT NULL,
    ref_type text,
    ref_id bigint,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT reward_point_transaction_member_id_fkey FOREIGN KEY (member_id) REFERENCES app.users(id) ON DELETE CASCADE,
    CONSTRAINT reward_point_transaction_pkey PRIMARY KEY (id)
);

CREATE TABLE app.staff_audit_log (
    id bigint GENERATED ALWAYS AS IDENTITY,
    staff_id bigint,
    staff_login_id text NOT NULL,
    staff_name text NOT NULL,
    staff_role text NOT NULL,
    store_id bigint,
    action text NOT NULL,
    method text NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    request_body jsonb,
    ip text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT staff_audit_log_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES app.admin_user(id) ON DELETE SET NULL,
    CONSTRAINT staff_audit_log_store_id_fkey FOREIGN KEY (store_id) REFERENCES app.shield_store(id) ON DELETE SET NULL,
    CONSTRAINT staff_audit_log_pkey PRIMARY KEY (id)
);

CREATE TABLE app.ward (
    id uuid NOT NULL DEFAULT uuidv7(),
    lsgd_id uuid NOT NULL,
    ward_number integer NOT NULL,
    name text NOT NULL DEFAULT ''::text,
    code text NOT NULL DEFAULT ''::text,
    sort integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    agent_id bigint,
    prefix_code text NOT NULL DEFAULT ''::text,
    CONSTRAINT ward_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES app.agent(id) ON DELETE SET NULL,
    CONSTRAINT ward_lsgd_id_fkey FOREIGN KEY (lsgd_id) REFERENCES app.lsgd(id) ON DELETE RESTRICT,
    CONSTRAINT ward_pkey PRIMARY KEY (id),
    CONSTRAINT ward_agent_id_key UNIQUE (agent_id),
    CONSTRAINT ward_parent_number_key UNIQUE (lsgd_id, ward_number)
);

-- ---- Functions ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.advance_referral_on_paid_order()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_inviter_id bigint;
BEGIN
    -- The one referral this member was invited by; only ever moves forward.
    UPDATE app.referral
       SET status = 'TRANSACTED', transacted_at = now()
     WHERE invitee_member_id = NEW.member_id
       AND status = 'REGISTERED'
    RETURNING inviter_member_id INTO v_inviter_id;

    IF v_inviter_id IS NOT NULL THEN
        -- Pays every level the inviter has now crossed, once each.
        PERFORM app.award_referral_level_points(v_inviter_id);
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION app.approve_wallet_card_activation(p_card_id bigint)
 RETURNS TABLE(approved_id bigint)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_wallet_id          bigint;
    v_member_id          bigint;
    v_tier_id            bigint;
    v_amount             numeric(12,2);
    v_bonus              numeric(12,2);
    v_tier_name          text;
    v_sold_by_agent_id   bigint;
    v_seller_id          bigint;
    v_seller_level       app.agent_level;
    v_pool                numeric(12,2);
    v_direct_share        numeric(12,2);
    v_distributed          numeric(12,2) := 0;
    v_ancestor_id         bigint;
    v_credit_id           bigint;
    v_hop_share           numeric(12,2);
    v_hop_rates           numeric[] := ARRAY[0.10, 0.06, 0.05, 0.04, 0.03, 0.02];
    v_hop                 int;
    v_reserve             numeric(12,2);
    v_referrer_id         bigint;
    v_referral_commission numeric(12,2);
    v_referrer_wallet_id  bigint;
    v_referral_id         bigint;
    v_company_share       numeric(12,2);
    -- ledger posting (migration 0075)
    v_received            numeric(12,2);
    v_entity_id            bigint;
    v_entry_id             uuid;
    v_acct_cash            bigint;
    v_acct_due             bigint;
    -- ledger posting (migration 0076; provisional) — Head Office side
    v_hq_entity_id         bigint;
    v_hq_entry_id          uuid;
    v_acct_due_from        bigint;
    v_acct_wallet          bigint;
    v_acct_agent_payable   bigint;
    v_acct_reserve_company bigint;
    v_acct_reserve_pool    bigint;
    v_acct_bonus_expense   bigint;
    v_acct_commission_exp  bigint;
    v_acct_suspense        bigint;
    v_plug                 numeric(12,2);
BEGIN
    UPDATE app.wallet_card
       SET status = 'APPROVED', reviewed_at = now()
     WHERE id = p_card_id AND status IN ('PENDING', 'ON_HOLD')
     RETURNING wallet_id, tier_id, amount, bonus, sold_by_agent_id
       INTO v_wallet_id, v_tier_id, v_amount, v_bonus, v_sold_by_agent_id;

    IF NOT FOUND THEN
        RETURN; -- already decided, or not a real card id — no rows out
    END IF;

    SELECT member_id INTO v_member_id FROM app.wallet WHERE id = v_wallet_id;
    SELECT name INTO v_tier_name FROM app.membership_tier WHERE id = v_tier_id;

    INSERT INTO app.wallet_entry (wallet_id, kind, label, amount, occurred_on, wallet_card_id)
    VALUES (v_wallet_id, 'ACTIVATION', v_tier_name || ' activation', v_amount, current_date, p_card_id);

    IF v_bonus > 0 THEN
        INSERT INTO app.wallet_entry (wallet_id, kind, label, amount, occurred_on, wallet_card_id)
        VALUES (v_wallet_id, 'BONUS', v_tier_name || ' bonus · 10%', v_bonus, current_date, p_card_id);
    END IF;

    UPDATE app.wallet
       SET balance    = balance + v_amount + v_bonus,
           opened_at  = COALESCE(opened_at, now()),
           updated_at = now()
     WHERE id = v_wallet_id;

    -- Unchanged from the pre-existing behaviour: the agent portal's own
    -- "Direct sale" / "Team sales" screens are worked out from this table,
    -- independent of the commission money below.
    INSERT INTO app.agent_customer_plan (agent_customer_id, tier_id, amount, activated_on, wallet_card_id)
    SELECT ac.id, v_tier_id, v_amount, current_date, p_card_id
    FROM app.agent_customer ac
    WHERE ac.member_id = v_member_id;

    -- Agent commission split.
    SELECT COALESCE(
        v_sold_by_agent_id,
        (SELECT ac.agent_id FROM app.agent_customer ac WHERE ac.member_id = v_member_id LIMIT 1)
    ) INTO v_seller_id;

    IF v_seller_id IS NOT NULL THEN
        SELECT level INTO v_seller_level
        FROM app.agent
        WHERE id = v_seller_id AND approval_status = 'APPROVED';
    END IF;

    IF v_seller_level IS NOT NULL THEN
        v_pool := v_amount * 0.10;
        v_direct_share := ROUND(v_pool * 0.60, 2);

        UPDATE app.agent
           SET earned         = earned + v_direct_share,
               personal_sales = personal_sales + v_amount
         WHERE id = v_seller_id;

        -- migration 0079: the direct seller's own row (hop 0).
        INSERT INTO app.agent_commission (wallet_card_id, agent_id, hop, rate, amount)
        VALUES (p_card_id, v_seller_id, 0, 0.60, v_direct_share);

        v_distributed := v_direct_share;

        v_ancestor_id := v_seller_id;
        FOR v_hop IN 1..array_length(v_hop_rates, 1) LOOP
            SELECT parent_id INTO v_ancestor_id FROM app.agent WHERE id = v_ancestor_id;
            EXIT WHEN v_ancestor_id IS NULL;

            SELECT id INTO v_credit_id
            FROM app.agent
            WHERE id = v_ancestor_id AND approval_status = 'APPROVED';

            IF v_credit_id IS NOT NULL THEN
                v_hop_share := ROUND(v_pool * v_hop_rates[v_hop], 2);
                UPDATE app.agent SET earned = earned + v_hop_share WHERE id = v_credit_id;

                -- migration 0079: this ancestor's own row (hop = v_hop).
                INSERT INTO app.agent_commission (wallet_card_id, agent_id, hop, rate, amount)
                VALUES (p_card_id, v_credit_id, v_hop, v_hop_rates[v_hop], v_hop_share);

                v_distributed := v_distributed + v_hop_share;
            END IF;
        END LOOP;

        v_reserve := ROUND(v_pool - v_distributed, 2);
        IF v_reserve > 0 THEN
            INSERT INTO app.commission_reserve_entry (wallet_card_id, amount, source)
            VALUES (p_card_id, v_reserve, 'POOL_LEFTOVER');
        END IF;
    END IF;

    -- The company's own 8% of the load, on EVERY approved activation -- whether
    -- or not an agent sold it, and whether or not the member was referred.
    -- Company money: it only lands in the Reserved ledger, never in a member's
    -- or an agent's wallet. Independent of the leftover entry above, which is
    -- the unspent part of the agent pool and exists only for agent sales.
    v_company_share := ROUND(v_amount * 0.08, 2);
    IF v_company_share > 0 THEN
        INSERT INTO app.commission_reserve_entry (wallet_card_id, amount, source)
        VALUES (p_card_id, v_company_share, 'COMPANY_SHARE');
    END IF;

    -- Member-to-member referral commission -- every plan this member
    -- activates, not just their first, pays whoever referred them (if
    -- anyone did) 2% of the load. Independent of the agent split above.
    SELECT referred_by_member_id INTO v_referrer_id FROM app.users WHERE id = v_member_id;

    IF v_referrer_id IS NOT NULL THEN
        v_referral_commission := ROUND(v_amount * 0.02, 2);

        SELECT id INTO v_referrer_wallet_id FROM app.wallet WHERE member_id = v_referrer_id;
        IF v_referrer_wallet_id IS NULL THEN
            INSERT INTO app.wallet (member_id) VALUES (v_referrer_id) RETURNING id INTO v_referrer_wallet_id;
        END IF;

        INSERT INTO app.wallet_entry (wallet_id, kind, label, amount, occurred_on, wallet_card_id)
        VALUES (v_referrer_wallet_id, 'REFERRAL_EARNINGS', 'Referral commission', v_referral_commission, current_date, p_card_id);

        UPDATE app.wallet
           SET balance = balance + v_referral_commission, updated_at = now()
         WHERE id = v_referrer_wallet_id;

        -- The most recent edge for this exact pair, if one already exists
        -- (from apply-code REGISTERED, or an earlier order's TRANSACTED) --
        -- this activation is otherwise the first evidence of the edge.
        SELECT id INTO v_referral_id
        FROM app.referral
        WHERE inviter_member_id = v_referrer_id AND invitee_member_id = v_member_id
        ORDER BY id DESC
        LIMIT 1;

        IF v_referral_id IS NOT NULL THEN
            UPDATE app.referral
               SET status = 'PLAN_ACTIVATED',
                   plan_amount = v_amount,
                   commission_amount = commission_amount + v_referral_commission,
                   plan_activated_at = now()
             WHERE id = v_referral_id;
        ELSE
            INSERT INTO app.referral (inviter_member_id, invitee_member_id, status, plan_amount, commission_amount, plan_activated_at)
            VALUES (v_referrer_id, v_member_id, 'PLAN_ACTIVATED', v_amount, v_referral_commission, now());
        END IF;

        PERFORM app.award_referral_level_points(v_referrer_id);
    END IF;

    -- ---- ledger posting (migration 0075; provisional) --------------------
    -- Only the store's own cash receipt: Dr Cash — store, Cr Due to Head
    -- Office, for whatever was actually received (received_amount, falling
    -- back to the load amount when no receipt figure was recorded). See
    -- this migration's header for why nothing else from this function is
    -- posted yet.
    BEGIN
        SELECT s.entity_id, COALESCE(wc.received_amount, v_amount)
          INTO v_entity_id, v_received
          FROM app.wallet_card wc
          JOIN app.shield_store s ON s.id = wc.store_id
         WHERE wc.id = p_card_id;

        IF v_entity_id IS NOT NULL AND v_received > 0 THEN
            v_acct_cash := app.ledger_account('activation_received', 'cash_in');
            v_acct_due  := app.ledger_account('activation_received', 'due_to_head_office');

            IF v_acct_cash IS NOT NULL AND v_acct_due IS NOT NULL THEN
                PERFORM app.assert_ledger_period_open(v_entity_id, current_date);

                INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
                VALUES (v_entity_id, current_date, 'wallet_card', p_card_id::text, 'activation_received',
                        'Health Pass activation received at store')
                RETURNING id INTO v_entry_id;

                INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES
                    (v_entry_id, v_acct_cash, v_received, 0),
                    (v_entry_id, v_acct_due, 0, v_received);

                PERFORM app.assert_journal_entry_balanced(v_entry_id);
            END IF;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Ledger posting skipped for wallet_card %: %', p_card_id, SQLERRM;
    END;

    -- ---- ledger posting (migration 0076; provisional) ----------------------
    -- The Head Office side deferred in migration 0075: the member wallet
    -- credit, the bonus, the agent commissions and the reserves this
    -- activation creates — none of them tied to one shop (see that
    -- migration's own header). Whatever is left after those known pieces
    -- and the store's own cash receipt (v_received) is posted to Suspense,
    -- not guessed at: that gap is exactly the revenue-recognition question
    -- (is the bonus/commission a day-1 cost, or funded from margin earned
    -- later when the member spends their wallet?) that needs the
    -- accountant's answer before this account can be reclassified. Never
    -- blocks the real approval — see migration 0075's header for why.
    BEGIN
        SELECT id INTO v_hq_entity_id FROM app.legal_entity WHERE code = 'HQ';
        -- Independent of the store block above: known from the card alone,
        -- so this still posts even when the card has no store/entity.
        SELECT COALESCE(received_amount, v_amount) INTO v_received FROM app.wallet_card WHERE id = p_card_id;

        IF v_hq_entity_id IS NOT NULL THEN
            v_acct_due_from        := app.ledger_account('activation_received', 'due_from_store');
            v_acct_wallet          := app.ledger_account('activation_received', 'member_wallet');
            v_acct_agent_payable   := app.ledger_account('activation_received', 'agent_commission');
            v_acct_reserve_company := app.ledger_account('activation_received', 'reserve_company');
            v_acct_reserve_pool    := app.ledger_account('activation_received', 'reserve_pool');
            v_acct_bonus_expense   := app.ledger_account('activation_received', 'bonus_expense');
            v_acct_commission_exp  := app.ledger_account('activation_received', 'agent_commission_expense');
            v_acct_suspense        := app.ledger_account('activation_received', 'suspense');

            IF v_acct_due_from IS NOT NULL AND v_acct_wallet IS NOT NULL AND v_acct_suspense IS NOT NULL THEN
                PERFORM app.assert_ledger_period_open(v_hq_entity_id, current_date);

                INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
                VALUES (v_hq_entity_id, current_date, 'wallet_card', p_card_id::text, 'activation_received',
                        'Health Pass activation booked at Head Office — provisional, pending revenue-recognition review')
                RETURNING id INTO v_hq_entry_id;

                INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                VALUES (v_hq_entry_id, v_acct_due_from, v_received, 0);

                IF v_bonus > 0 AND v_acct_bonus_expense IS NOT NULL THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_bonus_expense, v_bonus, 0);
                END IF;

                IF v_distributed > 0 AND v_acct_commission_exp IS NOT NULL THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_commission_exp, v_distributed, 0);
                END IF;

                INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                VALUES (v_hq_entry_id, v_acct_wallet, 0, v_amount + v_bonus);

                IF v_referral_commission > 0 THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_wallet, 0, v_referral_commission);
                END IF;

                IF v_distributed > 0 AND v_acct_agent_payable IS NOT NULL THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_agent_payable, 0, v_distributed);

                    -- migration 0079: every agent_commission row this
                    -- activation created now traces to the journal entry
                    -- whose 'agent_commission' line actually carries their
                    -- total — so "who got paid from this entry" is a join,
                    -- not a guess, going forward.
                    UPDATE app.agent_commission
                       SET journal_entry_id = v_hq_entry_id
                     WHERE wallet_card_id = p_card_id AND journal_entry_id IS NULL;
                END IF;

                IF v_company_share > 0 AND v_acct_reserve_company IS NOT NULL THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_reserve_company, 0, v_company_share);
                END IF;

                IF v_reserve > 0 AND v_acct_reserve_pool IS NOT NULL THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_reserve_pool, 0, v_reserve);
                END IF;

                SELECT COALESCE(SUM(credit), 0) - COALESCE(SUM(debit), 0) INTO v_plug
                  FROM app.journal_line WHERE entry_id = v_hq_entry_id;

                IF v_plug > 0 THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_suspense, v_plug, 0);
                ELSIF v_plug < 0 THEN
                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit)
                    VALUES (v_hq_entry_id, v_acct_suspense, 0, -v_plug);
                END IF;

                PERFORM app.assert_journal_entry_balanced(v_hq_entry_id);
            END IF;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Head Office ledger posting skipped for wallet_card %: %', p_card_id, SQLERRM;
    END;

    RETURN QUERY SELECT p_card_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION app.assert_journal_entry_balanced(p_entry_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_debit  numeric(12,2);
    v_credit numeric(12,2);
BEGIN
    SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
      INTO v_debit, v_credit
      FROM app.journal_line WHERE entry_id = p_entry_id;

    IF v_debit <> v_credit THEN
        RAISE EXCEPTION 'Journal entry % does not balance: debit % <> credit %',
            p_entry_id, v_debit, v_credit;
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION app.assert_ledger_period_open(p_entity_id bigint, p_on date)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF EXISTS (
        SELECT 1 FROM app.ledger_period
        WHERE entity_id = p_entity_id
          AND period = date_trunc('month', p_on)::date
          AND closed_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'The ledger period for entity % covering % is closed', p_entity_id, p_on;
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION app.award_referral_level_points(p_inviter_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_direct_referrals integer;
    v_already_awarded  integer;
    v_new_points       integer;
    v_new_level        integer;
    -- ledger posting (migration 0077; provisional)
    v_reward_txn_id    bigint;
    v_hq_entity_id     bigint;
    v_entry_id         uuid;
    v_acct_expense     bigint;
    v_acct_liability   bigint;
    v_rupees           numeric(12,2);
BEGIN
    SELECT COUNT(*) INTO v_direct_referrals
    FROM app.referral
    WHERE inviter_member_id = p_inviter_id
      AND status IN ('TRANSACTED', 'PLAN_ACTIVATED');

    SELECT COALESCE(referral_level_awarded, 0) INTO v_already_awarded
    FROM app.users WHERE id = p_inviter_id;

    SELECT COALESCE(SUM(points), 0), COALESCE(MAX(level), v_already_awarded)
      INTO v_new_points, v_new_level
    FROM app.referral_level
    WHERE level > v_already_awarded AND referrals_required <= v_direct_referrals;

    IF v_new_points > 0 THEN
        INSERT INTO app.reward_point_transaction (member_id, points, reason, note)
        VALUES (p_inviter_id, v_new_points, 'REFERRAL_LEVEL', 'Referral ladder — level ' || v_new_level)
        RETURNING id INTO v_reward_txn_id;

        UPDATE app.users
           SET reward_points = reward_points + v_new_points,
               referral_level_awarded = v_new_level
         WHERE id = p_inviter_id;

        -- ---- ledger posting (migration 0077; provisional) --------------------
        BEGIN
            SELECT id INTO v_hq_entity_id FROM app.legal_entity WHERE code = 'HQ';
            IF v_hq_entity_id IS NOT NULL THEN
                v_acct_expense   := app.ledger_account('reward_points_issued', 'expense');
                v_acct_liability := app.ledger_account('reward_points_issued', 'liability');

                IF v_acct_expense IS NOT NULL AND v_acct_liability IS NOT NULL THEN
                    PERFORM app.assert_ledger_period_open(v_hq_entity_id, current_date);
                    v_rupees := ROUND(v_new_points / 100.0, 2);

                    INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
                    VALUES (v_hq_entity_id, current_date, 'reward_point_transaction', v_reward_txn_id::text, 'reward_points_issued',
                            v_new_points || ' reward points awarded — referral ladder level ' || v_new_level)
                    RETURNING id INTO v_entry_id;

                    INSERT INTO app.journal_line (entry_id, account_id, debit, credit) VALUES
                        (v_entry_id, v_acct_expense, v_rupees, 0),
                        (v_entry_id, v_acct_liability, 0, v_rupees);

                    PERFORM app.assert_journal_entry_balanced(v_entry_id);
                END IF;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Ledger posting skipped for reward_point_transaction %: %', v_reward_txn_id, SQLERRM;
        END;
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION app.generate_referral_code()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_code text;
    v_try  integer := 0;
BEGIN
    LOOP
        v_try := v_try + 1;
        IF v_try <= 40 THEN
            v_code := 'SAHAKAR-' || (1000 + floor(random() * 9000))::int;
        ELSE
            v_code := 'SAHAKAR-' || (10000 + floor(random() * 90000))::int;
        END IF;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM app.users WHERE referral_code = v_code);
        IF v_try > 200 THEN
            RAISE EXCEPTION 'could not generate a free referral code';
        END IF;
    END LOOP;
    RETURN v_code;
END;
$function$
;

CREATE OR REPLACE FUNCTION app.ledger_account(p_event text, p_line_role text)
 RETURNS bigint
 LANGUAGE sql
 STABLE
AS $function$
    SELECT ca.id FROM app.posting_rule pr
    JOIN app.chart_of_account ca ON ca.code = pr.account_code
    WHERE pr.event = p_event AND pr.line_role = p_line_role;
$function$
;

CREATE OR REPLACE FUNCTION app.move_agent_earnings_to_wallet(p_agent_id bigint, p_amount numeric)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
  a app.agent%ROWTYPE;
  held numeric;
  v_wallet_id bigint;
  v_balance numeric;
  v_wallet_entry_id bigint;
  v_hq_entity_id bigint;
  v_entry_id uuid;
  v_acct_payable bigint;
  v_acct_wallet bigint;
BEGIN
  SELECT * INTO a FROM app.agent WHERE id = p_agent_id FOR UPDATE;
  IF NOT FOUND OR a.approval_status <> 'APPROVED' OR NOT a.active THEN
    RAISE EXCEPTION 'Only an active approved agent can add earnings to a wallet';
  END IF;
  IF a.member_id IS NULL THEN
    RAISE EXCEPTION 'This agent has no member account to hold a wallet';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount <> round(p_amount, 2) THEN
    RAISE EXCEPTION 'Enter a valid amount to add';
  END IF;
  SELECT coalesce(sum(amount), 0) INTO held FROM app.agent_withdrawal
    WHERE agent_id = a.id AND status = 'PENDING';
  IF p_amount > a.earned - a.redeemed - held THEN
    RAISE EXCEPTION 'Amount exceeds your available earnings after pending withdrawals';
  END IF;

  SELECT id INTO v_wallet_id FROM app.wallet WHERE member_id = a.member_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    INSERT INTO app.wallet (member_id) VALUES (a.member_id) RETURNING id INTO v_wallet_id;
  END IF;

  UPDATE app.agent SET redeemed = redeemed + p_amount WHERE id = a.id;
  INSERT INTO app.wallet_entry (wallet_id, kind, label, amount, occurred_on)
    VALUES (v_wallet_id, 'AGENT_EARNINGS', 'Agent commission · ' || a.code, p_amount, current_date)
    RETURNING id INTO v_wallet_entry_id;
  UPDATE app.wallet SET balance = balance + p_amount, updated_at = now()
    WHERE id = v_wallet_id RETURNING balance INTO v_balance;

  -- ---- ledger posting (migration 0075; provisional) ------------------------
  BEGIN
      SELECT id INTO v_hq_entity_id FROM app.legal_entity WHERE code = 'HQ';
      IF v_hq_entity_id IS NOT NULL THEN
          v_acct_payable := app.ledger_account('wallet_transfer', 'payable');
          v_acct_wallet := app.ledger_account('wallet_transfer', 'member_wallet');
          IF v_acct_payable IS NOT NULL AND v_acct_wallet IS NOT NULL THEN
              PERFORM app.assert_ledger_period_open(v_hq_entity_id, current_date);

              INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
              VALUES (v_hq_entity_id, current_date, 'wallet_entry', v_wallet_entry_id::text, 'wallet_transfer',
                      'Agent earnings moved to wallet - ' || a.code)
              RETURNING id INTO v_entry_id;

              -- subject_type/subject_id added (migration 0091): same
              -- underlying person, two different roles on the two lines —
              -- the payable side is them as an agent, the wallet side is
              -- them as a member.
              INSERT INTO app.journal_line (entry_id, account_id, debit, credit, subject_type, subject_id) VALUES
                  (v_entry_id, v_acct_payable, p_amount, 0, 'agent', a.id),
                  (v_entry_id, v_acct_wallet, 0, p_amount, 'member', a.member_id);

              PERFORM app.assert_journal_entry_balanced(v_entry_id);
          END IF;
      END IF;
  EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Ledger posting skipped for wallet_entry %: %', v_wallet_entry_id, SQLERRM;
  END;

  RETURN v_balance;
END $function$
;

CREATE OR REPLACE FUNCTION app.request_agent_withdrawal(p_agent_id bigint, p_amount numeric)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$
DECLARE a app.agent%ROWTYPE; held numeric; request_id bigint;
BEGIN
  SELECT * INTO a FROM app.agent WHERE id = p_agent_id FOR UPDATE;
  IF NOT FOUND OR a.approval_status <> 'APPROVED' OR NOT a.active THEN
    RAISE EXCEPTION 'Only an active approved agent can withdraw';
  END IF;
  IF p_amount IS NULL OR p_amount < 3000 OR p_amount <> round(p_amount, 2) THEN
    RAISE EXCEPTION 'Minimum withdrawal is Rs 3000; enter a valid amount';
  END IF;
  SELECT coalesce(sum(amount), 0) INTO held FROM app.agent_withdrawal
    WHERE agent_id = a.id AND status = 'PENDING';
  IF p_amount > a.earned - a.redeemed - held THEN
    RAISE EXCEPTION 'Amount exceeds available earnings after pending requests';
  END IF;
  IF trim(a.account_number) = '' THEN
    RAISE EXCEPTION 'Add your bank account before requesting a withdrawal';
  END IF;
  INSERT INTO app.agent_withdrawal(agent_id, amount) VALUES(a.id, p_amount)
    RETURNING id INTO request_id;
  RETURN request_id;
END $function$
;

CREATE OR REPLACE FUNCTION app.review_agent_withdrawal(p_id bigint, p_action text, p_reviewer text, p_account text, p_identity_verified boolean, p_earnings_verified boolean, p_note text, p_payment_reference text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  r app.agent_withdrawal%ROWTYPE;
  a app.agent%ROWTYPE;
  held numeric;
  v_hq_entity_id bigint;
  v_entry_id uuid;
  v_acct_payable bigint;
  v_acct_cash_out bigint;
BEGIN
  SELECT * INTO r FROM app.agent_withdrawal WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Withdrawal request not found'; END IF;
  SELECT * INTO a FROM app.agent WHERE id = r.agent_id FOR UPDATE;
  SELECT * INTO r FROM app.agent_withdrawal WHERE id = p_id FOR UPDATE;
  IF r.status <> 'PENDING' THEN RAISE EXCEPTION 'This request is already processed'; END IF;
  IF coalesce(trim(p_reviewer), '') = '' THEN RAISE EXCEPTION 'Reviewer is required'; END IF;
  IF p_action = 'REJECT' THEN
    IF coalesce(trim(p_note), '') = '' THEN RAISE EXCEPTION 'Enter a rejection reason'; END IF;
    UPDATE app.agent_withdrawal SET status = 'REJECTED', processed_on = current_date,
      processed_by = p_reviewer, verification_note = trim(p_note) WHERE id = p_id;
    RETURN;
  END IF;
  IF p_action NOT IN ('APPROVE', 'PAY') THEN RAISE EXCEPTION 'Invalid review action'; END IF;
  SELECT coalesce(sum(amount), 0) INTO held FROM app.agent_withdrawal
    WHERE agent_id = a.id AND status = 'PENDING';
  IF a.approval_status <> 'APPROVED' OR NOT a.active OR r.amount < 3000
     OR held > a.earned - a.redeemed THEN
    RAISE EXCEPTION 'Agent eligibility or available earnings changed; recheck this request';
  END IF;
  IF p_action = 'APPROVE' THEN
    IF r.approved_at IS NOT NULL THEN RAISE EXCEPTION 'Request is already approved'; END IF;
    IF p_identity_verified IS DISTINCT FROM true OR p_earnings_verified IS DISTINCT FROM true
       OR coalesce(trim(p_account), '') = '' OR trim(p_account) <> trim(a.account_number)
       OR coalesce(trim(p_note), '') = '' THEN
      RAISE EXCEPTION 'Verify identity, earnings and the matching bank account; enter your review note';
    END IF;
    UPDATE app.agent_withdrawal SET approved_at = now(), approved_by = p_reviewer,
      verified_account = trim(p_account), verification_note = trim(p_note) WHERE id = p_id;
  ELSE
    IF r.approved_at IS NULL THEN RAISE EXCEPTION 'Approve the request before recording payment'; END IF;
    IF r.verified_account IS DISTINCT FROM trim(a.account_number) THEN
      RAISE EXCEPTION 'Bank account changed after approval; reject and request again';
    END IF;
    IF coalesce(trim(p_payment_reference), '') = '' THEN RAISE EXCEPTION 'Payment reference is required'; END IF;
    UPDATE app.agent SET redeemed = redeemed + r.amount WHERE id = a.id;
    UPDATE app.agent_withdrawal SET status = 'PAID', processed_on = current_date,
      processed_by = p_reviewer, payment_reference = trim(p_payment_reference) WHERE id = p_id;

    -- ---- ledger posting (migration 0075; provisional) ----------------------
    BEGIN
        SELECT id INTO v_hq_entity_id FROM app.legal_entity WHERE code = 'HQ';
        IF v_hq_entity_id IS NOT NULL THEN
            v_acct_payable := app.ledger_account('withdrawal_paid', 'payable');
            v_acct_cash_out := app.ledger_account('withdrawal_paid', 'cash_out');
            IF v_acct_payable IS NOT NULL AND v_acct_cash_out IS NOT NULL THEN
                PERFORM app.assert_ledger_period_open(v_hq_entity_id, current_date);

                INSERT INTO app.journal_entry (entity_id, posted_on, source_table, source_id, event, description)
                VALUES (v_hq_entity_id, current_date, 'agent_withdrawal', p_id::text, 'withdrawal_paid',
                        'Agent withdrawal paid - ' || a.code)
                RETURNING id INTO v_entry_id;

                -- subject_type/subject_id added (migration 0091): this
                -- payable line is this one withdrawal's own agent.
                INSERT INTO app.journal_line (entry_id, account_id, debit, credit, subject_type, subject_id) VALUES
                    (v_entry_id, v_acct_payable, r.amount, 0, 'agent', a.id),
                    (v_entry_id, v_acct_cash_out, 0, r.amount, NULL, NULL);

                PERFORM app.assert_journal_entry_balanced(v_entry_id);
            END IF;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Ledger posting skipped for agent_withdrawal %: %', p_id, SQLERRM;
    END;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION app.touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION app.users_assign_referral_code()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.referral_code IS NULL OR NEW.referral_code = '' THEN
        NEW.referral_code := app.generate_referral_code();
    END IF;
    RETURN NEW;
END;
$function$
;

-- ---- Triggers ----------------------------------------------------------------
CREATE TRIGGER admin_user_touch BEFORE UPDATE ON app.admin_user FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER agent_touch BEFORE UPDATE ON app.agent FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER appointment_touch BEFORE UPDATE ON app.appointment FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER assembly_touch BEFORE UPDATE ON app.assembly FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER cart_touch BEFORE UPDATE ON app.cart FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER clinic_touch BEFORE UPDATE ON app.clinic FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER dietitian_touch BEFORE UPDATE ON app.dietitian FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER district_touch BEFORE UPDATE ON app.district FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER health_article_touch BEFORE UPDATE ON app.health_article FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER investor_touch BEFORE UPDATE ON app.investor FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER lab_booking_touch BEFORE UPDATE ON app.lab_booking FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER lab_category_touch BEFORE UPDATE ON app.lab_category FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER lab_package_touch BEFORE UPDATE ON app.lab_package FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER lab_test_touch BEFORE UPDATE ON app.lab_test FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER lsgd_touch BEFORE UPDATE ON app.lsgd FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER member_address_touch BEFORE UPDATE ON app.member_address FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER membership_tier_touch BEFORE UPDATE ON app.membership_tier FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER order_advance_referral AFTER INSERT OR UPDATE OF payment_status ON app."order" FOR EACH ROW WHEN ((new.payment_status = 'PAID'::app.order_payment_status)) EXECUTE FUNCTION app.advance_referral_on_paid_order();
CREATE TRIGGER order_touch BEFORE UPDATE ON app."order" FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER patient_touch BEFORE UPDATE ON app.patient FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER prescription_touch BEFORE UPDATE ON app.prescription FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER prescription_order_touch BEFORE UPDATE ON app.prescription_order FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER product_touch BEFORE UPDATE ON app.product FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER product_category_touch BEFORE UPDATE ON app.product_category FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER product_detail_touch BEFORE UPDATE ON app.product_detail FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER region_touch BEFORE UPDATE ON app.region FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER shield_store_touch BEFORE UPDATE ON app.shield_store FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER state_touch BEFORE UPDATE ON app.state FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER member_touch BEFORE UPDATE ON app.users FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER users_assign_referral_code BEFORE INSERT ON app.users FOR EACH ROW EXECUTE FUNCTION app.users_assign_referral_code();
CREATE TRIGGER wallet_touch BEFORE UPDATE ON app.wallet FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER ward_touch BEFORE UPDATE ON app.ward FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

-- ---- Indexes -----------------------------------------------------------------
CREATE INDEX agent_approval_status_idx ON app.agent USING btree (approval_status, created_at DESC);
CREATE INDEX agent_commission_agent_idx ON app.agent_commission USING btree (agent_id);
CREATE INDEX agent_commission_card_idx ON app.agent_commission USING btree (wallet_card_id);
CREATE INDEX agent_customer_agent_idx ON app.agent_customer USING btree (agent_id);
CREATE INDEX agent_parent_idx ON app.agent USING btree (parent_id);
CREATE INDEX agent_phone_idx ON app.agent USING btree (phone);
CREATE INDEX agent_request_parent_idx ON app.agent_request USING btree (parent_agent_id);
CREATE INDEX agent_request_phone_idx ON app.agent_request USING btree (phone);
CREATE INDEX agent_request_status_idx ON app.agent_request USING btree (status, created_at DESC);
CREATE INDEX agent_withdrawal_agent_idx ON app.agent_withdrawal USING btree (agent_id, created_at DESC);
CREATE INDEX appointment_member_idx ON app.appointment USING btree (member_id, created_at DESC);
CREATE INDEX approval_member_idx ON app.approval USING btree (member_id, created_at DESC);
CREATE INDEX assembly_district_idx ON app.assembly USING btree (district_id);
CREATE INDEX bill_line_bill_idx ON app.bill_line USING btree (bill_id);
CREATE INDEX cart_line_cart_idx ON app.cart_line USING btree (cart_id);
CREATE INDEX commission_reserve_entry_card_idx ON app.commission_reserve_entry USING btree (wallet_card_id);
CREATE INDEX customer_review_video_media_incomplete_idx ON app.customer_review_video_media USING btree (created_at) WHERE (upload_complete = false);
CREATE INDEX customer_review_video_sort_idx ON app.customer_review_video USING btree (sort);
CREATE INDEX district_state_idx ON app.district USING btree (state_id);
CREATE INDEX home_banner_placement_idx ON app.home_banner USING btree (placement, sort);
CREATE INDEX investor_phone_idx ON app.investor USING btree (phone);
CREATE INDEX journal_entry_entity_idx ON app.journal_entry USING btree (entity_id, posted_on);
CREATE INDEX journal_line_account_idx ON app.journal_line USING btree (account_id);
CREATE INDEX journal_line_entry_idx ON app.journal_line USING btree (entry_id);
CREATE INDEX journal_line_subject_idx ON app.journal_line USING btree (subject_type, subject_id, account_id);
CREATE INDEX lab_bill_line_bill_idx ON app.lab_bill_line USING btree (lab_bill_id);
CREATE INDEX lab_booking_member_idx ON app.lab_booking USING btree (member_id, created_at DESC);
CREATE INDEX lab_booking_report_booking_idx ON app.lab_booking_report USING btree (lab_booking_id, sort, id);
CREATE INDEX lab_booking_store_idx ON app.lab_booking USING btree (store_id);
CREATE INDEX lab_package_category_idx ON app.lab_package USING btree (category_id);
CREATE INDEX lab_package_extra_category_category_idx ON app.lab_package_extra_category USING btree (category_id);
CREATE INDEX lab_package_test_item_test_idx ON app.lab_package_test_item USING btree (test_id);
CREATE INDEX lab_test_category_idx ON app.lab_test USING btree (category_id);
CREATE INDEX lab_test_group_item_test_idx ON app.lab_test_group_item USING btree (test_id);
CREATE INDEX lab_test_source_idx ON app.lab_test USING btree (source, is_active);
CREATE INDEX lab_test_type_idx ON app.lab_test USING btree (test_type, is_active);
CREATE INDEX lsgd_assembly_idx ON app.lsgd USING btree (assembly_id);
CREATE INDEX lsgd_type_idx ON app.lsgd USING btree (type);
CREATE INDEX member_address_member_idx ON app.member_address USING btree (member_id) WHERE (deleted_at IS NULL);
CREATE INDEX notification_member_idx ON app.notification USING btree (member_id, created_at DESC);
CREATE INDEX order_line_order_idx ON app.order_line USING btree (order_id);
CREATE INDEX order_member_idx ON app."order" USING btree (member_id, placed_at DESC);
CREATE INDEX patient_member_idx ON app.patient USING btree (member_id) WHERE (deleted_at IS NULL);
CREATE INDEX prescription_image_prescription_idx ON app.prescription_image USING btree (prescription_id, sort);
CREATE INDEX prescription_member_idx ON app.prescription USING btree (member_id) WHERE (deleted_at IS NULL);
CREATE INDEX prescription_store_idx ON app.prescription USING btree (store_id);
CREATE INDEX product_category_idx ON app.product USING btree (category_id);
CREATE INDEX product_home_section_idx ON app.product USING btree (is_popular, is_deal, is_offer_of_day) WHERE (is_popular OR is_deal OR is_offer_of_day);
CREATE INDEX product_image_product_idx ON app.product_image USING btree (product_id, sort);
CREATE INDEX product_name_trgm ON app.product USING gin (lower(name) app.gin_trgm_ops);
CREATE INDEX referral_inviter_idx ON app.referral USING btree (inviter_member_id);
CREATE INDEX region_national_agent_idx ON app.region USING btree (national_agent_id);
CREATE INDEX reward_point_member_idx ON app.reward_point_transaction USING btree (member_id, created_at DESC);
CREATE INDEX staff_audit_log_created_idx ON app.staff_audit_log USING btree (created_at DESC);
CREATE INDEX staff_audit_log_staff_idx ON app.staff_audit_log USING btree (staff_id, created_at DESC);
CREATE INDEX state_region_idx ON app.state USING btree (region_id);
CREATE INDEX wallet_card_status_idx ON app.wallet_card USING btree (status, submitted_at DESC);
CREATE INDEX wallet_card_wallet_idx ON app.wallet_card USING btree (wallet_id);
CREATE INDEX wallet_entry_wallet_idx ON app.wallet_entry USING btree (wallet_id, created_at DESC);
CREATE INDEX ward_lsgd_idx ON app.ward USING btree (lsgd_id);

