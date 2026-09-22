import { newDb, DataType } from 'pg-mem';
import { drizzle } from 'drizzle-orm/node-postgres';
import type { Pool as PgPool } from 'pg';
import { randomUUID } from 'node:crypto';
import * as schema from '../../src/db/schema';

/**
 * An in-memory, wire-compatible Postgres for tests — proves the real SQL
 * (via Drizzle) against a real schema, without ever touching the shared
 * Neon dev database. Mirrors only the columns backend/docs/erd.md M1 scope
 * actually needs.
 */
export function createTestDb() {
  const mem = newDb({ autoCreateForeignKeyIndices: true });
  mem.public.registerFunction({ name: 'gen_random_uuid', returns: DataType.uuid, implementation: randomUUID });

  mem.public.none(`
    CREATE SCHEMA app;
    CREATE SCHEMA backend;
    CREATE TYPE app.admin_role AS ENUM ('SUPERADMIN','ADMIN','PHARMACY','LAB','APPOINTMENTS');
    CREATE TYPE app.gender AS ENUM ('MALE','FEMALE','OTHER');
    CREATE TYPE app.address_label AS ENUM ('HOME','WORK','OTHER');
    CREATE TYPE app.patient_relation AS ENUM ('SELF','SPOUSE','CHILD','PARENT','OTHER');
    CREATE TYPE app.cart_line_source AS ENUM ('SHOP','PRESCRIPTION');
    CREATE TYPE app.order_kind AS ENUM ('STANDARD','PRESCRIPTION');
    CREATE TYPE app.order_status AS ENUM ('PROCESSING','OUT_FOR_DELIVERY','DELIVERED','CANCELLED');
    CREATE TYPE app.track_state AS ENUM ('DONE','CURRENT','UPCOMING');
    CREATE TYPE app.fulfillment_type AS ENUM ('HOME_DELIVERY','STORE_PICKUP');
    CREATE TYPE app.order_payment_status AS ENUM ('PENDING','PAID');
    CREATE TYPE app.medicine_duration AS ENUM ('ONE_WEEK','FIFTEEN_DAYS','ONE_MONTH','TWO_MONTHS','THREE_MONTHS');
    CREATE TYPE app.prescription_status AS ENUM ('AWAITING_REVIEW','READ','IN_CART','ORDERED');
    CREATE TYPE app.prescription_medicine_status AS ENUM ('AVAILABLE','OUT_OF_STOCK','NOT_POSSIBLE','ORDERED');
    CREATE TYPE app.approval_status AS ENUM ('PENDING','APPROVED','PARTIALLY_APPROVED','REJECTED','CANCELLED','ON_HOLD');
    CREATE TYPE app.privilege_card_kind AS ENUM ('SILVER','GOLD','PLATINUM');
    CREATE TYPE app.wallet_entry_kind AS ENUM ('ACTIVATION','BONUS','TOPUP','SPEND','POINTS_REDEEMED','AGENT_EARNINGS','REFERRAL_EARNINGS');
    CREATE TYPE app.reward_txn_reason AS ENUM ('REGISTRATION','REFERRAL_LEVEL','ORDER','REDEMPTION','ADJUSTMENT');
    CREATE TYPE app.referral_status AS ENUM ('SHARED','REGISTERED','TRANSACTED','PLAN_ACTIVATED');
    CREATE TYPE app.appointment_kind AS ENUM ('CLINIC','TELE','DENTAL','DIETITIAN');
    CREATE TYPE app.appointment_status AS ENUM ('REQUESTED','CONFIRMED','COMPLETED','CANCELLED');
    CREATE TYPE app.lab_booking_status AS ENUM ('REQUESTED','CONFIRMED','SAMPLE_COLLECTED','REPORT_READY','CANCELLED');
    CREATE TYPE app.agent_level AS ENUM ('NATIONAL','REGION','STATE','DISTRICT','ASSEMBLY','LSGD','WARD');
    CREATE TYPE app.agent_approval AS ENUM ('PENDING','APPROVED','REJECTED');
    CREATE TYPE app.withdrawal_status AS ENUM ('PENDING','PAID','REJECTED');
    CREATE TYPE app.investor_plan_type AS ENUM ('YEARLY','MONTHLY');
    CREATE TYPE app.plan_change_status AS ENUM ('REQUESTED','APPROVED','REJECTED');
    CREATE TYPE backend_subject_type AS ENUM ('MEMBER','STAFF');

    CREATE TABLE app.users (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      phone text NOT NULL UNIQUE,
      name text NOT NULL,
      firebase_uid text UNIQUE,
      email text,
      gender app.gender,
      dob date,
      address text,
      place text,
      pincode text,
      state text,
      home_store_id bigint,
      reward_points integer NOT NULL DEFAULT 0,
      referral_code text UNIQUE,
      referred_by_member_id bigint,
      referral_level_awarded integer NOT NULL DEFAULT 0,
      registration_completed_at timestamptz,
      registration_prompt_dismissed boolean NOT NULL DEFAULT false,
      last_login_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      deleted_at timestamptz
    );

    CREATE TABLE app.member_address (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      member_id bigint NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
      label app.address_label NOT NULL DEFAULT 'HOME',
      house text NOT NULL,
      area text NOT NULL,
      landmark text NOT NULL DEFAULT '',
      pincode text NOT NULL,
      city text,
      state text,
      first_name text NOT NULL DEFAULT '',
      last_name text NOT NULL DEFAULT '',
      phone text NOT NULL DEFAULT '',
      patient_id bigint,
      is_default boolean NOT NULL DEFAULT false,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      deleted_at timestamptz
    );

    CREATE TABLE app.patient (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      member_id bigint NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
      name text NOT NULL,
      phone text NOT NULL DEFAULT '',
      address text NOT NULL DEFAULT '',
      dob date NOT NULL,
      gender app.gender NOT NULL DEFAULT 'OTHER',
      relation app.patient_relation NOT NULL DEFAULT 'SELF',
      abha_id text NOT NULL DEFAULT '',
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      deleted_at timestamptz
    );

    CREATE TABLE app.admin_user (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      firebase_uid text UNIQUE,
      login_id text NOT NULL UNIQUE,
      name text NOT NULL,
      password_hash text,
      role app.admin_role NOT NULL DEFAULT 'PHARMACY',
      store_id bigint,
      avatar_color text NOT NULL DEFAULT '#2c57a6',
      is_active boolean NOT NULL DEFAULT true,
      last_login_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.shield_store (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      code text NOT NULL UNIQUE,
      name text NOT NULL,
      area text NOT NULL,
      city text NOT NULL,
      state text NOT NULL,
      pincode text NOT NULL,
      phone text NOT NULL DEFAULT '',
      hours text NOT NULL DEFAULT '8:00 AM – 10:00 PM',
      is_active boolean NOT NULL DEFAULT true,
      offers_lab_collection boolean NOT NULL DEFAULT true,
      latitude numeric(9,6),
      longitude numeric(9,6),
      maps_url text NOT NULL DEFAULT '',
      bank_account_name text NOT NULL DEFAULT '',
      bank_account_number text NOT NULL DEFAULT '',
      bank_ifsc text NOT NULL DEFAULT '',
      bank_name text NOT NULL DEFAULT '',
      sort integer NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.payment_method (
      id bigserial PRIMARY KEY,
      code text NOT NULL UNIQUE,
      name text NOT NULL,
      blurb text NOT NULL DEFAULT '',
      is_live boolean NOT NULL DEFAULT false,
      sort integer NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.product_category (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      slug text NOT NULL UNIQUE,
      title text NOT NULL,
      tab_label text NOT NULL,
      icon_name text,
      image text,
      banner_image text,
      panel_tint text,
      offer text NOT NULL DEFAULT '',
      sort integer NOT NULL DEFAULT 0,
      is_active boolean NOT NULL DEFAULT true,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.product_subcategory (
      id bigserial PRIMARY KEY,
      category_id bigint NOT NULL REFERENCES app.product_category(id) ON DELETE CASCADE,
      label text NOT NULL,
      icon_name text,
      image text,
      offer text NOT NULL DEFAULT '',
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.product (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      code text UNIQUE,
      name text NOT NULL,
      pack text NOT NULL DEFAULT '',
      brand text,
      category_id bigint REFERENCES app.product_category(id) ON DELETE SET NULL,
      subcategory_id bigint REFERENCES app.product_subcategory(id) ON DELETE SET NULL,
      price numeric(12,2) NOT NULL DEFAULT 0,
      mrp numeric(12,2) NOT NULL DEFAULT 0,
      discount_label text,
      icon_name text,
      image text,
      is_prescription_only boolean NOT NULL DEFAULT false,
      status text NOT NULL DEFAULT 'ACTIVE',
      stock_quantity numeric(12,2) NOT NULL DEFAULT 0,
      is_popular boolean NOT NULL DEFAULT false,
      is_deal boolean NOT NULL DEFAULT false,
      is_offer_of_day boolean NOT NULL DEFAULT false,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.product_detail (
      product_id bigint PRIMARY KEY REFERENCES app.product(id) ON DELETE CASCADE,
      form text,
      manufacturer text,
      description text NOT NULL DEFAULT '',
      ingredients text NOT NULL DEFAULT '',
      storage text NOT NULL DEFAULT '',
      highlights text[] NOT NULL DEFAULT '{}',
      benefits text[] NOT NULL DEFAULT '{}',
      directions text[] NOT NULL DEFAULT '{}',
      safety text[] NOT NULL DEFAULT '{}',
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.product_faq (
      id bigserial PRIMARY KEY,
      product_id bigint NOT NULL REFERENCES app.product(id) ON DELETE CASCADE,
      question text NOT NULL,
      answer text NOT NULL,
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.home_banner (
      id bigserial PRIMARY KEY,
      title text,
      subtitle text,
      image text,
      cta text,
      target text,
      is_active boolean NOT NULL DEFAULT true,
      sort integer NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.customer_review_video (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      name text NOT NULL,
      subtitle text NOT NULL DEFAULT '',
      video_url text NOT NULL,
      thumbnail text,
      is_active boolean NOT NULL DEFAULT true,
      sort integer NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.promo (
      id bigserial PRIMARY KEY,
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
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.cart (
      id bigserial PRIMARY KEY,
      member_id bigint NOT NULL UNIQUE REFERENCES app.users(id) ON DELETE CASCADE,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.cart_line (
      id bigserial PRIMARY KEY,
      cart_id bigint NOT NULL REFERENCES app.cart(id) ON DELETE CASCADE,
      product_id bigint REFERENCES app.product(id) ON DELETE SET NULL,
      name text NOT NULL,
      pack text NOT NULL DEFAULT '',
      price numeric(12,2) NOT NULL DEFAULT 0,
      mrp numeric(12,2) NOT NULL DEFAULT 0,
      image text,
      qty integer NOT NULL DEFAULT 1,
      source app.cart_line_source NOT NULL DEFAULT 'SHOP',
      prescription_id bigint,
      added_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app."order" (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      member_id bigint NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
      code text NOT NULL UNIQUE,
      kind app.order_kind NOT NULL DEFAULT 'STANDARD',
      status app.order_status NOT NULL DEFAULT 'PROCESSING',
      item_count integer NOT NULL DEFAULT 0,
      mrp_total numeric(12,2) NOT NULL DEFAULT 0,
      paid_total numeric(12,2) NOT NULL DEFAULT 0,
      delivery_fee numeric(12,2) NOT NULL DEFAULT 0,
      delivery_address_id bigint,
      store_id bigint,
      payment_method_id bigint,
      billed_wallet_card_id bigint,
      reference text,
      fulfillment_type app.fulfillment_type NOT NULL DEFAULT 'HOME_DELIVERY',
      payment_status app.order_payment_status NOT NULL DEFAULT 'PENDING',
      delivery_boy_id bigint,
      paid_at timestamptz,
      store_contacted_at timestamptz,
      placed_on date NOT NULL DEFAULT current_date,
      placed_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.order_line (
      id bigserial PRIMARY KEY,
      order_id bigint NOT NULL REFERENCES app."order"(id) ON DELETE CASCADE,
      product_id bigint REFERENCES app.product(id) ON DELETE SET NULL,
      name text NOT NULL,
      pack text NOT NULL DEFAULT '',
      unit_price numeric(12,2) NOT NULL DEFAULT 0,
      mrp numeric(12,2) NOT NULL DEFAULT 0,
      qty integer NOT NULL DEFAULT 1,
      -- migration 0044: counter-only, never returned to the member; a plain
      -- text column here stands in for the app.order_line_status enum.
      stock_status text NOT NULL DEFAULT 'AVAILABLE'
    );

    CREATE TABLE app.order_track_step (
      id bigserial PRIMARY KEY,
      order_id bigint NOT NULL REFERENCES app."order"(id) ON DELETE CASCADE,
      sort integer NOT NULL DEFAULT 0,
      title text NOT NULL,
      detail text,
      state app.track_state NOT NULL DEFAULT 'UPCOMING',
      occurred_at timestamptz
    );

    CREATE TABLE app.bill (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      order_id bigint NOT NULL UNIQUE REFERENCES app."order"(id) ON DELETE CASCADE,
      image text NOT NULL,
      amount numeric(12,2) NOT NULL DEFAULT 0,
      status app.order_payment_status NOT NULL DEFAULT 'PENDING',
      paid_at timestamptz,
      sent_at timestamptz NOT NULL DEFAULT now(),
      wallet_collected numeric(12,2) NOT NULL DEFAULT 0,
      cash_collected numeric(12,2) NOT NULL DEFAULT 0,
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.bill_line (
      id bigserial PRIMARY KEY,
      bill_id bigint NOT NULL REFERENCES app.bill(id) ON DELETE CASCADE,
      name text NOT NULL,
      pack text NOT NULL DEFAULT '',
      unit_price numeric(12,2) NOT NULL DEFAULT 0,
      qty integer NOT NULL DEFAULT 1
    );

    CREATE TABLE app.order_receipt (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      order_id bigint NOT NULL REFERENCES app."order"(id) ON DELETE CASCADE,
      payer_name text,
      reference text,
      amount numeric(12,2),
      storage_path text,
      file_name text,
      mime_type text,
      uploaded_at timestamptz NOT NULL DEFAULT now(),
      verified_at timestamptz
    );

    CREATE TABLE app.prescription (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      member_id bigint NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
      patient_id bigint NOT NULL REFERENCES app.patient(id) ON DELETE RESTRICT,
      store_id bigint REFERENCES app.shield_store(id) ON DELETE SET NULL,
      code text NOT NULL UNIQUE,
      file_name text NOT NULL DEFAULT '',
      storage_path text,
      image text,
      image_rotation smallint NOT NULL DEFAULT 0,
      doctor text NOT NULL DEFAULT '',
      duration app.medicine_duration,
      custom_days integer,
      recurring_from date,
      recurring_until date,
      status app.prescription_status NOT NULL DEFAULT 'AWAITING_REVIEW',
      reviewed_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      deleted_at timestamptz
    );

    CREATE TABLE app.prescription_image (
      id bigserial PRIMARY KEY,
      prescription_id bigint NOT NULL REFERENCES app.prescription(id) ON DELETE CASCADE,
      sort integer NOT NULL DEFAULT 0,
      image text NOT NULL,
      image_rotation smallint NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.prescription_medicine (
      id bigserial PRIMARY KEY,
      prescription_id bigint NOT NULL REFERENCES app.prescription(id) ON DELETE CASCADE,
      sort integer NOT NULL DEFAULT 0,
      name text NOT NULL,
      pack text NOT NULL DEFAULT '',
      dose_morning integer NOT NULL DEFAULT 0,
      dose_afternoon integer NOT NULL DEFAULT 0,
      dose_night integer NOT NULL DEFAULT 0,
      total_units integer NOT NULL DEFAULT 0,
      route_time text NOT NULL DEFAULT '',
      product_id bigint REFERENCES app.product(id) ON DELETE SET NULL,
      status app.prescription_medicine_status NOT NULL DEFAULT 'AVAILABLE'
    );

    CREATE TABLE app.prescription_order (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      prescription_id bigint NOT NULL REFERENCES app.prescription(id) ON DELETE CASCADE,
      order_id bigint REFERENCES app."order"(id) ON DELETE SET NULL,
      store_id bigint REFERENCES app.shield_store(id) ON DELETE SET NULL,
      status text NOT NULL DEFAULT 'SUBMITTED',
      customer_notes text,
      submitted_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.approval (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      member_id bigint NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
      order_id bigint REFERENCES app."order"(id) ON DELETE SET NULL,
      prescription_id bigint REFERENCES app.prescription(id) ON DELETE SET NULL,
      code text NOT NULL UNIQUE,
      order_ref text,
      patient_name text,
      pharmacist_note text NOT NULL DEFAULT '',
      status app.approval_status NOT NULL DEFAULT 'PENDING',
      raised_on date NOT NULL DEFAULT current_date,
      responded_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.approval_item (
      id bigserial PRIMARY KEY,
      approval_id bigint NOT NULL REFERENCES app.approval(id) ON DELETE CASCADE,
      name text NOT NULL,
      pack text NOT NULL DEFAULT '',
      quantity integer NOT NULL DEFAULT 1,
      price numeric(12,2) NOT NULL DEFAULT 0,
      note text NOT NULL DEFAULT '',
      is_accepted boolean
    );

    CREATE TABLE app.membership_tier (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      kind app.privilege_card_kind NOT NULL UNIQUE,
      name text NOT NULL,
      bin text NOT NULL,
      blurb text NOT NULL DEFAULT '',
      bonus_rate numeric(4,3) NOT NULL DEFAULT 0.100,
      validity_months integer NOT NULL DEFAULT 12,
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.membership_tier_load (
      id bigserial PRIMARY KEY,
      tier_id bigint NOT NULL REFERENCES app.membership_tier(id) ON DELETE CASCADE,
      amount numeric(12,2) NOT NULL,
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.wallet (
      id bigserial PRIMARY KEY,
      member_id bigint NOT NULL UNIQUE REFERENCES app.users(id) ON DELETE CASCADE,
      balance numeric(12,2) NOT NULL DEFAULT 0,
      reward_points integer NOT NULL DEFAULT 0,
      redeemed_this_month numeric(12,2) NOT NULL DEFAULT 0,
      opened_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.wallet_card (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      wallet_id bigint NOT NULL REFERENCES app.wallet(id) ON DELETE CASCADE,
      tier_id bigint NOT NULL REFERENCES app.membership_tier(id) ON DELETE RESTRICT,
      amount numeric(12,2) NOT NULL,
      bonus numeric(12,2) NOT NULL,
      recharged_extra numeric(12,2) NOT NULL DEFAULT 0,
      card_number text,
      store_id bigint REFERENCES app.shield_store(id) ON DELETE SET NULL,
      status app.approval_status NOT NULL DEFAULT 'PENDING',
      submitted_at timestamptz NOT NULL DEFAULT now(),
      reviewed_at timestamptz,
      reviewer_note text NOT NULL DEFAULT '',
      receipt_reference text,
      receipt_file_name text,
      receipt_image text,
      issued_on date NOT NULL DEFAULT current_date,
      recharged_on date NOT NULL DEFAULT current_date,
      expires_on date NOT NULL,
      sold_by_agent_id bigint,
      verified_reference text,
      received_on date,
      receipt_verified boolean NOT NULL DEFAULT false,
      received_amount numeric(12,2),
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.wallet_entry (
      id bigserial PRIMARY KEY,
      wallet_id bigint NOT NULL REFERENCES app.wallet(id) ON DELETE CASCADE,
      kind app.wallet_entry_kind NOT NULL,
      label text NOT NULL,
      amount numeric(12,2) NOT NULL,
      occurred_on date NOT NULL DEFAULT current_date,
      wallet_card_id bigint REFERENCES app.wallet_card(id) ON DELETE SET NULL,
      order_id bigint REFERENCES app."order"(id) ON DELETE SET NULL,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.commission_reserve_entry (
      id bigserial PRIMARY KEY,
      wallet_card_id bigint NOT NULL REFERENCES app.wallet_card(id),
      amount numeric(12,2) NOT NULL,
      source text NOT NULL DEFAULT 'POOL_LEFTOVER',
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.reward_point_transaction (
      id bigserial PRIMARY KEY,
      member_id bigint NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
      points integer NOT NULL,
      reason app.reward_txn_reason NOT NULL,
      ref_type text,
      ref_id bigint,
      note text,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.referral (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      inviter_member_id bigint NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
      invitee_member_id bigint REFERENCES app.users(id) ON DELETE SET NULL,
      invitee_phone text,
      code_used text,
      status app.referral_status NOT NULL DEFAULT 'SHARED',
      plan_amount numeric(12,2),
      commission_amount numeric(12,2) NOT NULL DEFAULT 0,
      registered_at timestamptz,
      transacted_at timestamptz,
      plan_activated_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.referral_level (
      id bigserial PRIMARY KEY,
      level integer NOT NULL UNIQUE,
      name text NOT NULL,
      referrals_required integer NOT NULL,
      points integer NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now()
    );
    INSERT INTO app.referral_level (level, name, referrals_required, points) VALUES
      (1, 'Starter',   2,  100),
      (2, 'Riser',     5,  200),
      (3, 'Achiever', 10,  500),
      (4, 'Champion', 20, 1500),
      (5, 'Legend',   40, 3000);

    CREATE TABLE app.lab_category (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      name text NOT NULL,
      image text,
      sort integer NOT NULL DEFAULT 0,
      is_active boolean NOT NULL DEFAULT true
    );

    CREATE TABLE app.lab_package (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      slug text NOT NULL UNIQUE,
      name text NOT NULL,
      category_id bigint REFERENCES app.lab_category(id) ON DELETE SET NULL,
      source_test_id bigint UNIQUE,
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
      organs text[] NOT NULL DEFAULT '{}',
      about text NOT NULL DEFAULT '',
      is_active boolean NOT NULL DEFAULT true,
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.lab_profile (
      id bigserial PRIMARY KEY,
      lab_package_id bigint NOT NULL REFERENCES app.lab_package(id) ON DELETE CASCADE,
      emoji text NOT NULL DEFAULT '',
      name text NOT NULL,
      parameters integer NOT NULL DEFAULT 0,
      is_extra boolean NOT NULL DEFAULT false,
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.clinic (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      name text NOT NULL,
      type text,
      location text,
      phone text,
      description text NOT NULL DEFAULT '',
      is_verified boolean NOT NULL DEFAULT false,
      specialities text[] NOT NULL DEFAULT '{}',
      is_active boolean NOT NULL DEFAULT true,
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.clinic_doctor (
      id bigserial PRIMARY KEY,
      clinic_id bigint NOT NULL REFERENCES app.clinic(id) ON DELETE CASCADE,
      name text NOT NULL,
      speciality text,
      fee text,
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.dietitian (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      name text NOT NULL,
      qualification text,
      focus text[] NOT NULL DEFAULT '{}',
      experience_years integer NOT NULL DEFAULT 0,
      languages text[] NOT NULL DEFAULT '{}',
      fee numeric(12,2) NOT NULL DEFAULT 0,
      next_slot text,
      is_active boolean NOT NULL DEFAULT true,
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.lab_booking (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      member_id bigint NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
      lab_package_id bigint NOT NULL REFERENCES app.lab_package(id) ON DELETE RESTRICT,
      patients_count integer NOT NULL DEFAULT 1,
      unit_price numeric(12,2) NOT NULL DEFAULT 0,
      total_price numeric(12,2) NOT NULL DEFAULT 0,
      status app.lab_booking_status NOT NULL DEFAULT 'REQUESTED',
      scheduled_for timestamptz,
      address_id bigint REFERENCES app.member_address(id) ON DELETE SET NULL,
      store_id bigint REFERENCES app.shield_store(id) ON DELETE SET NULL,
      note text,
      report_uploaded_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.lab_booking_patient (
      id bigserial PRIMARY KEY,
      lab_booking_id bigint NOT NULL REFERENCES app.lab_booking(id) ON DELETE CASCADE,
      patient_id bigint REFERENCES app.patient(id) ON DELETE SET NULL,
      name text,
      age integer
    );

    CREATE TABLE app.lab_booking_report (
      id bigserial PRIMARY KEY,
      lab_booking_id bigint NOT NULL REFERENCES app.lab_booking(id) ON DELETE CASCADE,
      name text NOT NULL DEFAULT '',
      image text NOT NULL,
      sort integer NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.appointment (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      member_id bigint NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
      kind app.appointment_kind NOT NULL DEFAULT 'CLINIC',
      clinic_id bigint REFERENCES app.clinic(id) ON DELETE SET NULL,
      dietitian_id bigint REFERENCES app.dietitian(id) ON DELETE SET NULL,
      patient_id bigint REFERENCES app.patient(id) ON DELETE SET NULL,
      doctor_name text,
      fee numeric(12,2),
      status app.appointment_status NOT NULL DEFAULT 'REQUESTED',
      scheduled_for timestamptz,
      remarks text,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.agent (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      member_id bigint REFERENCES app.users(id) ON DELETE SET NULL,
      code text NOT NULL UNIQUE,
      name text NOT NULL,
      phone text NOT NULL,
      level app.agent_level NOT NULL,
      parent_id bigint REFERENCES app.agent(id) ON DELETE SET NULL,
      active boolean NOT NULL DEFAULT true,
      area text NOT NULL DEFAULT '',
      area_id uuid,
      first_name text NOT NULL DEFAULT '',
      middle_name text NOT NULL DEFAULT '',
      last_name text NOT NULL DEFAULT '',
      dob date,
      aadhaar text NOT NULL DEFAULT '',
      pan text NOT NULL DEFAULT '',
      address text NOT NULL DEFAULT '',
      pincode text NOT NULL DEFAULT '',
      place text NOT NULL DEFAULT '',
      account_number text NOT NULL DEFAULT '',
      photo_path text,
      approval_status app.agent_approval NOT NULL DEFAULT 'APPROVED',
      reviewed_at timestamptz,
      reviewer_note text NOT NULL DEFAULT '',
      earned numeric(12,2) NOT NULL DEFAULT 0,
      redeemed numeric(12,2) NOT NULL DEFAULT 0,
      personal_sales numeric(12,2) NOT NULL DEFAULT 0,
      moved_to_wallet numeric(12,2) NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.agent_request (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      parent_agent_id bigint REFERENCES app.agent(id) ON DELETE SET NULL,
      requested_level app.agent_level NOT NULL,
      requested_area text NOT NULL DEFAULT '',
      requested_area_id uuid,
      name text NOT NULL,
      phone text NOT NULL,
      first_name text NOT NULL DEFAULT '',
      middle_name text NOT NULL DEFAULT '',
      last_name text NOT NULL DEFAULT '',
      dob date,
      aadhaar text NOT NULL DEFAULT '',
      pan text NOT NULL DEFAULT '',
      address text NOT NULL DEFAULT '',
      pincode text NOT NULL DEFAULT '',
      place text NOT NULL DEFAULT '',
      account_number text NOT NULL DEFAULT '',
      photo_path text,
      status app.agent_approval NOT NULL DEFAULT 'PENDING',
      reviewer_note text NOT NULL DEFAULT '',
      reviewed_at timestamptz,
      agent_id bigint REFERENCES app.agent(id) ON DELETE SET NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.agent_customer (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      agent_id bigint NOT NULL REFERENCES app.agent(id) ON DELETE CASCADE,
      member_id bigint REFERENCES app.users(id) ON DELETE SET NULL,
      name text NOT NULL,
      phone text NOT NULL DEFAULT '',
      created_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE (agent_id, member_id)
    );

    CREATE TABLE app.agent_customer_plan (
      id bigserial PRIMARY KEY,
      agent_customer_id bigint NOT NULL REFERENCES app.agent_customer(id) ON DELETE CASCADE,
      tier_id bigint NOT NULL REFERENCES app.membership_tier(id) ON DELETE RESTRICT,
      amount numeric(12,2) NOT NULL,
      activated_on date NOT NULL,
      wallet_card_id bigint REFERENCES app.wallet_card(id) ON DELETE SET NULL
    );

    CREATE TABLE app.agent_withdrawal (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      agent_id bigint NOT NULL REFERENCES app.agent(id) ON DELETE CASCADE,
      amount numeric(12,2) NOT NULL,
      status app.withdrawal_status NOT NULL DEFAULT 'PENDING',
      requested_on date NOT NULL DEFAULT current_date,
      processed_on date,
      created_at timestamptz NOT NULL DEFAULT now(),
      approved_at timestamptz,
      approved_by text,
      verified_account text,
      verification_note text,
      payment_reference text,
      processed_by text
    );

    CREATE TYPE app.lsgd_type AS ENUM ('corporation','municipality','grama_panchayat');

    CREATE TABLE app.region (
      id uuid PRIMARY KEY,
      national_agent_id bigint REFERENCES app.agent(id) ON DELETE SET NULL,
      name text NOT NULL UNIQUE,
      code text NOT NULL DEFAULT '',
      sort integer NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.state (
      id uuid PRIMARY KEY,
      region_id uuid NOT NULL REFERENCES app.region(id) ON DELETE RESTRICT,
      name text NOT NULL,
      code text NOT NULL DEFAULT '',
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.district (
      id uuid PRIMARY KEY,
      state_id uuid NOT NULL REFERENCES app.state(id) ON DELETE RESTRICT,
      name text NOT NULL,
      code text NOT NULL DEFAULT '',
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.assembly (
      id uuid PRIMARY KEY,
      district_id uuid NOT NULL REFERENCES app.district(id) ON DELETE RESTRICT,
      name text NOT NULL,
      code text NOT NULL DEFAULT '',
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.lsgd (
      id uuid PRIMARY KEY,
      assembly_id uuid REFERENCES app.assembly(id) ON DELETE RESTRICT,
      type app.lsgd_type NOT NULL,
      name text NOT NULL,
      code text NOT NULL DEFAULT '',
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.ward (
      id uuid PRIMARY KEY,
      lsgd_id uuid NOT NULL REFERENCES app.lsgd(id) ON DELETE RESTRICT,
      ward_number integer NOT NULL,
      name text NOT NULL DEFAULT '',
      code text NOT NULL DEFAULT '',
      sort integer NOT NULL DEFAULT 0
    );

    CREATE TABLE app.investor (
      id bigserial PRIMARY KEY,
      uuid uuid NOT NULL DEFAULT gen_random_uuid(),
      member_id bigint REFERENCES app.users(id) ON DELETE SET NULL,
      code text NOT NULL UNIQUE,
      name text NOT NULL,
      phone text NOT NULL,
      invested_store_id bigint REFERENCES app.shield_store(id) ON DELETE SET NULL,
      total_units integer NOT NULL DEFAULT 0,
      unit_price numeric(12,2) NOT NULL DEFAULT 150000,
      invested_since date NOT NULL,
      roi_percent numeric(6,2) NOT NULL DEFAULT 0,
      plan_type app.investor_plan_type NOT NULL DEFAULT 'YEARLY',
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE app.investor_plan_change_request (
      id bigserial PRIMARY KEY,
      investor_id bigint NOT NULL REFERENCES app.investor(id) ON DELETE CASCADE,
      requested_plan_type app.investor_plan_type NOT NULL,
      status app.plan_change_status NOT NULL DEFAULT 'REQUESTED',
      note text,
      created_at timestamptz NOT NULL DEFAULT now(),
      resolved_at timestamptz
    );

    CREATE TABLE backend.auth_session (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      subject_type backend_subject_type NOT NULL,
      subject_id text NOT NULL,
      issued_at timestamptz NOT NULL DEFAULT now(),
      expires_at timestamptz NOT NULL,
      revoked_at timestamptz,
      user_agent text,
      ip text
    );

    CREATE TABLE backend.refresh_token (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      session_id uuid NOT NULL REFERENCES backend.auth_session(id) ON DELETE CASCADE,
      token_hash text NOT NULL,
      expires_at timestamptz NOT NULL,
      used_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE backend.idempotency_key (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      key text NOT NULL,
      session_id uuid NOT NULL REFERENCES backend.auth_session(id) ON DELETE CASCADE,
      endpoint text NOT NULL,
      response_snapshot jsonb,
      created_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE (key, endpoint)
    );
  `);

  const { Pool: MemPool } = mem.adapters.createPg();

  // Two gaps between drizzle-orm's node-postgres driver and pg-mem's mock
  // client, both test-only shims — production talks to real `pg` against
  // real Neon and never goes through this file:
  //  1. drizzle always attaches `types.getTypeParser` (a no-op passthrough
  //     that keeps timestamps as raw strings instead of `pg` auto-parsing
  //     them) — pg-mem's mock explicitly rejects that option, so it's
  //     stripped before the call reaches it.
  //  2. drizzle requests `rowMode: 'array'` for queries with field
  //     selections, so it can position-map raw rows itself — pg-mem
  //     doesn't support that mode either and always returns keyed row
  //     objects. `Object.values()` recovers the same column order (JS
  //     preserves insertion order for string keys, and pg-mem builds each
  //     row object in the query's column order), which is what
  //     drizzle's array-mode mapper expects.
  class CompatPool extends MemPool {
    async query(config: unknown, values?: unknown) {
      const isConfigObject = !!config && typeof config === 'object';
      const wantsArrayMode = isConfigObject && (config as Record<string, unknown>).rowMode === 'array';
      const cleaned = isConfigObject
        ? Object.fromEntries(Object.entries(config as Record<string, unknown>).filter(([k]) => k !== 'types' && k !== 'rowMode'))
        : config;

      const result = await super.query(cleaned as never, values as never);
      if (wantsArrayMode && result && Array.isArray((result as { rows: unknown[] }).rows)) {
        (result as { rows: unknown[] }).rows = (result as { rows: unknown[] }).rows.map((row) =>
          Array.isArray(row) ? row : Object.values(row as object),
        );
      }
      return result;
    }
  }

  const pool = new CompatPool() as unknown as PgPool;
  return drizzle(pool, { schema });
}

export type TestDb = ReturnType<typeof createTestDb>;
