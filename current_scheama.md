CREATE SCHEMA "public";
CREATE SCHEMA "app";
CREATE SCHEMA "auth";
CREATE SCHEMA "neon_auth";
CREATE SCHEMA "pgrst";
CREATE TYPE "app"."gender" AS ENUM('FEMALE', 'MALE', 'OTHER');
CREATE TYPE "app"."address_label" AS ENUM('HOME', 'WORK', 'OTHER');
CREATE TYPE "app"."patient_relation" AS ENUM('SELF', 'SPOUSE', 'CHILD', 'PARENT', 'OTHER');
CREATE TYPE "app"."cart_line_source" AS ENUM('SHOP', 'PRESCRIPTION');
CREATE TYPE "app"."order_kind" AS ENUM('STANDARD', 'PRESCRIPTION');
CREATE TYPE "app"."order_status" AS ENUM('PROCESSING', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED');
CREATE TYPE "app"."track_state" AS ENUM('DONE', 'CURRENT', 'UPCOMING');
CREATE TYPE "app"."medicine_duration" AS ENUM('ONE_WEEK', 'FIFTEEN_DAYS', 'ONE_MONTH', 'TWO_MONTHS', 'THREE_MONTHS');
CREATE TYPE "app"."prescription_status" AS ENUM('AWAITING_REVIEW', 'READ', 'IN_CART', 'ORDERED');
CREATE TYPE "app"."approval_status" AS ENUM('PENDING', 'APPROVED', 'PARTIALLY_APPROVED', 'REJECTED', 'CANCELLED');
CREATE TYPE "app"."privilege_card_kind" AS ENUM('SILVER', 'GOLD', 'PLATINUM');
CREATE TYPE "app"."wallet_entry_kind" AS ENUM('ACTIVATION', 'BONUS', 'TOPUP', 'SPEND', 'POINTS_REDEEMED', 'AGENT_EARNINGS');
CREATE TYPE "app"."reward_txn_reason" AS ENUM('REGISTRATION', 'REFERRAL_LEVEL', 'ORDER', 'REDEMPTION', 'ADJUSTMENT');
CREATE TYPE "app"."referral_status" AS ENUM('SHARED', 'REGISTERED', 'TRANSACTED', 'PLAN_ACTIVATED');
CREATE TYPE "app"."appointment_kind" AS ENUM('CLINIC', 'TELE', 'DENTAL', 'DIETITIAN');
CREATE TYPE "app"."appointment_status" AS ENUM('REQUESTED', 'CONFIRMED', 'COMPLETED', 'CANCELLED');
CREATE TYPE "app"."lab_booking_status" AS ENUM('REQUESTED', 'CONFIRMED', 'SAMPLE_COLLECTED', 'REPORT_READY', 'CANCELLED');
CREATE TYPE "app"."agent_level" AS ENUM('NATIONAL', 'REGION', 'STATE', 'DISTRICT', 'ASSEMBLY', 'LSGD', 'WARD');
CREATE TYPE "app"."agent_approval" AS ENUM('PENDING', 'APPROVED', 'REJECTED');
CREATE TYPE "app"."withdrawal_status" AS ENUM('PENDING', 'PAID', 'REJECTED');
CREATE TYPE "app"."investor_plan_type" AS ENUM('YEARLY', 'MONTHLY');
CREATE TYPE "app"."plan_change_status" AS ENUM('REQUESTED', 'APPROVED', 'REJECTED');
CREATE TYPE "app"."notification_status" AS ENUM('QUEUED', 'SENT', 'READ');
CREATE TYPE "app"."push_platform" AS ENUM('ANDROID', 'IOS', 'WEB');
CREATE TYPE "app"."admin_role" AS ENUM('SUPERADMIN', 'PHARMACY', 'LAB', 'APPOINTMENTS');
CREATE TABLE "_prisma_migrations" (
	"id" varchar(36) PRIMARY KEY,
	"checksum" varchar(64) NOT NULL,
	"finished_at" timestamp with time zone,
	"migration_name" varchar(255) NOT NULL,
	"logs" text,
	"rolled_back_at" timestamp with time zone,
	"started_at" timestamp with time zone DEFAULT now() NOT NULL,
	"applied_steps_count" integer DEFAULT 0 NOT NULL
);
CREATE TABLE "activity_events" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "activity_events_uuid_key" UNIQUE,
	"customer_id" bigint,
	"activity_type" varchar(80) NOT NULL,
	"related_entity_type" varchar(100),
	"related_entity_id" bigint,
	"business_id" bigint,
	"provider_id" bigint,
	"agent_user_id" bigint,
	"crm_user_id" bigint,
	"status" varchar(50) DEFAULT 'PENDING' NOT NULL,
	"description" text NOT NULL,
	"created_by" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "agent_branch_assignments" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"user_id" bigint NOT NULL,
	"business_id" bigint NOT NULL,
	"status" varchar(50) DEFAULT 'PENDING' NOT NULL,
	"is_primary" boolean DEFAULT false NOT NULL,
	"requested_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"approved_at" timestamp with time zone,
	"transferred_at" timestamp with time zone,
	"inactive_at" timestamp with time zone,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "agent_preferences" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"user_id" bigint NOT NULL,
	"theme_preference" varchar(50),
	"language_preference" varchar(20),
	"timezone" varchar(100),
	"availability" jsonb,
	"working_hours" jsonb,
	"working_area" jsonb,
	"emergency_contact" jsonb,
	"notification_preferences" jsonb,
	"dashboard_layout" jsonb,
	"profile_preferences" jsonb,
	"device_preferences" jsonb,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"deleted_at" timestamp with time zone
);
CREATE TABLE "appointments" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"customer_id" bigint,
	"provider_id" bigint,
	"appointment_type" varchar(50),
	"appointment_date" timestamp with time zone,
	"status" varchar(50),
	"remarks" text
);
CREATE TABLE "audit_logs" (
	"id" bigserial PRIMARY KEY,
	"user_id" bigint,
	"action" varchar(255),
	"entity_type" varchar(100),
	"entity_id" bigint,
	"old_data" jsonb,
	"new_data" jsonb,
	"ip_address" varchar(100),
	"device_info" text,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "auth_devices" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"owner_type" varchar(30) NOT NULL,
	"owner_id" varchar(50) NOT NULL,
	"customer_id" bigint,
	"user_id" bigint,
	"fingerprint_hash" varchar(128) NOT NULL,
	"device_id" varchar(120),
	"device_name" varchar(255),
	"platform" varchar(50),
	"browser" varchar(100),
	"os" varchar(100),
	"ip_address" varchar(100),
	"user_agent" text,
	"is_trusted" boolean DEFAULT false NOT NULL,
	"first_seen_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "auth_sessions" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"session_id" uuid NOT NULL,
	"subject_id" varchar(120) NOT NULL,
	"owner_type" varchar(30) NOT NULL,
	"owner_id" varchar(50) NOT NULL,
	"customer_id" bigint,
	"user_id" bigint,
	"auth_device_id" bigint,
	"principal_type" varchar(30) NOT NULL,
	"role_code" varchar(50),
	"user_type" varchar(30),
	"access_scope" varchar(30),
	"permissions" jsonb,
	"firebase_uid" varchar(128),
	"auth_provider" varchar(30),
	"email" varchar(255),
	"mobile" varchar(20),
	"branch_business_id" varchar(50),
	"login_method" varchar(50),
	"refresh_token_hash" varchar(128) NOT NULL,
	"refresh_token_expires_at" timestamp with time zone NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"ip_address" varchar(100),
	"user_agent" text,
	"revoked_at" timestamp with time zone,
	"revoked_reason" text,
	"is_current" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "benefit_ledger_transactions" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"wallet_id" bigint NOT NULL,
	"transaction_type" varchar(50) NOT NULL,
	"amount" numeric(15, 2) NOT NULL,
	"service_type" varchar(50),
	"reference_type" varchar(100),
	"reference_id" bigint,
	"remarks" text,
	"created_by" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"metadata" jsonb
);
CREATE TABLE "businesses" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"code" varchar(50) NOT NULL,
	"name" varchar(255) NOT NULL,
	"business_type" varchar(100),
	"status" varchar(50) DEFAULT 'ACTIVE',
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "card_requests" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "card_requests_uuid_key" UNIQUE,
	"customer_id" bigint NOT NULL,
	"membership_id" bigint,
	"business_id" bigint,
	"status" varchar(50) DEFAULT 'REQUESTED' NOT NULL,
	"requested_by" bigint,
	"reviewed_by" bigint,
	"requested_at" timestamp with time zone DEFAULT now() NOT NULL,
	"reviewed_at" timestamp with time zone,
	"remarks" text,
	"request_kind" varchar(50) DEFAULT 'PHYSICAL' NOT NULL,
	CONSTRAINT "chk_card_requests_kind" CHECK (((request_kind)::text = ANY ((ARRAY['DIGITAL'::character varying, 'PHYSICAL'::character varying])::text[])))
);
CREATE TABLE "cash_wallet_transactions" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"wallet_id" bigint NOT NULL,
	"transaction_type" varchar(50) NOT NULL,
	"amount" numeric(15, 2) NOT NULL,
	"reference_type" varchar(100),
	"reference_id" bigint,
	"remarks" text,
	"created_by" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"metadata" jsonb
);
CREATE TABLE "commercial_settings" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"code" varchar(100) NOT NULL,
	"value_type" varchar(30) NOT NULL,
	"value_text" text,
	"value_number" numeric(15, 2),
	"value_boolean" boolean,
	"status" varchar(50) DEFAULT 'ACTIVE' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "commission_allocations" (
	"id" bigserial PRIMARY KEY,
	"commission_event_id" bigint NOT NULL,
	"recipient_level" varchar(30) NOT NULL,
	"recipient_user_id" bigint,
	"percentage" numeric(5, 2) NOT NULL,
	"amount_paise" bigint NOT NULL,
	"status" varchar(50) DEFAULT 'PENDING' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "commission_allocations_amount_paise_check" CHECK ((amount_paise >= 0)),
	CONSTRAINT "commission_allocations_percentage_check" CHECK ((percentage >= (0)::numeric))
);
CREATE TABLE "commission_events" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "commission_events_uuid_key" UNIQUE,
	"customer_id" bigint,
	"source_type" varchar(80) NOT NULL,
	"originating_level" varchar(30) NOT NULL,
	"pool_paise" bigint NOT NULL,
	"status" varchar(50) DEFAULT 'PENDING' NOT NULL,
	"created_by" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "commission_events_pool_paise_check" CHECK ((pool_paise >= 0))
);
CREATE TABLE "complaint_lifecycle_events" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "complaint_lifecycle_events_uuid_key" UNIQUE,
	"complaint_id" bigint NOT NULL,
	"event_type" varchar(50) NOT NULL,
	"actor_user_id" bigint,
	"from_assignee_user_id" bigint,
	"to_assignee_user_id" bigint,
	"note" text,
	"customer_visible" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "complaints" (
	"id" bigserial PRIMARY KEY,
	"customer_id" bigint,
	"complaint_type" varchar(100),
	"description" text,
	"status" varchar(50),
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"assigned_to_user_id" bigint,
	"assigned_at" timestamp with time zone,
	"resolved_by_user_id" bigint,
	"resolved_at" timestamp with time zone,
	"resolution_note" text,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "consultations" (
	"id" bigserial PRIMARY KEY,
	"customer_id" bigint,
	"appointment_id" bigint,
	"doctor_name" varchar(255),
	"diagnosis" text,
	"notes" text
);
CREATE TABLE "credit_accounts" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"customer_id" bigint,
	"credit_limit" numeric(15, 2),
	"available_credit" numeric(15, 2),
	"outstanding_amount" numeric(15, 2),
	"status" varchar(50)
);
CREATE TABLE "credit_transactions" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"credit_account_id" bigint,
	"transaction_type" varchar(50),
	"amount" numeric(15, 2),
	"remarks" text,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "crm_activities" (
	"id" bigserial PRIMARY KEY,
	"customer_id" bigint,
	"activity_type" varchar(50),
	"notes" text,
	"created_by" bigint,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "crm_tasks" (
	"id" bigserial PRIMARY KEY,
	"customer_id" bigint,
	"assigned_to" bigint,
	"due_date" timestamp with time zone,
	"status" varchar(50),
	"notes" text
);
CREATE TABLE "customer_addresses" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "customer_addresses_uuid_key" UNIQUE,
	"customer_id" bigint NOT NULL,
	"label" varchar(50) DEFAULT 'HOME' NOT NULL,
	"address_line1" text NOT NULL,
	"address_line2" text,
	"city" varchar(100),
	"district" varchar(100),
	"state" varchar(100),
	"pincode" varchar(20),
	"is_default" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
CREATE TABLE "customer_contacts" (
	"id" bigserial PRIMARY KEY,
	"customer_id" bigint NOT NULL,
	"name" varchar(255),
	"relation" varchar(100),
	"mobile" varchar(20),
	"is_primary" boolean DEFAULT false,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"contact_type" varchar(30) DEFAULT 'ALTERNATIVE' NOT NULL,
	"deleted_at" timestamp with time zone
);
CREATE TABLE "customer_dependents" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "customer_dependents_uuid_key" UNIQUE,
	"customer_id" bigint NOT NULL,
	"first_name" varchar(255) NOT NULL,
	"last_name" varchar(255),
	"relation" varchar(100) NOT NULL,
	"dob" date,
	"gender" varchar(20),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
CREATE TABLE "customer_import_batches" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "customer_import_batches_uuid_key" UNIQUE,
	"business_id" bigint NOT NULL,
	"status" varchar(50) DEFAULT 'PENDING_APPROVAL' NOT NULL,
	"requested_by" bigint,
	"approved_by" bigint,
	"requested_at" timestamp with time zone DEFAULT now() NOT NULL,
	"approved_at" timestamp with time zone,
	"imported_at" timestamp with time zone,
	"source_file_name" varchar(255),
	"row_count" integer DEFAULT 0 NOT NULL,
	"notes" text
);
CREATE TABLE "customer_import_rows" (
	"id" bigserial PRIMARY KEY,
	"batch_id" bigint NOT NULL,
	"external_customer_id" varchar(100) NOT NULL,
	"mobile" varchar(20) NOT NULL,
	"full_name" varchar(255),
	"payload" jsonb DEFAULT '{}' NOT NULL,
	"matched_customer_id" bigint,
	"status" varchar(50) DEFAULT 'PENDING' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "customer_import_rows_batch_id_external_customer_id_key" UNIQUE("batch_id","external_customer_id")
);
CREATE TABLE "customer_preferences" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "customer_preferences_uuid_key" UNIQUE,
	"customer_id" bigint NOT NULL CONSTRAINT "customer_preferences_customer_id_key" UNIQUE,
	"notification_preferences" jsonb,
	"language" varchar(20),
	"theme" varchar(30),
	"preferred_provider_id" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "customer_status_history" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"customer_id" bigint NOT NULL,
	"old_status" varchar(50),
	"new_status" varchar(50),
	"changed_by" bigint,
	"remarks" text,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "customers" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"customer_code" varchar(50),
	"aadhaar_number" varchar(20),
	"first_name" varchar(255),
	"last_name" varchar(255),
	"dob" date,
	"gender" varchar(20),
	"mobile" varchar(20) NOT NULL,
	"email" varchar(255),
	"address_line1" text,
	"address_line2" text,
	"city" varchar(100),
	"district" varchar(100),
	"state" varchar(100),
	"pincode" varchar(20),
	"status" varchar(50),
	"created_by" bigint,
	"approved_by" bigint,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"deleted_at" timestamp with time zone,
	"blood_group" varchar(10),
	"agent_code" varchar(50) NOT NULL,
	"referral_code" varchar(50),
	"referred_by_id" bigint,
	"firebase_uid" varchar(128),
	"last_login_at" timestamp with time zone,
	"onboarding_source" varchar(50) DEFAULT 'NEW_REGISTRATION' NOT NULL
);
CREATE TABLE "dental_records" (
	"id" bigserial PRIMARY KEY,
	"customer_id" bigint,
	"appointment_id" bigint,
	"treatment_name" varchar(255),
	"notes" text
);
CREATE TABLE "departments" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"business_id" bigint NOT NULL,
	"code" varchar(50),
	"name" varchar(255),
	"status" varchar(50),
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "device_push_tokens" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "device_push_tokens_uuid_key" UNIQUE,
	"customer_id" bigint NOT NULL,
	"token" text NOT NULL CONSTRAINT "device_push_tokens_token_key" UNIQUE,
	"platform" varchar(30) NOT NULL,
	"device_label" varchar(120),
	"is_active" boolean DEFAULT true NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"auth_device_id" bigint
);
CREATE TABLE "document_classifications" (
	"id" bigserial PRIMARY KEY,
	"document_id" bigint,
	"classification" varchar(100),
	"confidence" numeric(5, 2)
);
CREATE TABLE "document_extractions" (
	"id" bigserial PRIMARY KEY,
	"document_id" bigint,
	"extracted_text" text,
	"confidence_score" numeric(5, 2),
	"extraction_status" varchar(50),
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "document_processing_logs" (
	"id" bigserial PRIMARY KEY,
	"document_id" bigint,
	"stage" varchar(100),
	"status" varchar(50),
	"remarks" text,
	"processed_at" timestamp with time zone
);
CREATE TABLE "documents" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"customer_id" bigint,
	"uploaded_by" bigint,
	"document_type" varchar(100),
	"file_name" varchar(255),
	"storage_path" text,
	"file_size" bigint,
	"mime_type" varchar(100),
	"status" varchar(50),
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "erp_existing_customers" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"mobile" varchar(20) NOT NULL,
	"full_name" varchar(255) NOT NULL,
	"branch_name" varchar(255),
	"business_id" bigint,
	"erp_customer_code" varchar(100),
	"source_provider" varchar(100),
	"status" varchar(50) DEFAULT 'UNCLAIMED' NOT NULL,
	"matched_customer_id" bigint,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "lab_reports" (
	"id" bigserial PRIMARY KEY,
	"customer_id" bigint,
	"appointment_id" bigint,
	"document_id" bigint,
	"report_date" date
);
CREATE TABLE "login_history" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"owner_type" varchar(30) NOT NULL,
	"owner_id" varchar(50) NOT NULL,
	"customer_id" bigint,
	"user_id" bigint,
	"auth_device_id" bigint,
	"session_id" uuid,
	"login_method" varchar(50),
	"status" varchar(30) NOT NULL,
	"reason" text,
	"ip_address" varchar(100),
	"user_agent" text,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "membership_applications" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "membership_applications_uuid_key" UNIQUE,
	"customer_id" bigint NOT NULL,
	"status" varchar(50) DEFAULT 'PENDING' NOT NULL,
	"reference" varchar(100) NOT NULL CONSTRAINT "membership_applications_reference_key" UNIQUE,
	"review_reason" text,
	"reviewed_by" bigint,
	"submitted_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"reviewed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "membership_subscriptions" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "membership_subscriptions_uuid_key" UNIQUE,
	"customer_id" bigint NOT NULL CONSTRAINT "membership_subscriptions_customer_id_key" UNIQUE,
	"membership_id" bigint,
	"plan_name" varchar(255) NOT NULL,
	"customer_contribution_paise" bigint DEFAULT 1000000 NOT NULL,
	"shield_benefit_paise" bigint DEFAULT 100000 NOT NULL,
	"total_entitlement_paise" bigint DEFAULT 1100000 NOT NULL,
	"status" varchar(50) DEFAULT 'DRAFT' NOT NULL,
	"starts_on" date,
	"ends_on" date,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "membership_subscriptions_check" CHECK ((total_entitlement_paise = (customer_contribution_paise + shield_benefit_paise))),
	CONSTRAINT "membership_subscriptions_customer_contribution_paise_check" CHECK ((customer_contribution_paise >= 0)),
	CONSTRAINT "membership_subscriptions_shield_benefit_paise_check" CHECK ((shield_benefit_paise >= 0))
);
CREATE TABLE "membership_types" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"code" varchar(50),
	"name" varchar(255),
	"joining_fee" numeric(12, 2),
	"discount_percentage" numeric(5, 2),
	"credit_eligible" boolean,
	"status" varchar(50)
);
CREATE TABLE "memberships" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"customer_id" bigint,
	"membership_type_id" bigint,
	"membership_number" varchar(100),
	"joining_fee" numeric(12, 2),
	"activation_date" date,
	"expiry_date" date,
	"status" varchar(50),
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "notifications" (
	"id" bigserial PRIMARY KEY,
	"customer_id" bigint,
	"title" varchar(255),
	"message" text,
	"channel" varchar(50),
	"status" varchar(50),
	"sent_at" timestamp with time zone
);
CREATE TABLE "order_chronic_refills" (
	"id" bigserial PRIMARY KEY,
	"purchase_id" bigint NOT NULL,
	"is_chronic" boolean DEFAULT true NOT NULL,
	"repeat_interval_days" integer DEFAULT 30 NOT NULL,
	"tagged_by" bigint,
	"tagged_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "order_customer_confirmations" (
	"id" bigserial PRIMARY KEY,
	"purchase_id" bigint NOT NULL,
	"confirmation_status" varchar(50) DEFAULT 'PENDING' NOT NULL,
	"reason" text,
	"requested_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"confirmed_at" timestamp with time zone,
	"purchase_item_id" bigint,
	"requested_by" bigint
);
CREATE TABLE "order_invoices" (
	"id" bigserial PRIMARY KEY,
	"purchase_id" bigint NOT NULL,
	"storage_key" varchar(500) NOT NULL,
	"file_name" varchar(255) DEFAULT 'Pharmacy_Invoice.pdf' NOT NULL,
	"uploaded_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"sent_at" timestamp with time zone,
	"mime_type" varchar(100) DEFAULT 'application/pdf' NOT NULL,
	"file_size" bigint,
	"uploaded_by" bigint
);
CREATE TABLE "order_pharmacist_notes" (
	"id" bigserial PRIMARY KEY,
	"purchase_id" bigint NOT NULL,
	"notes" text NOT NULL,
	"author_id" bigint,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"visibility" varchar(50) DEFAULT 'INTERNAL' NOT NULL
);
CREATE TABLE "permissions" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"code" varchar(100),
	"name" varchar(255),
	"description" text
);
CREATE TABLE "pharmacy_provider_settings" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"provider_id" bigint NOT NULL CONSTRAINT "pharmacy_provider_settings_provider_id_key" UNIQUE,
	"settings" jsonb DEFAULT '{}' NOT NULL,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "prescription_pharmacy_requests" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "prescription_pharmacy_requests_uuid_key" UNIQUE,
	"customer_id" bigint NOT NULL,
	"document_id" bigint NOT NULL,
	"provider_id" bigint NOT NULL,
	"status" varchar(50) DEFAULT 'SUBMITTED' NOT NULL,
	"customer_notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "prescriptions" (
	"id" bigserial PRIMARY KEY,
	"customer_id" bigint,
	"consultation_id" bigint,
	"document_id" bigint,
	"issue_date" date
);
CREATE TABLE "pricing_rule_audits" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"wallet_id" bigint,
	"customer_id" bigint,
	"service_type" varchar(50) NOT NULL,
	"original_amount" numeric(15, 2) NOT NULL,
	"benefit_applied" numeric(15, 2) DEFAULT '0' NOT NULL,
	"membership_discount_applied" numeric(15, 2) DEFAULT '0' NOT NULL,
	"reward_points_earned" numeric(15, 2) DEFAULT '0' NOT NULL,
	"reward_points_redeemed" numeric(15, 2) DEFAULT '0' NOT NULL,
	"reward_credit_applied" numeric(15, 2) DEFAULT '0' NOT NULL,
	"cash_wallet_deducted" numeric(15, 2) DEFAULT '0' NOT NULL,
	"final_payable_amount" numeric(15, 2) DEFAULT '0' NOT NULL,
	"matched_rule_code" varchar(100),
	"preloading_used" boolean DEFAULT false NOT NULL,
	"metadata" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "product_categories" (
	"id" bigserial PRIMARY KEY,
	"name" varchar(255)
);
CREATE TABLE "products" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"product_code" varchar(100),
	"product_name" varchar(255),
	"brand" varchar(255),
	"category_id" bigint,
	"unit" varchar(50),
	"mrp" numeric(15, 2),
	"selling_price" numeric(15, 2),
	"cost_price" numeric(15, 2),
	"margin_percentage" numeric(5, 2),
	"stock_quantity" numeric(12, 2) DEFAULT '0' NOT NULL,
	"is_demo_available" boolean DEFAULT false NOT NULL,
	"data_source" varchar(50) DEFAULT 'PRIMARY' NOT NULL,
	"status" varchar(50) DEFAULT 'ACTIVE' NOT NULL
);
CREATE TABLE "provider_profile_branch_assignments" (
	"provider_profile_id" bigint,
	"business_id" bigint,
	"is_primary" boolean DEFAULT false NOT NULL,
	"assigned_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	CONSTRAINT "provider_profile_branch_assignments_pkey" PRIMARY KEY("provider_profile_id","business_id")
);
CREATE TABLE "provider_profiles" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"user_id" bigint NOT NULL,
	"display_name" varchar(255),
	"contact_email" varchar(255),
	"contact_phone" varchar(20),
	"profile_photo_storage_path" text,
	"profile_photo_file_name" varchar(255),
	"signature_storage_path" text,
	"signature_file_name" varchar(255),
	"qualifications" text,
	"specialization" varchar(255),
	"registration_details" jsonb,
	"consultation_availability" jsonb,
	"working_hours" jsonb,
	"notification_preferences" jsonb,
	"print_preferences" jsonb,
	"theme_preference" varchar(50),
	"language_preference" varchar(20),
	"default_printer" varchar(255),
	"timezone" varchar(100),
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"deleted_at" timestamp with time zone
);
CREATE TABLE "purchase_item_fulfillments" (
	"id" bigserial PRIMARY KEY,
	"purchase_item_id" bigint NOT NULL,
	"approved_quantity" numeric(10, 2) DEFAULT '0.00' NOT NULL,
	"dispatched_quantity" numeric(10, 2) DEFAULT '0.00' NOT NULL,
	"remaining_quantity" numeric(10, 2) DEFAULT '0.00' NOT NULL,
	"stock_status" varchar(50) DEFAULT 'FULL_STOCK' NOT NULL,
	"decision_status" varchar(50) DEFAULT 'PENDING' NOT NULL,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"rejected_quantity" numeric(10, 2) DEFAULT '0.00' NOT NULL,
	"decision_reason" text,
	"decision_actor_id" bigint,
	"authoritative_price" numeric(12, 2)
);
CREATE TABLE "purchase_item_substitutions" (
	"id" bigserial PRIMARY KEY,
	"purchase_item_id" bigint NOT NULL,
	"substitute_product_id" bigint,
	"substitute_name" varchar(255) NOT NULL,
	"substitute_unit_price" numeric(12, 2) DEFAULT '0.00' NOT NULL,
	"decision_reason" text,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"substitute_quantity" numeric(10, 2) DEFAULT '1.00' NOT NULL,
	"proposed_by" bigint,
	"customer_confirmation_status" varchar(50) DEFAULT 'PENDING' NOT NULL
);
CREATE TABLE "purchase_items" (
	"id" bigserial PRIMARY KEY,
	"purchase_id" bigint,
	"product_id" bigint,
	"quantity" numeric(12, 2),
	"unit_price" numeric(15, 2),
	"total_price" numeric(15, 2),
	"item_type" varchar(50) DEFAULT 'MEDICINE',
	"item_name" varchar(255),
	"metadata" jsonb
);
CREATE TABLE "purchases" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"customer_id" bigint,
	"provider_id" bigint,
	"invoice_number" varchar(255),
	"total_amount" numeric(15, 2),
	"discount_amount" numeric(15, 2),
	"payable_amount" numeric(15, 2),
	"purchase_date" timestamp with time zone,
	"appointment_id" bigint,
	"purchase_kind" varchar(50) DEFAULT 'GENERAL',
	"payment_status" varchar(50) DEFAULT 'PENDING',
	"payment_summary" jsonb,
	"billing_snapshot" jsonb,
	"order_status" varchar(50) DEFAULT 'PLACED' NOT NULL,
	"order_status_updated_at" timestamp with time zone
);
CREATE TABLE "referral_reward_events" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "referral_reward_events_uuid_key" UNIQUE,
	"referrer_customer_id" bigint NOT NULL,
	"referred_customer_id" bigint NOT NULL CONSTRAINT "referral_reward_events_referred_customer_id_key" UNIQUE,
	"referral_code" varchar(50),
	"status" varchar(30) DEFAULT 'PENDING' NOT NULL,
	"reward_points" numeric(15, 2) DEFAULT '0' NOT NULL,
	"qualifying_reference_type" varchar(100),
	"qualifying_reference_id" bigint,
	"notes" text,
	"verified_at" timestamp with time zone,
	"qualified_at" timestamp with time zone,
	"rewarded_at" timestamp with time zone,
	"rejected_at" timestamp with time zone,
	"rejected_reason" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expired_at" timestamp with time zone
);
CREATE TABLE "reward_point_rules" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"action_code" varchar(100) NOT NULL,
	"display_name" varchar(255) NOT NULL,
	"points" numeric(12, 2) NOT NULL,
	"requires_approval" boolean DEFAULT false NOT NULL,
	"status" varchar(50) DEFAULT 'ACTIVE' NOT NULL,
	"metadata" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "reward_point_transactions" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"wallet_id" bigint NOT NULL,
	"transaction_type" varchar(50) NOT NULL,
	"action_code" varchar(100),
	"points" numeric(15, 2) NOT NULL,
	"reason" text,
	"reference_type" varchar(100),
	"reference_id" bigint,
	"status" varchar(30) DEFAULT 'APPROVED' NOT NULL,
	"created_by" bigint,
	"approved_by" bigint,
	"approved_at" timestamp with time zone,
	"expires_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"metadata" jsonb
);
CREATE TABLE "reward_redemption_rules" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "reward_redemption_rules_uuid_key" UNIQUE,
	"code" varchar(50) NOT NULL CONSTRAINT "reward_redemption_rules_code_key" UNIQUE,
	"points_required" numeric(12, 2) NOT NULL,
	"cash_credit_amount" numeric(12, 2) NOT NULL,
	"minimum_points" numeric(12, 2) DEFAULT '0' NOT NULL,
	"maximum_points_per_month" numeric(12, 2) DEFAULT '0' NOT NULL,
	"expiry_months" integer DEFAULT 24 NOT NULL,
	"credit_ledger_type" varchar(50) DEFAULT 'CASH' NOT NULL,
	"status" varchar(50) DEFAULT 'ACTIVE' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "role_permissions" (
	"role_id" bigint,
	"permission_id" bigint,
	CONSTRAINT "role_permissions_pkey" PRIMARY KEY("role_id","permission_id")
);
CREATE TABLE "roles" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"code" varchar(50),
	"name" varchar(255),
	"description" text,
	"user_type" varchar(30),
	"default_scope" varchar(30),
	"is_system_role" boolean DEFAULT false
);
CREATE TABLE "service_benefit_rules" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "service_benefit_rules_uuid_key" UNIQUE,
	"service_type" varchar(50) NOT NULL CONSTRAINT "service_benefit_rules_service_type_key" UNIQUE,
	"is_benefit_eligible" boolean DEFAULT false NOT NULL,
	"max_benefit_amount" numeric(12, 2) DEFAULT '0' NOT NULL,
	"qualifies_referral_reward" boolean DEFAULT true NOT NULL,
	"reward_points_on_service" numeric(12, 2) DEFAULT '0' NOT NULL,
	"status" varchar(50) DEFAULT 'ACTIVE' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"wallets_allowed" varchar(120) DEFAULT 'CASH',
	"allow_external_payment" boolean DEFAULT true NOT NULL
);
CREATE TABLE "service_provider_payment_methods" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL CONSTRAINT "service_provider_payment_methods_uuid_key" UNIQUE,
	"provider_id" bigint NOT NULL,
	"method_type" varchar(30) NOT NULL,
	"display_label" varchar(100),
	"account_holder_name" varchar(255),
	"bank_name" varchar(255),
	"account_number" varchar(50),
	"ifsc_code" varchar(20),
	"branch_name" varchar(255),
	"upi_id" varchar(120),
	"qr_storage_path" text,
	"qr_file_name" varchar(255),
	"qr_mime_type" varchar(50),
	"is_active" boolean DEFAULT true NOT NULL,
	"is_primary" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "chk_sp_payment_methods_primary_active" CHECK (((NOT is_primary) OR is_active)),
	CONSTRAINT "chk_sp_payment_methods_type" CHECK (((method_type)::text = ANY (ARRAY[('BANK_ACCOUNT'::character varying)::text, ('UPI'::character varying)::text])))
);
CREATE TABLE "service_providers" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"business_id" bigint,
	"provider_name" varchar(255),
	"provider_type" varchar(100),
	"status" varchar(50)
);
CREATE TABLE "shield_cards" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"customer_id" bigint,
	"card_number" varchar(100),
	"qr_code" text,
	"status" varchar(50),
	"issued_business_id" bigint,
	"issued_at" timestamp with time zone
);
CREATE TABLE "store_change_requests" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "store_change_requests_uuid_key" UNIQUE,
	"customer_id" bigint NOT NULL,
	"previous_provider_id" bigint,
	"requested_provider_id" bigint NOT NULL,
	"reason" text NOT NULL,
	"status" varchar(50) DEFAULT 'PENDING' NOT NULL,
	"review_reason" text,
	"reviewed_by" bigint,
	"submitted_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"reviewed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "subscription_monthly_allocations" (
	"id" bigserial PRIMARY KEY,
	"subscription_id" bigint NOT NULL,
	"month_start" date NOT NULL,
	"allocation_paise" bigint NOT NULL,
	"carry_forward_paise" bigint DEFAULT 0 NOT NULL,
	"used_paise" bigint DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "subscription_monthly_allocation_subscription_id_month_start_key" UNIQUE("subscription_id","month_start"),
	CONSTRAINT "subscription_monthly_allocations_allocation_paise_check" CHECK ((allocation_paise >= 0)),
	CONSTRAINT "subscription_monthly_allocations_carry_forward_paise_check" CHECK ((carry_forward_paise >= 0)),
	CONSTRAINT "subscription_monthly_allocations_used_paise_check" CHECK ((used_paise >= 0))
);
CREATE TABLE "users" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL,
	"employee_code" varchar(50),
	"first_name" varchar(255),
	"last_name" varchar(255),
	"mobile" varchar(20),
	"email" varchar(255),
	"password_hash" text,
	"role_id" bigint,
	"department_id" bigint,
	"status" varchar(50),
	"last_login_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"deleted_at" timestamp with time zone,
	"firebase_uid" varchar(128),
	"auth_provider" varchar(30),
	"user_type" varchar(30),
	"access_scope" varchar(30),
	"branch_business_id" bigint
);
CREATE TABLE "wallet_recharge_intents" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid NOT NULL CONSTRAINT "wallet_recharge_intents_uuid_key" UNIQUE,
	"customer_id" bigint NOT NULL,
	"wallet_id" bigint NOT NULL,
	"amount" numeric(15, 2) NOT NULL,
	"idempotency_key" varchar(120) NOT NULL CONSTRAINT "wallet_recharge_intents_idempotency_key_key" UNIQUE,
	"provider_code" varchar(80),
	"provider_reference" varchar(160) CONSTRAINT "wallet_recharge_intents_provider_reference_key" UNIQUE,
	"status" varchar(40) DEFAULT 'INITIATED' NOT NULL,
	"failure_code" varchar(100),
	"failure_reason" text,
	"credited_at" timestamp with time zone,
	"failed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"provider_id" bigint,
	"payment_method_id" bigint,
	"payment_channel" varchar(50) DEFAULT 'BANK_TRANSFER',
	"reference_number" varchar(120),
	"proof_storage_path" text,
	"reviewed_by" bigint,
	"reviewed_at" timestamp with time zone,
	"rejection_reason" text,
	"destination_snapshot" jsonb,
	CONSTRAINT "wallet_recharge_intents_amount_positive" CHECK ((amount > (0)::numeric))
);
CREATE TABLE "wallet_transactions" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"wallet_id" bigint,
	"transaction_type" varchar(50),
	"sub_ledger_type" varchar(50) DEFAULT 'CASH',
	"amount" numeric(15, 2),
	"reference_type" varchar(100),
	"reference_id" bigint,
	"remarks" text,
	"created_by" bigint,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"is_customer_visible" boolean DEFAULT true,
	"expires_at" timestamp with time zone,
	"metadata" jsonb
);
CREATE TABLE "wallets" (
	"id" bigserial PRIMARY KEY,
	"uuid" uuid,
	"customer_id" bigint,
	"status" varchar(50),
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE "app"."admin_user" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."admin_user_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"firebase_uid" text CONSTRAINT "admin_user_firebase_uid_key" UNIQUE,
	"email" text NOT NULL CONSTRAINT "admin_user_email_key" UNIQUE,
	"name" text NOT NULL,
	"role" "app"."admin_role" DEFAULT 'PHARMACY'::"app"."admin_role" NOT NULL,
	"store_id" bigint,
	"avatar_color" text DEFAULT '#2c57a6' NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"last_login_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."agent" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."agent_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"member_id" bigint,
	"code" text NOT NULL CONSTRAINT "agent_code_key" UNIQUE,
	"name" text NOT NULL,
	"phone" text NOT NULL,
	"level" "app"."agent_level" NOT NULL,
	"parent_id" bigint,
	"active" boolean DEFAULT true NOT NULL,
	"area" text DEFAULT '' NOT NULL,
	"first_name" text DEFAULT '' NOT NULL,
	"middle_name" text DEFAULT '' NOT NULL,
	"last_name" text DEFAULT '' NOT NULL,
	"dob" date,
	"aadhaar" text DEFAULT '' NOT NULL,
	"pan" text DEFAULT '' NOT NULL,
	"address" text DEFAULT '' NOT NULL,
	"pincode" text DEFAULT '' NOT NULL,
	"place" text DEFAULT '' NOT NULL,
	"account_number" text DEFAULT '' NOT NULL,
	"photo_path" text,
	"approval_status" "app"."agent_approval" DEFAULT 'APPROVED'::"app"."agent_approval" NOT NULL,
	"earned" numeric(12, 2) DEFAULT '0' NOT NULL,
	"redeemed" numeric(12, 2) DEFAULT '0' NOT NULL,
	"personal_sales" numeric(12, 2) DEFAULT '0' NOT NULL,
	"moved_to_wallet" numeric(12, 2) DEFAULT '0' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."agent_customer" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."agent_customer_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"agent_id" bigint NOT NULL,
	"member_id" bigint,
	"name" text NOT NULL,
	"phone" text DEFAULT '' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."agent_customer_plan" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."agent_customer_plan_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"agent_customer_id" bigint NOT NULL,
	"tier_id" bigint NOT NULL,
	"amount" numeric(12, 2) NOT NULL,
	"activated_on" date NOT NULL,
	"wallet_card_id" bigint
);
CREATE TABLE "app"."agent_geo_node" (
	"id" text PRIMARY KEY,
	"parent_id" text,
	"level" text NOT NULL,
	"name" text NOT NULL,
	"code" text DEFAULT '' NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "agent_geo_node_level_check" CHECK ((level = ANY (ARRAY['region'::text, 'state'::text, 'district'::text, 'assembly'::text, 'lsgd'::text, 'ward'::text])))
);
CREATE TABLE "app"."agent_wallet_transfer" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."agent_wallet_transfer_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"agent_id" bigint NOT NULL,
	"amount" numeric(12, 2) NOT NULL,
	"wallet_entry_id" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."agent_withdrawal" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."agent_withdrawal_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"agent_id" bigint NOT NULL,
	"amount" numeric(12, 2) NOT NULL,
	"status" "app"."withdrawal_status" DEFAULT 'PENDING'::"app"."withdrawal_status" NOT NULL,
	"requested_on" date DEFAULT CURRENT_DATE NOT NULL,
	"processed_on" date,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."appointment" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."appointment_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"member_id" bigint NOT NULL,
	"kind" "app"."appointment_kind" DEFAULT 'CLINIC'::"app"."appointment_kind" NOT NULL,
	"clinic_id" bigint,
	"dietitian_id" bigint,
	"patient_id" bigint,
	"doctor_name" text,
	"fee" numeric(12, 2),
	"status" "app"."appointment_status" DEFAULT 'REQUESTED'::"app"."appointment_status" NOT NULL,
	"scheduled_for" timestamp with time zone,
	"remarks" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."approval" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."approval_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"member_id" bigint NOT NULL,
	"order_id" bigint,
	"prescription_id" bigint,
	"code" text NOT NULL CONSTRAINT "approval_code_key" UNIQUE,
	"order_ref" text,
	"patient_name" text,
	"pharmacist_note" text DEFAULT '' NOT NULL,
	"status" "app"."approval_status" DEFAULT 'PENDING'::"app"."approval_status" NOT NULL,
	"raised_on" date DEFAULT CURRENT_DATE NOT NULL,
	"responded_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."approval_item" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."approval_item_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"approval_id" bigint NOT NULL,
	"name" text NOT NULL,
	"pack" text DEFAULT '' NOT NULL,
	"quantity" integer DEFAULT 1 NOT NULL,
	"price" numeric(12, 2) DEFAULT '0' NOT NULL,
	"note" text DEFAULT '' NOT NULL,
	"is_accepted" boolean
);
CREATE TABLE "app"."cart" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."cart_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"member_id" bigint NOT NULL CONSTRAINT "cart_member_id_key" UNIQUE,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."cart_line" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."cart_line_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"cart_id" bigint NOT NULL,
	"product_id" bigint,
	"name" text NOT NULL,
	"pack" text DEFAULT '' NOT NULL,
	"price" numeric(12, 2) DEFAULT '0' NOT NULL,
	"mrp" numeric(12, 2) DEFAULT '0' NOT NULL,
	"image" text,
	"qty" integer DEFAULT 1 NOT NULL,
	"source" "app"."cart_line_source" DEFAULT 'SHOP'::"app"."cart_line_source" NOT NULL,
	"prescription_id" bigint,
	"added_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "cart_line_qty_check" CHECK (((qty >= 1) AND (qty <= 999)))
);
CREATE TABLE "app"."clinic" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."clinic_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"type" text,
	"location" text,
	"phone" text,
	"description" text DEFAULT '' NOT NULL,
	"tint" text,
	"is_verified" boolean DEFAULT false NOT NULL,
	"specialities" text[] DEFAULT '{}' NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."clinic_doctor" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."clinic_doctor_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"clinic_id" bigint NOT NULL,
	"name" text NOT NULL,
	"speciality" text,
	"fee" text,
	"sort" integer DEFAULT 0 NOT NULL
);
CREATE TABLE "app"."customer_review" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."customer_review_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"subtitle" text,
	"video_url" text,
	"duration_seconds" integer,
	"is_active" boolean DEFAULT true NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."customer_review_video" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."customer_review_video_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"subtitle" text DEFAULT '' NOT NULL,
	"video_url" text NOT NULL,
	"thumbnail" text,
	"is_active" boolean DEFAULT true NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."device_push_token" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."device_push_token_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"member_id" bigint NOT NULL,
	"token" text NOT NULL CONSTRAINT "device_push_token_token_key" UNIQUE,
	"platform" "app"."push_platform" NOT NULL,
	"device_label" text,
	"is_active" boolean DEFAULT true NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."dietitian" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."dietitian_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"qualification" text,
	"focus" text[] DEFAULT '{}' NOT NULL,
	"experience_years" integer DEFAULT 0 NOT NULL,
	"languages" text[] DEFAULT '{}' NOT NULL,
	"fee" numeric(12, 2) DEFAULT '0' NOT NULL,
	"next_slot" text,
	"is_active" boolean DEFAULT true NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."health_article" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."health_article_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"slug" text NOT NULL CONSTRAINT "health_article_slug_key" UNIQUE,
	"title" text NOT NULL,
	"topics" text[] DEFAULT '{}' NOT NULL,
	"author" text,
	"published_on" date,
	"hero_kicker" text,
	"intro" text[] DEFAULT '{}' NOT NULL,
	"icon_name" text,
	"tint" text,
	"is_published" boolean DEFAULT true NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."health_article_section" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."health_article_section_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"article_id" bigint NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"heading" text NOT NULL,
	"paragraphs" text[] DEFAULT '{}' NOT NULL
);
CREATE TABLE "app"."home_banner" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."home_banner_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"title" text,
	"subtitle" text,
	"image" text,
	"cta" text,
	"target" text,
	"is_active" boolean DEFAULT true NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."investment_plan_point" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."investment_plan_point_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"kind" text DEFAULT 'PLAN' NOT NULL,
	"title" text NOT NULL,
	"body" text DEFAULT '' NOT NULL,
	"icon_name" text,
	"sort" integer DEFAULT 0 NOT NULL
);
CREATE TABLE "app"."investor" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."investor_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"member_id" bigint,
	"code" text NOT NULL CONSTRAINT "investor_code_key" UNIQUE,
	"name" text NOT NULL,
	"phone" text NOT NULL,
	"invested_store_id" bigint,
	"total_units" integer DEFAULT 0 NOT NULL,
	"unit_price" numeric(12, 2) DEFAULT '150000' NOT NULL,
	"invested_since" date NOT NULL,
	"roi_percent" numeric(6, 2) DEFAULT '0' NOT NULL,
	"plan_type" "app"."investor_plan_type" DEFAULT 'YEARLY'::"app"."investor_plan_type" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."investor_plan_change_request" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."investor_plan_change_request_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"investor_id" bigint NOT NULL,
	"requested_plan_type" "app"."investor_plan_type" NOT NULL,
	"status" "app"."plan_change_status" DEFAULT 'REQUESTED'::"app"."plan_change_status" NOT NULL,
	"note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"resolved_at" timestamp with time zone
);
CREATE TABLE "app"."lab_booking" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."lab_booking_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"member_id" bigint NOT NULL,
	"lab_package_id" bigint NOT NULL,
	"patients_count" integer DEFAULT 1 NOT NULL,
	"unit_price" numeric(12, 2) DEFAULT '0' NOT NULL,
	"total_price" numeric(12, 2) DEFAULT '0' NOT NULL,
	"status" "app"."lab_booking_status" DEFAULT 'REQUESTED'::"app"."lab_booking_status" NOT NULL,
	"scheduled_for" timestamp with time zone,
	"address_id" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."lab_booking_patient" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."lab_booking_patient_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"lab_booking_id" bigint NOT NULL,
	"patient_id" bigint,
	"name" text,
	"age" integer
);
CREATE TABLE "app"."lab_package" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."lab_package_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"slug" text NOT NULL CONSTRAINT "lab_package_slug_key" UNIQUE,
	"name" text NOT NULL,
	"test_count" integer DEFAULT 0 NOT NULL,
	"profile_count" integer DEFAULT 0 NOT NULL,
	"rating" text,
	"booked" text,
	"report_in" text,
	"price" numeric(12, 2) DEFAULT '0' NOT NULL,
	"mrp" numeric(12, 2) DEFAULT '0' NOT NULL,
	"saved" numeric(12, 2) DEFAULT '0' NOT NULL,
	"inherits_from" text,
	"inherits_summary" text,
	"extras_label" text,
	"for_whom" text,
	"age_range" text,
	"preparation" text,
	"sample" text,
	"organs" text[] DEFAULT '{}' NOT NULL,
	"about" text DEFAULT '' NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."lab_profile" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."lab_profile_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"lab_package_id" bigint NOT NULL,
	"emoji" text DEFAULT '' NOT NULL,
	"name" text NOT NULL,
	"parameters" integer DEFAULT 0 NOT NULL,
	"is_extra" boolean DEFAULT false NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL
);
CREATE TABLE "app"."member_address" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."member_address_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"member_id" bigint NOT NULL,
	"label" "app"."address_label" DEFAULT 'HOME'::"app"."address_label" NOT NULL,
	"house" text NOT NULL,
	"area" text NOT NULL,
	"landmark" text DEFAULT '' NOT NULL,
	"pincode" text NOT NULL,
	"city" text,
	"state" text,
	"first_name" text DEFAULT '' NOT NULL,
	"last_name" text DEFAULT '' NOT NULL,
	"phone" text DEFAULT '' NOT NULL,
	"patient_id" bigint,
	"is_default" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
CREATE TABLE "app"."membership_tier" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."membership_tier_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"kind" "app"."privilege_card_kind" NOT NULL CONSTRAINT "membership_tier_kind_key" UNIQUE,
	"name" text NOT NULL,
	"bin" text NOT NULL,
	"blurb" text DEFAULT '' NOT NULL,
	"bonus_rate" numeric(4, 3) DEFAULT '0.100' NOT NULL,
	"validity_months" integer DEFAULT 12 NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."membership_tier_load" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."membership_tier_load_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"tier_id" bigint NOT NULL,
	"amount" numeric(12, 2) NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	CONSTRAINT "membership_tier_load_tier_id_amount_key" UNIQUE("tier_id","amount")
);
CREATE TABLE "app"."notification" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."notification_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"member_id" bigint NOT NULL,
	"title" text NOT NULL,
	"body" text DEFAULT '' NOT NULL,
	"channel" text DEFAULT 'PUSH' NOT NULL,
	"status" "app"."notification_status" DEFAULT 'QUEUED'::"app"."notification_status" NOT NULL,
	"deep_link" text,
	"sent_at" timestamp with time zone,
	"read_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."order" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."order_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"member_id" bigint NOT NULL,
	"code" text NOT NULL CONSTRAINT "order_code_key" UNIQUE,
	"kind" "app"."order_kind" DEFAULT 'STANDARD'::"app"."order_kind" NOT NULL,
	"status" "app"."order_status" DEFAULT 'PROCESSING'::"app"."order_status" NOT NULL,
	"item_count" integer DEFAULT 0 NOT NULL,
	"mrp_total" numeric(12, 2) DEFAULT '0' NOT NULL,
	"paid_total" numeric(12, 2) DEFAULT '0' NOT NULL,
	"delivery_fee" numeric(12, 2) DEFAULT '0' NOT NULL,
	"delivery_address_id" bigint,
	"store_id" bigint,
	"payment_method_id" bigint,
	"billed_wallet_card_id" bigint,
	"reference" text,
	"placed_on" date DEFAULT CURRENT_DATE NOT NULL,
	"placed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."order_line" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."order_line_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"order_id" bigint NOT NULL,
	"product_id" bigint,
	"name" text NOT NULL,
	"pack" text DEFAULT '' NOT NULL,
	"unit_price" numeric(12, 2) DEFAULT '0' NOT NULL,
	"mrp" numeric(12, 2) DEFAULT '0' NOT NULL,
	"qty" integer DEFAULT 1 NOT NULL
);
CREATE TABLE "app"."order_receipt" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."order_receipt_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"order_id" bigint NOT NULL,
	"payer_name" text,
	"reference" text,
	"amount" numeric(12, 2),
	"storage_path" text,
	"file_name" text,
	"mime_type" text,
	"uploaded_at" timestamp with time zone DEFAULT now() NOT NULL,
	"verified_at" timestamp with time zone
);
CREATE TABLE "app"."order_track_step" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."order_track_step_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"order_id" bigint NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"title" text NOT NULL,
	"detail" text,
	"state" "app"."track_state" DEFAULT 'UPCOMING'::"app"."track_state" NOT NULL,
	"occurred_at" timestamp with time zone
);
CREATE TABLE "app"."patient" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."patient_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"member_id" bigint NOT NULL,
	"name" text NOT NULL,
	"phone" text DEFAULT '' NOT NULL,
	"address" text DEFAULT '' NOT NULL,
	"dob" date NOT NULL,
	"gender" "app"."gender" DEFAULT 'OTHER'::"app"."gender" NOT NULL,
	"abha_id" text DEFAULT '' NOT NULL,
	"relation" "app"."patient_relation" DEFAULT 'SELF'::"app"."patient_relation" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
CREATE TABLE "app"."payment_method" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."payment_method_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"code" text NOT NULL CONSTRAINT "payment_method_code_key" UNIQUE,
	"name" text NOT NULL,
	"blurb" text DEFAULT '' NOT NULL,
	"is_live" boolean DEFAULT false NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."prescription" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."prescription_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"member_id" bigint NOT NULL,
	"patient_id" bigint NOT NULL,
	"code" text NOT NULL CONSTRAINT "prescription_code_key" UNIQUE,
	"file_name" text DEFAULT '' NOT NULL,
	"storage_path" text,
	"doctor" text DEFAULT '' NOT NULL,
	"duration" "app"."medicine_duration",
	"custom_days" integer,
	"recurring_from" date,
	"recurring_until" date,
	"status" "app"."prescription_status" DEFAULT 'AWAITING_REVIEW'::"app"."prescription_status" NOT NULL,
	"reviewed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	"store_id" bigint,
	"image" text
);
CREATE TABLE "app"."prescription_medicine" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."prescription_medicine_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"prescription_id" bigint NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"name" text NOT NULL,
	"pack" text DEFAULT '' NOT NULL,
	"dose_morning" integer DEFAULT 0 NOT NULL,
	"dose_afternoon" integer DEFAULT 0 NOT NULL,
	"dose_night" integer DEFAULT 0 NOT NULL,
	"product_id" bigint,
	"total_units" integer DEFAULT 0 NOT NULL
);
CREATE TABLE "app"."prescription_order" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."prescription_order_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"prescription_id" bigint NOT NULL,
	"order_id" bigint,
	"store_id" bigint,
	"status" text DEFAULT 'SUBMITTED' NOT NULL,
	"customer_notes" text,
	"submitted_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."product" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."product_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"code" text CONSTRAINT "product_code_key" UNIQUE,
	"name" text NOT NULL,
	"pack" text DEFAULT '' NOT NULL,
	"brand" text,
	"category_id" bigint,
	"subcategory_id" bigint,
	"price" numeric(12, 2) DEFAULT '0' NOT NULL,
	"mrp" numeric(12, 2) DEFAULT '0' NOT NULL,
	"discount_label" text,
	"icon_name" text,
	"image" text,
	"is_prescription_only" boolean DEFAULT false NOT NULL,
	"status" text DEFAULT 'ACTIVE' NOT NULL,
	"stock_quantity" numeric(12, 2) DEFAULT '0' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"is_popular" boolean DEFAULT false NOT NULL,
	"is_deal" boolean DEFAULT false NOT NULL,
	"is_offer_of_day" boolean DEFAULT false NOT NULL
);
CREATE TABLE "app"."product_category" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."product_category_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"slug" text NOT NULL CONSTRAINT "product_category_slug_key" UNIQUE,
	"title" text NOT NULL,
	"tab_label" text NOT NULL,
	"icon_name" text,
	"image" text,
	"banner_image" text,
	"panel_tint" text,
	"offer" text DEFAULT '' NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."product_detail" (
	"product_id" bigint PRIMARY KEY,
	"form" text,
	"manufacturer" text,
	"description" text DEFAULT '' NOT NULL,
	"ingredients" text DEFAULT '' NOT NULL,
	"storage" text DEFAULT '' NOT NULL,
	"highlights" text[] DEFAULT '{}' NOT NULL,
	"benefits" text[] DEFAULT '{}' NOT NULL,
	"directions" text[] DEFAULT '{}' NOT NULL,
	"safety" text[] DEFAULT '{}' NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."product_faq" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."product_faq_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"product_id" bigint NOT NULL,
	"question" text NOT NULL,
	"answer" text NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL
);
CREATE TABLE "app"."product_subcategory" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."product_subcategory_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"category_id" bigint NOT NULL,
	"label" text NOT NULL,
	"icon_name" text,
	"image" text,
	"offer" text DEFAULT '' NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL
);
CREATE TABLE "app"."promo" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."promo_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"title_top" text,
	"title_middle" text,
	"title_accent" text,
	"title_tail" text,
	"cta" text,
	"code" text,
	"percent" text,
	"background" text,
	"starts_on" date,
	"ends_on" date,
	"is_active" boolean DEFAULT true NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."referral" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."referral_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"inviter_member_id" bigint NOT NULL,
	"invitee_member_id" bigint,
	"invitee_phone" text,
	"code_used" text,
	"status" "app"."referral_status" DEFAULT 'SHARED'::"app"."referral_status" NOT NULL,
	"plan_amount" numeric(12, 2),
	"commission_amount" numeric(12, 2) DEFAULT '0' NOT NULL,
	"registered_at" timestamp with time zone,
	"transacted_at" timestamp with time zone,
	"plan_activated_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."referral_level" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."referral_level_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"level" integer NOT NULL CONSTRAINT "referral_level_level_key" UNIQUE,
	"name" text NOT NULL,
	"referrals_required" integer NOT NULL,
	"points" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."reward_point_transaction" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."reward_point_transaction_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"member_id" bigint NOT NULL,
	"points" integer NOT NULL,
	"reason" "app"."reward_txn_reason" NOT NULL,
	"ref_type" text,
	"ref_id" bigint,
	"note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."shield_store" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."shield_store_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"code" text NOT NULL CONSTRAINT "shield_store_code_key" UNIQUE,
	"name" text NOT NULL,
	"area" text NOT NULL,
	"city" text NOT NULL,
	"state" text NOT NULL,
	"pincode" text NOT NULL,
	"phone" text DEFAULT '' NOT NULL,
	"hours" text DEFAULT '8:00 AM – 10:00 PM' NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"latitude" numeric(9, 6),
	"longitude" numeric(9, 6),
	"maps_url" text DEFAULT '' NOT NULL,
	"bank_account_name" text DEFAULT '' NOT NULL,
	"bank_account_number" text DEFAULT '' NOT NULL,
	"bank_ifsc" text DEFAULT '' NOT NULL,
	"bank_name" text DEFAULT '' NOT NULL
);
CREATE TABLE "app"."users" (
	"id" bigint GENERATED ALWAYS AS IDENTITY (sequence name "app"."member_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"phone" text NOT NULL CONSTRAINT "member_phone_key" UNIQUE,
	"name" text NOT NULL,
	"firebase_uid" text CONSTRAINT "member_firebase_uid_key" UNIQUE,
	"email" text,
	"gender" "app"."gender",
	"dob" date,
	"address" text,
	"place" text,
	"pincode" text,
	"state" text,
	"home_store_id" bigint,
	"reward_points" integer DEFAULT 0 NOT NULL,
	"referral_code" text CONSTRAINT "member_referral_code_key" UNIQUE,
	"referred_by_member_id" bigint,
	"registration_completed_at" timestamp with time zone,
	"registration_prompt_dismissed" boolean DEFAULT false NOT NULL,
	"last_login_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "member_pkey" PRIMARY KEY("id")
);
CREATE TABLE "app"."wallet" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."wallet_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"member_id" bigint NOT NULL CONSTRAINT "wallet_member_id_key" UNIQUE,
	"balance" numeric(12, 2) DEFAULT '0' NOT NULL,
	"reward_points" integer DEFAULT 0 NOT NULL,
	"redeemed_this_month" numeric(12, 2) DEFAULT '0' NOT NULL,
	"opened_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "app"."wallet_card" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."wallet_card_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"uuid" uuid DEFAULT gen_random_uuid() NOT NULL,
	"wallet_id" bigint NOT NULL,
	"tier_id" bigint NOT NULL,
	"amount" numeric(12, 2) NOT NULL,
	"bonus" numeric(12, 2) NOT NULL,
	"recharged_extra" numeric(12, 2) DEFAULT '0' NOT NULL,
	"card_number" text,
	"store_id" bigint,
	"issued_on" date DEFAULT CURRENT_DATE NOT NULL,
	"recharged_on" date DEFAULT CURRENT_DATE NOT NULL,
	"expires_on" date NOT NULL,
	"sold_by_agent_id" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"status" "app"."approval_status" DEFAULT 'PENDING'::"app"."approval_status" NOT NULL,
	"submitted_at" timestamp with time zone DEFAULT now() NOT NULL,
	"reviewed_at" timestamp with time zone,
	"reviewer_note" text DEFAULT '' NOT NULL,
	"receipt_reference" text,
	"receipt_file_name" text,
	"receipt_image" text
);
CREATE TABLE "app"."wallet_entry" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "app"."wallet_entry_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"wallet_id" bigint NOT NULL,
	"kind" "app"."wallet_entry_kind" NOT NULL,
	"label" text NOT NULL,
	"amount" numeric(12, 2) NOT NULL,
	"occurred_on" date DEFAULT CURRENT_DATE NOT NULL,
	"wallet_card_id" bigint,
	"order_id" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE "neon_auth"."account" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"accountId" text NOT NULL,
	"providerId" text NOT NULL,
	"userId" uuid NOT NULL,
	"accessToken" text,
	"refreshToken" text,
	"idToken" text,
	"accessTokenExpiresAt" timestamp with time zone,
	"refreshTokenExpiresAt" timestamp with time zone,
	"scope" text,
	"password" text,
	"createdAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updatedAt" timestamp with time zone NOT NULL
);
CREATE TABLE "neon_auth"."invitation" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"organizationId" uuid NOT NULL,
	"email" text NOT NULL,
	"role" text,
	"status" text NOT NULL,
	"expiresAt" timestamp with time zone NOT NULL,
	"createdAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"inviterId" uuid NOT NULL
);
CREATE TABLE "neon_auth"."jwks" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"publicKey" text NOT NULL,
	"privateKey" text NOT NULL,
	"createdAt" timestamp with time zone NOT NULL,
	"expiresAt" timestamp with time zone
);
CREATE TABLE "neon_auth"."member" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"organizationId" uuid NOT NULL,
	"userId" uuid NOT NULL,
	"role" text NOT NULL,
	"createdAt" timestamp with time zone NOT NULL
);
CREATE TABLE "neon_auth"."organization" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"name" text NOT NULL,
	"slug" text NOT NULL CONSTRAINT "organization_slug_key" UNIQUE,
	"logo" text,
	"createdAt" timestamp with time zone NOT NULL,
	"metadata" text
);
CREATE TABLE "neon_auth"."project_config" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"name" text NOT NULL,
	"endpoint_id" text NOT NULL CONSTRAINT "project_config_endpoint_id_key" UNIQUE,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"trusted_origins" jsonb NOT NULL,
	"social_providers" jsonb NOT NULL,
	"email_provider" jsonb,
	"email_and_password" jsonb,
	"allow_localhost" boolean NOT NULL,
	"plugin_configs" jsonb,
	"webhook_config" jsonb
);
CREATE TABLE "neon_auth"."session" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"expiresAt" timestamp with time zone NOT NULL,
	"token" text NOT NULL CONSTRAINT "session_token_key" UNIQUE,
	"createdAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updatedAt" timestamp with time zone NOT NULL,
	"ipAddress" text,
	"userAgent" text,
	"userId" uuid NOT NULL,
	"impersonatedBy" text,
	"activeOrganizationId" text
);
CREATE TABLE "neon_auth"."user" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"name" text NOT NULL,
	"email" text NOT NULL CONSTRAINT "user_email_key" UNIQUE,
	"emailVerified" boolean NOT NULL,
	"image" text,
	"createdAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updatedAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"role" text,
	"banned" boolean,
	"banReason" text,
	"banExpires" timestamp with time zone
);
CREATE TABLE "neon_auth"."verification" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	"identifier" text NOT NULL,
	"value" text NOT NULL,
	"expiresAt" timestamp with time zone NOT NULL,
	"createdAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updatedAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE UNIQUE INDEX "_prisma_migrations_pkey" ON "_prisma_migrations" ("id");
CREATE UNIQUE INDEX "activity_events_pkey" ON "activity_events" ("id");
CREATE UNIQUE INDEX "activity_events_uuid_key" ON "activity_events" ("uuid");
CREATE INDEX "idx_activity_events_customer" ON "activity_events" ("customer_id","created_at");
CREATE INDEX "idx_activity_events_type" ON "activity_events" ("activity_type","created_at");
CREATE UNIQUE INDEX "agent_branch_assignments_pkey" ON "agent_branch_assignments" ("id");
CREATE UNIQUE INDEX "agent_branch_assignments_user_business_key" ON "agent_branch_assignments" ("user_id","business_id");
CREATE UNIQUE INDEX "agent_branch_assignments_uuid_key" ON "agent_branch_assignments" ("uuid");
CREATE INDEX "idx_agent_branch_assignment_business" ON "agent_branch_assignments" ("business_id");
CREATE INDEX "idx_agent_branch_assignment_status" ON "agent_branch_assignments" ("status");
CREATE INDEX "idx_agent_branch_assignment_user" ON "agent_branch_assignments" ("user_id");
CREATE UNIQUE INDEX "agent_preferences_pkey" ON "agent_preferences" ("id");
CREATE UNIQUE INDEX "agent_preferences_user_id_key" ON "agent_preferences" ("user_id");
CREATE UNIQUE INDEX "agent_preferences_uuid_key" ON "agent_preferences" ("uuid");
CREATE UNIQUE INDEX "appointments_pkey" ON "appointments" ("id");
CREATE UNIQUE INDEX "appointments_uuid_key" ON "appointments" ("uuid");
CREATE INDEX "idx_appointment_customer" ON "appointments" ("customer_id");
CREATE INDEX "idx_appointment_date" ON "appointments" ("appointment_date");
CREATE INDEX "idx_appointment_provider" ON "appointments" ("provider_id");
CREATE INDEX "idx_appointment_status" ON "appointments" ("status");
CREATE INDEX "idx_appointments_customer_date" ON "appointments" ("customer_id","appointment_date");
CREATE INDEX "idx_appointments_customer_status" ON "appointments" ("customer_id","status");
CREATE UNIQUE INDEX "audit_logs_pkey" ON "audit_logs" ("id");
CREATE UNIQUE INDEX "auth_devices_pkey" ON "auth_devices" ("id");
CREATE UNIQUE INDEX "auth_devices_uuid_key" ON "auth_devices" ("uuid");
CREATE INDEX "idx_auth_devices_customer" ON "auth_devices" ("customer_id");
CREATE INDEX "idx_auth_devices_last_seen" ON "auth_devices" ("last_seen_at");
CREATE INDEX "idx_auth_devices_user" ON "auth_devices" ("user_id");
CREATE UNIQUE INDEX "uq_auth_devices_owner_fingerprint" ON "auth_devices" ("owner_type","owner_id","fingerprint_hash");
CREATE UNIQUE INDEX "auth_sessions_pkey" ON "auth_sessions" ("id");
CREATE UNIQUE INDEX "auth_sessions_refresh_token_hash_key" ON "auth_sessions" ("refresh_token_hash");
CREATE UNIQUE INDEX "auth_sessions_session_id_key" ON "auth_sessions" ("session_id");
CREATE UNIQUE INDEX "auth_sessions_uuid_key" ON "auth_sessions" ("uuid");
CREATE INDEX "idx_auth_sessions_auth_device" ON "auth_sessions" ("auth_device_id");
CREATE INDEX "idx_auth_sessions_current" ON "auth_sessions" ("is_current");
CREATE INDEX "idx_auth_sessions_customer" ON "auth_sessions" ("customer_id");
CREATE INDEX "idx_auth_sessions_owner" ON "auth_sessions" ("owner_type","owner_id");
CREATE INDEX "idx_auth_sessions_refresh_expiry" ON "auth_sessions" ("refresh_token_expires_at");
CREATE INDEX "idx_auth_sessions_user" ON "auth_sessions" ("user_id");
CREATE UNIQUE INDEX "benefit_ledger_transactions_pkey" ON "benefit_ledger_transactions" ("id");
CREATE UNIQUE INDEX "benefit_ledger_transactions_uuid_key" ON "benefit_ledger_transactions" ("uuid");
CREATE INDEX "idx_benefit_ledger_transactions_date" ON "benefit_ledger_transactions" ("created_at");
CREATE INDEX "idx_benefit_ledger_transactions_service" ON "benefit_ledger_transactions" ("service_type");
CREATE INDEX "idx_benefit_ledger_transactions_wallet" ON "benefit_ledger_transactions" ("wallet_id");
CREATE UNIQUE INDEX "businesses_code_key" ON "businesses" ("code");
CREATE UNIQUE INDEX "businesses_pkey" ON "businesses" ("id");
CREATE UNIQUE INDEX "businesses_uuid_key" ON "businesses" ("uuid");
CREATE UNIQUE INDEX "card_requests_pkey" ON "card_requests" ("id");
CREATE UNIQUE INDEX "card_requests_uuid_key" ON "card_requests" ("uuid");
CREATE INDEX "idx_card_requests_customer" ON "card_requests" ("customer_id","status");
CREATE INDEX "idx_card_requests_kind" ON "card_requests" ("customer_id","request_kind");
CREATE UNIQUE INDEX "cash_wallet_transactions_pkey" ON "cash_wallet_transactions" ("id");
CREATE UNIQUE INDEX "cash_wallet_transactions_uuid_key" ON "cash_wallet_transactions" ("uuid");
CREATE INDEX "idx_cash_wallet_transactions_date" ON "cash_wallet_transactions" ("created_at");
CREATE INDEX "idx_cash_wallet_transactions_type" ON "cash_wallet_transactions" ("transaction_type");
CREATE INDEX "idx_cash_wallet_transactions_wallet" ON "cash_wallet_transactions" ("wallet_id");
CREATE UNIQUE INDEX "commercial_settings_code_key" ON "commercial_settings" ("code");
CREATE UNIQUE INDEX "commercial_settings_pkey" ON "commercial_settings" ("id");
CREATE UNIQUE INDEX "commercial_settings_uuid_key" ON "commercial_settings" ("uuid");
CREATE UNIQUE INDEX "commission_allocations_pkey" ON "commission_allocations" ("id");
CREATE UNIQUE INDEX "commission_events_pkey" ON "commission_events" ("id");
CREATE UNIQUE INDEX "commission_events_uuid_key" ON "commission_events" ("uuid");
CREATE INDEX "idx_commission_events_status" ON "commission_events" ("status","created_at");
CREATE UNIQUE INDEX "complaint_lifecycle_events_pkey" ON "complaint_lifecycle_events" ("id");
CREATE UNIQUE INDEX "complaint_lifecycle_events_uuid_key" ON "complaint_lifecycle_events" ("uuid");
CREATE INDEX "idx_complaint_lifecycle_events_complaint_created" ON "complaint_lifecycle_events" ("complaint_id","created_at");
CREATE INDEX "idx_complaint_lifecycle_events_visible_created" ON "complaint_lifecycle_events" ("customer_visible","created_at");
CREATE UNIQUE INDEX "complaints_pkey" ON "complaints" ("id");
CREATE INDEX "idx_complaints_assignee_status" ON "complaints" ("assigned_to_user_id","status");
CREATE INDEX "idx_complaints_customer_status" ON "complaints" ("customer_id","status");
CREATE UNIQUE INDEX "consultations_pkey" ON "consultations" ("id");
CREATE UNIQUE INDEX "credit_accounts_customer_id_key" ON "credit_accounts" ("customer_id");
CREATE UNIQUE INDEX "credit_accounts_pkey" ON "credit_accounts" ("id");
CREATE UNIQUE INDEX "credit_accounts_uuid_key" ON "credit_accounts" ("uuid");
CREATE UNIQUE INDEX "credit_transactions_pkey" ON "credit_transactions" ("id");
CREATE UNIQUE INDEX "credit_transactions_uuid_key" ON "credit_transactions" ("uuid");
CREATE UNIQUE INDEX "crm_activities_pkey" ON "crm_activities" ("id");
CREATE UNIQUE INDEX "crm_tasks_pkey" ON "crm_tasks" ("id");
CREATE UNIQUE INDEX "customer_addresses_pkey" ON "customer_addresses" ("id");
CREATE UNIQUE INDEX "customer_addresses_uuid_key" ON "customer_addresses" ("uuid");
CREATE INDEX "idx_customer_addresses_customer" ON "customer_addresses" ("customer_id","deleted_at");
CREATE UNIQUE INDEX "customer_contacts_pkey" ON "customer_contacts" ("id");
CREATE UNIQUE INDEX "customer_dependents_pkey" ON "customer_dependents" ("id");
CREATE UNIQUE INDEX "customer_dependents_uuid_key" ON "customer_dependents" ("uuid");
CREATE INDEX "idx_customer_dependents_customer" ON "customer_dependents" ("customer_id","deleted_at");
CREATE UNIQUE INDEX "customer_import_batches_pkey" ON "customer_import_batches" ("id");
CREATE UNIQUE INDEX "customer_import_batches_uuid_key" ON "customer_import_batches" ("uuid");
CREATE INDEX "idx_customer_import_batches_business" ON "customer_import_batches" ("business_id","status");
CREATE UNIQUE INDEX "customer_import_rows_batch_id_external_customer_id_key" ON "customer_import_rows" ("batch_id","external_customer_id");
CREATE UNIQUE INDEX "customer_import_rows_pkey" ON "customer_import_rows" ("id");
CREATE INDEX "idx_customer_import_rows_mobile" ON "customer_import_rows" ("mobile");
CREATE UNIQUE INDEX "customer_preferences_customer_id_key" ON "customer_preferences" ("customer_id");
CREATE UNIQUE INDEX "customer_preferences_pkey" ON "customer_preferences" ("id");
CREATE UNIQUE INDEX "customer_preferences_uuid_key" ON "customer_preferences" ("uuid");
CREATE UNIQUE INDEX "customer_status_history_pkey" ON "customer_status_history" ("id");
CREATE UNIQUE INDEX "customer_status_history_uuid_key" ON "customer_status_history" ("uuid");
CREATE INDEX "idx_customer_status_history_customer" ON "customer_status_history" ("customer_id");
CREATE INDEX "idx_customer_status_history_date" ON "customer_status_history" ("created_at");
CREATE UNIQUE INDEX "customers_aadhaar_number_key" ON "customers" ("aadhaar_number");
CREATE UNIQUE INDEX "customers_customer_code_key" ON "customers" ("customer_code");
CREATE UNIQUE INDEX "customers_mobile_key" ON "customers" ("mobile");
CREATE UNIQUE INDEX "customers_pkey" ON "customers" ("id");
CREATE UNIQUE INDEX "customers_referral_code_key" ON "customers" ("referral_code");
CREATE UNIQUE INDEX "customers_uuid_key" ON "customers" ("uuid");
CREATE INDEX "idx_customer_aadhaar" ON "customers" ("aadhaar_number");
CREATE UNIQUE INDEX "idx_customer_firebase_uid" ON "customers" ("firebase_uid");
CREATE INDEX "idx_customer_mobile" ON "customers" ("mobile");
CREATE UNIQUE INDEX "dental_records_pkey" ON "dental_records" ("id");
CREATE UNIQUE INDEX "departments_pkey" ON "departments" ("id");
CREATE UNIQUE INDEX "departments_uuid_key" ON "departments" ("uuid");
CREATE UNIQUE INDEX "device_push_tokens_pkey" ON "device_push_tokens" ("id");
CREATE UNIQUE INDEX "device_push_tokens_token_key" ON "device_push_tokens" ("token");
CREATE UNIQUE INDEX "device_push_tokens_uuid_key" ON "device_push_tokens" ("uuid");
CREATE INDEX "idx_device_push_tokens_customer" ON "device_push_tokens" ("customer_id");
CREATE INDEX "idx_device_push_tokens_platform" ON "device_push_tokens" ("platform");
CREATE UNIQUE INDEX "document_classifications_pkey" ON "document_classifications" ("id");
CREATE UNIQUE INDEX "document_extractions_pkey" ON "document_extractions" ("id");
CREATE UNIQUE INDEX "document_processing_logs_pkey" ON "document_processing_logs" ("id");
CREATE UNIQUE INDEX "documents_pkey" ON "documents" ("id");
CREATE UNIQUE INDEX "documents_uuid_key" ON "documents" ("uuid");
CREATE INDEX "idx_documents_customer_created" ON "documents" ("customer_id","created_at");
CREATE UNIQUE INDEX "erp_existing_customers_pkey" ON "erp_existing_customers" ("id");
CREATE INDEX "idx_erp_existing_customers_mobile" ON "erp_existing_customers" ("mobile");
CREATE UNIQUE INDEX "lab_reports_pkey" ON "lab_reports" ("id");
CREATE INDEX "idx_login_history_auth_device" ON "login_history" ("auth_device_id");
CREATE INDEX "idx_login_history_created_at" ON "login_history" ("created_at");
CREATE INDEX "idx_login_history_customer" ON "login_history" ("customer_id");
CREATE INDEX "idx_login_history_owner" ON "login_history" ("owner_type","owner_id");
CREATE INDEX "idx_login_history_user" ON "login_history" ("user_id");
CREATE UNIQUE INDEX "login_history_pkey" ON "login_history" ("id");
CREATE UNIQUE INDEX "login_history_uuid_key" ON "login_history" ("uuid");
CREATE INDEX "idx_membership_applications_customer_status" ON "membership_applications" ("customer_id","status");
CREATE INDEX "idx_membership_applications_submitted_at" ON "membership_applications" ("submitted_at");
CREATE UNIQUE INDEX "membership_applications_pkey" ON "membership_applications" ("id");
CREATE UNIQUE INDEX "membership_applications_reference_key" ON "membership_applications" ("reference");
CREATE UNIQUE INDEX "membership_applications_uuid_key" ON "membership_applications" ("uuid");
CREATE UNIQUE INDEX "uq_membership_applications_one_open_per_customer" ON "membership_applications" ("customer_id");
CREATE UNIQUE INDEX "membership_subscriptions_customer_id_key" ON "membership_subscriptions" ("customer_id");
CREATE UNIQUE INDEX "membership_subscriptions_pkey" ON "membership_subscriptions" ("id");
CREATE UNIQUE INDEX "membership_subscriptions_uuid_key" ON "membership_subscriptions" ("uuid");
CREATE UNIQUE INDEX "membership_types_code_key" ON "membership_types" ("code");
CREATE UNIQUE INDEX "membership_types_pkey" ON "membership_types" ("id");
CREATE UNIQUE INDEX "membership_types_uuid_key" ON "membership_types" ("uuid");
CREATE UNIQUE INDEX "memberships_customer_id_key" ON "memberships" ("customer_id");
CREATE UNIQUE INDEX "memberships_membership_number_key" ON "memberships" ("membership_number");
CREATE UNIQUE INDEX "memberships_pkey" ON "memberships" ("id");
CREATE UNIQUE INDEX "memberships_uuid_key" ON "memberships" ("uuid");
CREATE INDEX "idx_notifications_customer_sent" ON "notifications" ("customer_id","sent_at");
CREATE INDEX "idx_notifications_customer_status" ON "notifications" ("customer_id","status");
CREATE UNIQUE INDEX "notifications_pkey" ON "notifications" ("id");
CREATE INDEX "idx_order_chronic_refills_purchase_id" ON "order_chronic_refills" ("purchase_id");
CREATE UNIQUE INDEX "order_chronic_refills_pkey" ON "order_chronic_refills" ("id");
CREATE INDEX "idx_order_customer_confirmations_purchase_id" ON "order_customer_confirmations" ("purchase_id");
CREATE UNIQUE INDEX "order_customer_confirmations_pkey" ON "order_customer_confirmations" ("id");
CREATE INDEX "idx_order_invoices_purchase_id" ON "order_invoices" ("purchase_id");
CREATE UNIQUE INDEX "order_invoices_pkey" ON "order_invoices" ("id");
CREATE INDEX "idx_order_pharmacist_notes_purchase_id" ON "order_pharmacist_notes" ("purchase_id");
CREATE UNIQUE INDEX "order_pharmacist_notes_pkey" ON "order_pharmacist_notes" ("id");
CREATE UNIQUE INDEX "permissions_code_key" ON "permissions" ("code");
CREATE UNIQUE INDEX "permissions_pkey" ON "permissions" ("id");
CREATE UNIQUE INDEX "permissions_uuid_key" ON "permissions" ("uuid");
CREATE UNIQUE INDEX "idx_pharmacy_provider_settings_provider_id" ON "pharmacy_provider_settings" ("provider_id");
CREATE UNIQUE INDEX "pharmacy_provider_settings_pkey" ON "pharmacy_provider_settings" ("id");
CREATE UNIQUE INDEX "pharmacy_provider_settings_provider_id_key" ON "pharmacy_provider_settings" ("provider_id");
CREATE INDEX "idx_prescription_pharmacy_requests_customer" ON "prescription_pharmacy_requests" ("customer_id","created_at");
CREATE INDEX "idx_prescription_pharmacy_requests_document" ON "prescription_pharmacy_requests" ("document_id");
CREATE INDEX "idx_prescription_pharmacy_requests_provider_status" ON "prescription_pharmacy_requests" ("provider_id","status");
CREATE UNIQUE INDEX "prescription_pharmacy_requests_pkey" ON "prescription_pharmacy_requests" ("id");
CREATE UNIQUE INDEX "prescription_pharmacy_requests_uuid_key" ON "prescription_pharmacy_requests" ("uuid");
CREATE UNIQUE INDEX "uq_prescription_pharmacy_requests_open" ON "prescription_pharmacy_requests" ("document_id","provider_id");
CREATE UNIQUE INDEX "prescriptions_pkey" ON "prescriptions" ("id");
CREATE INDEX "idx_pricing_rule_audits_customer" ON "pricing_rule_audits" ("customer_id");
CREATE INDEX "idx_pricing_rule_audits_date" ON "pricing_rule_audits" ("created_at");
CREATE INDEX "idx_pricing_rule_audits_service" ON "pricing_rule_audits" ("service_type");
CREATE INDEX "idx_pricing_rule_audits_wallet" ON "pricing_rule_audits" ("wallet_id");
CREATE UNIQUE INDEX "pricing_rule_audits_pkey" ON "pricing_rule_audits" ("id");
CREATE UNIQUE INDEX "pricing_rule_audits_uuid_key" ON "pricing_rule_audits" ("uuid");
CREATE UNIQUE INDEX "product_categories_pkey" ON "product_categories" ("id");
CREATE UNIQUE INDEX "products_pkey" ON "products" ("id");
CREATE UNIQUE INDEX "products_uuid_key" ON "products" ("uuid");
CREATE INDEX "idx_provider_profile_branch_business" ON "provider_profile_branch_assignments" ("business_id");
CREATE UNIQUE INDEX "provider_profile_branch_assignments_pkey" ON "provider_profile_branch_assignments" ("provider_profile_id","business_id");
CREATE UNIQUE INDEX "provider_profiles_pkey" ON "provider_profiles" ("id");
CREATE UNIQUE INDEX "provider_profiles_user_id_key" ON "provider_profiles" ("user_id");
CREATE UNIQUE INDEX "provider_profiles_uuid_key" ON "provider_profiles" ("uuid");
CREATE INDEX "idx_purchase_item_fulfillments_item_id" ON "purchase_item_fulfillments" ("purchase_item_id");
CREATE UNIQUE INDEX "purchase_item_fulfillments_pkey" ON "purchase_item_fulfillments" ("id");
CREATE INDEX "idx_purchase_item_substitutions_item_id" ON "purchase_item_substitutions" ("purchase_item_id");
CREATE UNIQUE INDEX "purchase_item_substitutions_pkey" ON "purchase_item_substitutions" ("id");
CREATE INDEX "idx_purchase_items_metadata_gin" ON "purchase_items" USING gin ("metadata");
CREATE UNIQUE INDEX "purchase_items_pkey" ON "purchase_items" ("id");
CREATE INDEX "idx_purchases_appointment" ON "purchases" ("appointment_id");
CREATE INDEX "idx_purchases_billing_snapshot_gin" ON "purchases" USING gin ("billing_snapshot");
CREATE INDEX "idx_purchases_chronic" ON "purchases" ("(billing_snapshot ->> 'isChronic'::text)");
CREATE INDEX "idx_purchases_kind" ON "purchases" ("purchase_kind");
CREATE INDEX "idx_purchases_payment_status" ON "purchases" ("payment_status");
CREATE UNIQUE INDEX "purchases_customer_invoice_key" ON "purchases" ("customer_id","invoice_number");
CREATE UNIQUE INDEX "purchases_pkey" ON "purchases" ("id");
CREATE UNIQUE INDEX "purchases_uuid_key" ON "purchases" ("uuid");
CREATE INDEX "idx_referral_reward_events_referrer" ON "referral_reward_events" ("referrer_customer_id");
CREATE INDEX "idx_referral_reward_events_status" ON "referral_reward_events" ("status");
CREATE UNIQUE INDEX "referral_reward_events_pkey" ON "referral_reward_events" ("id");
CREATE UNIQUE INDEX "referral_reward_events_referred_customer_id_key" ON "referral_reward_events" ("referred_customer_id");
CREATE UNIQUE INDEX "referral_reward_events_uuid_key" ON "referral_reward_events" ("uuid");
CREATE UNIQUE INDEX "reward_point_rules_action_code_key" ON "reward_point_rules" ("action_code");
CREATE UNIQUE INDEX "reward_point_rules_pkey" ON "reward_point_rules" ("id");
CREATE UNIQUE INDEX "reward_point_rules_uuid_key" ON "reward_point_rules" ("uuid");
CREATE INDEX "idx_reward_point_transactions_action" ON "reward_point_transactions" ("action_code");
CREATE INDEX "idx_reward_point_transactions_date" ON "reward_point_transactions" ("created_at");
CREATE INDEX "idx_reward_point_transactions_status" ON "reward_point_transactions" ("status");
CREATE INDEX "idx_reward_point_transactions_wallet" ON "reward_point_transactions" ("wallet_id");
CREATE UNIQUE INDEX "reward_point_transactions_pkey" ON "reward_point_transactions" ("id");
CREATE UNIQUE INDEX "reward_point_transactions_uuid_key" ON "reward_point_transactions" ("uuid");
CREATE UNIQUE INDEX "reward_redemption_rules_code_key" ON "reward_redemption_rules" ("code");
CREATE UNIQUE INDEX "reward_redemption_rules_pkey" ON "reward_redemption_rules" ("id");
CREATE UNIQUE INDEX "reward_redemption_rules_uuid_key" ON "reward_redemption_rules" ("uuid");
CREATE UNIQUE INDEX "role_permissions_pkey" ON "role_permissions" ("role_id","permission_id");
CREATE UNIQUE INDEX "roles_code_key" ON "roles" ("code");
CREATE UNIQUE INDEX "roles_pkey" ON "roles" ("id");
CREATE UNIQUE INDEX "roles_uuid_key" ON "roles" ("uuid");
CREATE UNIQUE INDEX "service_benefit_rules_pkey" ON "service_benefit_rules" ("id");
CREATE UNIQUE INDEX "service_benefit_rules_service_type_key" ON "service_benefit_rules" ("service_type");
CREATE UNIQUE INDEX "service_benefit_rules_uuid_key" ON "service_benefit_rules" ("uuid");
CREATE INDEX "idx_sp_payment_methods_provider_active" ON "service_provider_payment_methods" ("provider_id","is_active","deleted_at");
CREATE UNIQUE INDEX "service_provider_payment_methods_pkey" ON "service_provider_payment_methods" ("id");
CREATE UNIQUE INDEX "service_provider_payment_methods_uuid_key" ON "service_provider_payment_methods" ("uuid");
CREATE UNIQUE INDEX "uq_sp_payment_methods_primary_bank" ON "service_provider_payment_methods" ("provider_id","method_type");
CREATE UNIQUE INDEX "service_providers_pkey" ON "service_providers" ("id");
CREATE UNIQUE INDEX "service_providers_uuid_key" ON "service_providers" ("uuid");
CREATE UNIQUE INDEX "shield_cards_card_number_key" ON "shield_cards" ("card_number");
CREATE UNIQUE INDEX "shield_cards_customer_id_key" ON "shield_cards" ("customer_id");
CREATE UNIQUE INDEX "shield_cards_pkey" ON "shield_cards" ("id");
CREATE UNIQUE INDEX "shield_cards_uuid_key" ON "shield_cards" ("uuid");
CREATE INDEX "idx_store_change_requests_customer_status" ON "store_change_requests" ("customer_id","status");
CREATE INDEX "idx_store_change_requests_status_submitted" ON "store_change_requests" ("status","submitted_at");
CREATE UNIQUE INDEX "store_change_requests_pkey" ON "store_change_requests" ("id");
CREATE UNIQUE INDEX "store_change_requests_uuid_key" ON "store_change_requests" ("uuid");
CREATE UNIQUE INDEX "uq_store_change_requests_one_pending_per_customer" ON "store_change_requests" ("customer_id");
CREATE INDEX "idx_subscription_allocations_month" ON "subscription_monthly_allocations" ("month_start");
CREATE UNIQUE INDEX "subscription_monthly_allocation_subscription_id_month_start_key" ON "subscription_monthly_allocations" ("subscription_id","month_start");
CREATE UNIQUE INDEX "subscription_monthly_allocations_pkey" ON "subscription_monthly_allocations" ("id");
CREATE INDEX "idx_user_branch_business" ON "users" ("branch_business_id");
CREATE INDEX "idx_user_email" ON "users" ("email");
CREATE UNIQUE INDEX "idx_user_firebase_uid" ON "users" ("firebase_uid");
CREATE INDEX "idx_user_mobile" ON "users" ("mobile");
CREATE INDEX "idx_user_role" ON "users" ("role_id");
CREATE UNIQUE INDEX "users_email_key" ON "users" ("email");
CREATE UNIQUE INDEX "users_mobile_key" ON "users" ("mobile");
CREATE UNIQUE INDEX "users_pkey" ON "users" ("id");
CREATE UNIQUE INDEX "users_uuid_key" ON "users" ("uuid");
CREATE INDEX "idx_wallet_recharge_intents_customer_status" ON "wallet_recharge_intents" ("customer_id","status","created_at");
CREATE INDEX "idx_wallet_recharge_intents_provider_status" ON "wallet_recharge_intents" ("provider_id","status","created_at");
CREATE INDEX "idx_wallet_recharge_intents_wallet_status" ON "wallet_recharge_intents" ("wallet_id","status");
CREATE UNIQUE INDEX "wallet_recharge_intents_idempotency_key_key" ON "wallet_recharge_intents" ("idempotency_key");
CREATE UNIQUE INDEX "wallet_recharge_intents_pkey" ON "wallet_recharge_intents" ("id");
CREATE UNIQUE INDEX "wallet_recharge_intents_provider_reference_key" ON "wallet_recharge_intents" ("provider_reference");
CREATE UNIQUE INDEX "wallet_recharge_intents_uuid_key" ON "wallet_recharge_intents" ("uuid");
CREATE INDEX "idx_wallet_transaction_date" ON "wallet_transactions" ("created_at");
CREATE INDEX "idx_wallet_transaction_type" ON "wallet_transactions" ("transaction_type");
CREATE INDEX "idx_wallet_transaction_wallet" ON "wallet_transactions" ("wallet_id");
CREATE UNIQUE INDEX "idx_wallet_transactions_manual_recharge_unique" ON "wallet_transactions" ("reference_type","reference_id");
CREATE UNIQUE INDEX "wallet_transactions_pkey" ON "wallet_transactions" ("id");
CREATE UNIQUE INDEX "wallet_transactions_uuid_key" ON "wallet_transactions" ("uuid");
CREATE UNIQUE INDEX "wallets_customer_id_key" ON "wallets" ("customer_id");
CREATE UNIQUE INDEX "wallets_pkey" ON "wallets" ("id");
CREATE UNIQUE INDEX "wallets_uuid_key" ON "wallets" ("uuid");
CREATE UNIQUE INDEX "admin_user_email_key" ON "app"."admin_user" ("email");
CREATE UNIQUE INDEX "admin_user_firebase_uid_key" ON "app"."admin_user" ("firebase_uid");
CREATE UNIQUE INDEX "admin_user_pkey" ON "app"."admin_user" ("id");
CREATE UNIQUE INDEX "agent_code_key" ON "app"."agent" ("code");
CREATE INDEX "agent_parent_idx" ON "app"."agent" ("parent_id");
CREATE INDEX "agent_phone_idx" ON "app"."agent" ("phone");
CREATE UNIQUE INDEX "agent_pkey" ON "app"."agent" ("id");
CREATE INDEX "agent_customer_agent_idx" ON "app"."agent_customer" ("agent_id");
CREATE UNIQUE INDEX "agent_customer_pkey" ON "app"."agent_customer" ("id");
CREATE UNIQUE INDEX "agent_customer_plan_pkey" ON "app"."agent_customer_plan" ("id");
CREATE INDEX "agent_geo_node_parent_idx" ON "app"."agent_geo_node" ("parent_id");
CREATE UNIQUE INDEX "agent_geo_node_parent_name_idx" ON "app"."agent_geo_node" ("COALESCE(parent_id, ''::text)","name");
CREATE UNIQUE INDEX "agent_geo_node_pkey" ON "app"."agent_geo_node" ("id");
CREATE UNIQUE INDEX "agent_wallet_transfer_pkey" ON "app"."agent_wallet_transfer" ("id");
CREATE INDEX "agent_withdrawal_agent_idx" ON "app"."agent_withdrawal" ("agent_id","created_at");
CREATE UNIQUE INDEX "agent_withdrawal_pkey" ON "app"."agent_withdrawal" ("id");
CREATE INDEX "appointment_member_idx" ON "app"."appointment" ("member_id","created_at");
CREATE UNIQUE INDEX "appointment_pkey" ON "app"."appointment" ("id");
CREATE UNIQUE INDEX "approval_code_key" ON "app"."approval" ("code");
CREATE INDEX "approval_member_idx" ON "app"."approval" ("member_id","created_at");
CREATE UNIQUE INDEX "approval_pkey" ON "app"."approval" ("id");
CREATE UNIQUE INDEX "approval_item_pkey" ON "app"."approval_item" ("id");
CREATE UNIQUE INDEX "cart_member_id_key" ON "app"."cart" ("member_id");
CREATE UNIQUE INDEX "cart_pkey" ON "app"."cart" ("id");
CREATE INDEX "cart_line_cart_idx" ON "app"."cart_line" ("cart_id");
CREATE UNIQUE INDEX "cart_line_pkey" ON "app"."cart_line" ("id");
CREATE UNIQUE INDEX "clinic_pkey" ON "app"."clinic" ("id");
CREATE UNIQUE INDEX "clinic_doctor_pkey" ON "app"."clinic_doctor" ("id");
CREATE UNIQUE INDEX "customer_review_pkey" ON "app"."customer_review" ("id");
CREATE UNIQUE INDEX "customer_review_video_pkey" ON "app"."customer_review_video" ("id");
CREATE INDEX "customer_review_video_sort_idx" ON "app"."customer_review_video" ("sort");
CREATE UNIQUE INDEX "device_push_token_pkey" ON "app"."device_push_token" ("id");
CREATE UNIQUE INDEX "device_push_token_token_key" ON "app"."device_push_token" ("token");
CREATE UNIQUE INDEX "dietitian_pkey" ON "app"."dietitian" ("id");
CREATE UNIQUE INDEX "health_article_pkey" ON "app"."health_article" ("id");
CREATE UNIQUE INDEX "health_article_slug_key" ON "app"."health_article" ("slug");
CREATE UNIQUE INDEX "health_article_section_pkey" ON "app"."health_article_section" ("id");
CREATE UNIQUE INDEX "home_banner_pkey" ON "app"."home_banner" ("id");
CREATE UNIQUE INDEX "investment_plan_point_pkey" ON "app"."investment_plan_point" ("id");
CREATE UNIQUE INDEX "investor_code_key" ON "app"."investor" ("code");
CREATE INDEX "investor_phone_idx" ON "app"."investor" ("phone");
CREATE UNIQUE INDEX "investor_pkey" ON "app"."investor" ("id");
CREATE UNIQUE INDEX "investor_plan_change_request_pkey" ON "app"."investor_plan_change_request" ("id");
CREATE INDEX "lab_booking_member_idx" ON "app"."lab_booking" ("member_id","created_at");
CREATE UNIQUE INDEX "lab_booking_pkey" ON "app"."lab_booking" ("id");
CREATE UNIQUE INDEX "lab_booking_patient_pkey" ON "app"."lab_booking_patient" ("id");
CREATE UNIQUE INDEX "lab_package_pkey" ON "app"."lab_package" ("id");
CREATE UNIQUE INDEX "lab_package_slug_key" ON "app"."lab_package" ("slug");
CREATE UNIQUE INDEX "lab_profile_pkey" ON "app"."lab_profile" ("id");
CREATE INDEX "member_address_member_idx" ON "app"."member_address" ("member_id");
CREATE UNIQUE INDEX "member_address_pkey" ON "app"."member_address" ("id");
CREATE UNIQUE INDEX "membership_tier_kind_key" ON "app"."membership_tier" ("kind");
CREATE UNIQUE INDEX "membership_tier_pkey" ON "app"."membership_tier" ("id");
CREATE UNIQUE INDEX "membership_tier_load_pkey" ON "app"."membership_tier_load" ("id");
CREATE UNIQUE INDEX "membership_tier_load_tier_id_amount_key" ON "app"."membership_tier_load" ("tier_id","amount");
CREATE INDEX "notification_member_idx" ON "app"."notification" ("member_id","created_at");
CREATE UNIQUE INDEX "notification_pkey" ON "app"."notification" ("id");
CREATE UNIQUE INDEX "order_code_key" ON "app"."order" ("code");
CREATE INDEX "order_member_idx" ON "app"."order" ("member_id","placed_at");
CREATE UNIQUE INDEX "order_pkey" ON "app"."order" ("id");
CREATE INDEX "order_line_order_idx" ON "app"."order_line" ("order_id");
CREATE UNIQUE INDEX "order_line_pkey" ON "app"."order_line" ("id");
CREATE UNIQUE INDEX "order_receipt_pkey" ON "app"."order_receipt" ("id");
CREATE UNIQUE INDEX "order_track_step_pkey" ON "app"."order_track_step" ("id");
CREATE INDEX "patient_member_idx" ON "app"."patient" ("member_id");
CREATE UNIQUE INDEX "patient_pkey" ON "app"."patient" ("id");
CREATE UNIQUE INDEX "payment_method_code_key" ON "app"."payment_method" ("code");
CREATE UNIQUE INDEX "payment_method_pkey" ON "app"."payment_method" ("id");
CREATE UNIQUE INDEX "prescription_code_key" ON "app"."prescription" ("code");
CREATE INDEX "prescription_member_idx" ON "app"."prescription" ("member_id");
CREATE UNIQUE INDEX "prescription_pkey" ON "app"."prescription" ("id");
CREATE INDEX "prescription_store_idx" ON "app"."prescription" ("store_id");
CREATE UNIQUE INDEX "prescription_medicine_pkey" ON "app"."prescription_medicine" ("id");
CREATE UNIQUE INDEX "prescription_order_pkey" ON "app"."prescription_order" ("id");
CREATE INDEX "product_category_idx" ON "app"."product" ("category_id");
CREATE UNIQUE INDEX "product_code_key" ON "app"."product" ("code");
CREATE INDEX "product_home_section_idx" ON "app"."product" ("is_popular","is_deal","is_offer_of_day");
CREATE INDEX "product_name_trgm" ON "app"."product" USING gin ("lower(name)");
CREATE UNIQUE INDEX "product_pkey" ON "app"."product" ("id");
CREATE UNIQUE INDEX "product_category_pkey" ON "app"."product_category" ("id");
CREATE UNIQUE INDEX "product_category_slug_key" ON "app"."product_category" ("slug");
CREATE UNIQUE INDEX "product_detail_pkey" ON "app"."product_detail" ("product_id");
CREATE UNIQUE INDEX "product_faq_pkey" ON "app"."product_faq" ("id");
CREATE UNIQUE INDEX "product_subcategory_cat_label_idx" ON "app"."product_subcategory" ("category_id","lower(label)");
CREATE UNIQUE INDEX "product_subcategory_pkey" ON "app"."product_subcategory" ("id");
CREATE UNIQUE INDEX "promo_pkey" ON "app"."promo" ("id");
CREATE INDEX "referral_inviter_idx" ON "app"."referral" ("inviter_member_id");
CREATE UNIQUE INDEX "referral_pkey" ON "app"."referral" ("id");
CREATE UNIQUE INDEX "referral_level_level_key" ON "app"."referral_level" ("level");
CREATE UNIQUE INDEX "referral_level_pkey" ON "app"."referral_level" ("id");
CREATE INDEX "reward_point_member_idx" ON "app"."reward_point_transaction" ("member_id","created_at");
CREATE UNIQUE INDEX "reward_point_transaction_pkey" ON "app"."reward_point_transaction" ("id");
CREATE UNIQUE INDEX "shield_store_code_key" ON "app"."shield_store" ("code");
CREATE UNIQUE INDEX "shield_store_pkey" ON "app"."shield_store" ("id");
CREATE UNIQUE INDEX "member_firebase_uid_key" ON "app"."users" ("firebase_uid");
CREATE UNIQUE INDEX "member_phone_key" ON "app"."users" ("phone");
CREATE UNIQUE INDEX "member_pkey" ON "app"."users" ("id");
CREATE UNIQUE INDEX "member_referral_code_key" ON "app"."users" ("referral_code");
CREATE UNIQUE INDEX "wallet_member_id_key" ON "app"."wallet" ("member_id");
CREATE UNIQUE INDEX "wallet_pkey" ON "app"."wallet" ("id");
CREATE UNIQUE INDEX "wallet_card_pkey" ON "app"."wallet_card" ("id");
CREATE INDEX "wallet_card_status_idx" ON "app"."wallet_card" ("status","submitted_at");
CREATE INDEX "wallet_card_wallet_idx" ON "app"."wallet_card" ("wallet_id");
CREATE UNIQUE INDEX "wallet_entry_pkey" ON "app"."wallet_entry" ("id");
CREATE INDEX "wallet_entry_wallet_idx" ON "app"."wallet_entry" ("wallet_id","created_at");
CREATE UNIQUE INDEX "account_pkey" ON "neon_auth"."account" ("id");
CREATE INDEX "account_userId_idx" ON "neon_auth"."account" ("userId");
CREATE INDEX "invitation_email_idx" ON "neon_auth"."invitation" ("email");
CREATE INDEX "invitation_organizationId_idx" ON "neon_auth"."invitation" ("organizationId");
CREATE UNIQUE INDEX "invitation_pkey" ON "neon_auth"."invitation" ("id");
CREATE UNIQUE INDEX "jwks_pkey" ON "neon_auth"."jwks" ("id");
CREATE INDEX "member_organizationId_idx" ON "neon_auth"."member" ("organizationId");
CREATE UNIQUE INDEX "member_pkey" ON "neon_auth"."member" ("id");
CREATE INDEX "member_userId_idx" ON "neon_auth"."member" ("userId");
CREATE UNIQUE INDEX "organization_pkey" ON "neon_auth"."organization" ("id");
CREATE UNIQUE INDEX "organization_slug_key" ON "neon_auth"."organization" ("slug");
CREATE UNIQUE INDEX "organization_slug_uidx" ON "neon_auth"."organization" ("slug");
CREATE UNIQUE INDEX "project_config_endpoint_id_key" ON "neon_auth"."project_config" ("endpoint_id");
CREATE UNIQUE INDEX "project_config_pkey" ON "neon_auth"."project_config" ("id");
CREATE UNIQUE INDEX "session_pkey" ON "neon_auth"."session" ("id");
CREATE UNIQUE INDEX "session_token_key" ON "neon_auth"."session" ("token");
CREATE INDEX "session_userId_idx" ON "neon_auth"."session" ("userId");
CREATE UNIQUE INDEX "user_email_key" ON "neon_auth"."user" ("email");
CREATE UNIQUE INDEX "user_pkey" ON "neon_auth"."user" ("id");
CREATE INDEX "verification_identifier_idx" ON "neon_auth"."verification" ("identifier");
CREATE UNIQUE INDEX "verification_pkey" ON "neon_auth"."verification" ("id");
ALTER TABLE "activity_events" ADD CONSTRAINT "activity_events_agent_user_id_fkey" FOREIGN KEY ("agent_user_id") REFERENCES "users"("id");
ALTER TABLE "activity_events" ADD CONSTRAINT "activity_events_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "businesses"("id");
ALTER TABLE "activity_events" ADD CONSTRAINT "activity_events_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id");
ALTER TABLE "activity_events" ADD CONSTRAINT "activity_events_crm_user_id_fkey" FOREIGN KEY ("crm_user_id") REFERENCES "users"("id");
ALTER TABLE "activity_events" ADD CONSTRAINT "activity_events_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id");
ALTER TABLE "activity_events" ADD CONSTRAINT "activity_events_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "service_providers"("id");
ALTER TABLE "agent_branch_assignments" ADD CONSTRAINT "agent_branch_assignments_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agent_branch_assignments" ADD CONSTRAINT "agent_branch_assignments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agent_preferences" ADD CONSTRAINT "agent_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "service_providers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "benefit_ledger_transactions" ADD CONSTRAINT "benefit_ledger_transactions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "benefit_ledger_transactions" ADD CONSTRAINT "benefit_ledger_transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "wallets"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "card_requests" ADD CONSTRAINT "card_requests_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "businesses"("id");
ALTER TABLE "card_requests" ADD CONSTRAINT "card_requests_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id");
ALTER TABLE "card_requests" ADD CONSTRAINT "card_requests_membership_id_fkey" FOREIGN KEY ("membership_id") REFERENCES "memberships"("id");
ALTER TABLE "card_requests" ADD CONSTRAINT "card_requests_requested_by_fkey" FOREIGN KEY ("requested_by") REFERENCES "users"("id");
ALTER TABLE "card_requests" ADD CONSTRAINT "card_requests_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "users"("id");
ALTER TABLE "cash_wallet_transactions" ADD CONSTRAINT "cash_wallet_transactions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "cash_wallet_transactions" ADD CONSTRAINT "cash_wallet_transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "wallets"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "commission_allocations" ADD CONSTRAINT "commission_allocations_commission_event_id_fkey" FOREIGN KEY ("commission_event_id") REFERENCES "commission_events"("id") ON DELETE CASCADE;
ALTER TABLE "commission_allocations" ADD CONSTRAINT "commission_allocations_recipient_user_id_fkey" FOREIGN KEY ("recipient_user_id") REFERENCES "users"("id");
ALTER TABLE "commission_events" ADD CONSTRAINT "commission_events_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id");
ALTER TABLE "commission_events" ADD CONSTRAINT "commission_events_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id");
ALTER TABLE "complaint_lifecycle_events" ADD CONSTRAINT "complaint_lifecycle_events_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE SET NULL;
ALTER TABLE "complaint_lifecycle_events" ADD CONSTRAINT "complaint_lifecycle_events_complaint_id_fkey" FOREIGN KEY ("complaint_id") REFERENCES "complaints"("id") ON DELETE CASCADE;
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_assigned_to_user_id_fkey" FOREIGN KEY ("assigned_to_user_id") REFERENCES "users"("id") ON DELETE SET NULL;
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_resolved_by_user_id_fkey" FOREIGN KEY ("resolved_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL;
ALTER TABLE "consultations" ADD CONSTRAINT "consultations_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "appointments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "consultations" ADD CONSTRAINT "consultations_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "credit_accounts" ADD CONSTRAINT "credit_accounts_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "credit_transactions" ADD CONSTRAINT "credit_transactions_credit_account_id_fkey" FOREIGN KEY ("credit_account_id") REFERENCES "credit_accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "crm_activities" ADD CONSTRAINT "crm_activities_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "crm_activities" ADD CONSTRAINT "crm_activities_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "crm_tasks" ADD CONSTRAINT "crm_tasks_assigned_to_fkey" FOREIGN KEY ("assigned_to") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "crm_tasks" ADD CONSTRAINT "crm_tasks_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "customer_addresses" ADD CONSTRAINT "customer_addresses_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE;
ALTER TABLE "customer_contacts" ADD CONSTRAINT "customer_contacts_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "customer_dependents" ADD CONSTRAINT "customer_dependents_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE;
ALTER TABLE "customer_import_batches" ADD CONSTRAINT "customer_import_batches_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "users"("id");
ALTER TABLE "customer_import_batches" ADD CONSTRAINT "customer_import_batches_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "businesses"("id");
ALTER TABLE "customer_import_batches" ADD CONSTRAINT "customer_import_batches_requested_by_fkey" FOREIGN KEY ("requested_by") REFERENCES "users"("id");
ALTER TABLE "customer_import_rows" ADD CONSTRAINT "customer_import_rows_batch_id_fkey" FOREIGN KEY ("batch_id") REFERENCES "customer_import_batches"("id") ON DELETE CASCADE;
ALTER TABLE "customer_import_rows" ADD CONSTRAINT "customer_import_rows_matched_customer_id_fkey" FOREIGN KEY ("matched_customer_id") REFERENCES "customers"("id");
ALTER TABLE "customer_preferences" ADD CONSTRAINT "customer_preferences_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE;
ALTER TABLE "customer_status_history" ADD CONSTRAINT "customer_status_history_changed_by_fkey" FOREIGN KEY ("changed_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "customer_status_history" ADD CONSTRAINT "customer_status_history_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "customers" ADD CONSTRAINT "customers_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "customers" ADD CONSTRAINT "customers_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "customers" ADD CONSTRAINT "customers_referred_by_id_fkey" FOREIGN KEY ("referred_by_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "dental_records" ADD CONSTRAINT "dental_records_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "appointments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "dental_records" ADD CONSTRAINT "dental_records_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "departments" ADD CONSTRAINT "departments_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "document_classifications" ADD CONSTRAINT "document_classifications_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "documents"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "document_extractions" ADD CONSTRAINT "document_extractions_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "documents"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "document_processing_logs" ADD CONSTRAINT "document_processing_logs_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "documents"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "documents" ADD CONSTRAINT "documents_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "documents" ADD CONSTRAINT "documents_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "erp_existing_customers" ADD CONSTRAINT "erp_existing_customers_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "businesses"("id");
ALTER TABLE "erp_existing_customers" ADD CONSTRAINT "erp_existing_customers_matched_customer_id_fkey" FOREIGN KEY ("matched_customer_id") REFERENCES "customers"("id");
ALTER TABLE "lab_reports" ADD CONSTRAINT "lab_reports_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "appointments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "lab_reports" ADD CONSTRAINT "lab_reports_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "lab_reports" ADD CONSTRAINT "lab_reports_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "documents"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "membership_applications" ADD CONSTRAINT "membership_applications_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE;
ALTER TABLE "membership_applications" ADD CONSTRAINT "membership_applications_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "users"("id") ON DELETE SET NULL;
ALTER TABLE "membership_subscriptions" ADD CONSTRAINT "membership_subscriptions_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id");
ALTER TABLE "membership_subscriptions" ADD CONSTRAINT "membership_subscriptions_membership_id_fkey" FOREIGN KEY ("membership_id") REFERENCES "memberships"("id");
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_membership_type_id_fkey" FOREIGN KEY ("membership_type_id") REFERENCES "membership_types"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "order_chronic_refills" ADD CONSTRAINT "fk_order_chronic_refills_purchase" FOREIGN KEY ("purchase_id") REFERENCES "purchases"("id") ON DELETE CASCADE;
ALTER TABLE "order_chronic_refills" ADD CONSTRAINT "order_chronic_refills_tagged_by_fkey" FOREIGN KEY ("tagged_by") REFERENCES "users"("id") ON DELETE SET NULL;
ALTER TABLE "order_customer_confirmations" ADD CONSTRAINT "fk_order_customer_confirmations_purchase" FOREIGN KEY ("purchase_id") REFERENCES "purchases"("id") ON DELETE CASCADE;
ALTER TABLE "order_customer_confirmations" ADD CONSTRAINT "order_customer_confirmations_purchase_item_id_fkey" FOREIGN KEY ("purchase_item_id") REFERENCES "purchase_items"("id") ON DELETE CASCADE;
ALTER TABLE "order_customer_confirmations" ADD CONSTRAINT "order_customer_confirmations_requested_by_fkey" FOREIGN KEY ("requested_by") REFERENCES "users"("id") ON DELETE SET NULL;
ALTER TABLE "order_invoices" ADD CONSTRAINT "fk_order_invoices_purchase" FOREIGN KEY ("purchase_id") REFERENCES "purchases"("id") ON DELETE CASCADE;
ALTER TABLE "order_invoices" ADD CONSTRAINT "order_invoices_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "users"("id") ON DELETE SET NULL;
ALTER TABLE "order_pharmacist_notes" ADD CONSTRAINT "fk_order_pharmacist_notes_purchase" FOREIGN KEY ("purchase_id") REFERENCES "purchases"("id") ON DELETE CASCADE;
ALTER TABLE "order_pharmacist_notes" ADD CONSTRAINT "order_pharmacist_notes_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE SET NULL;
ALTER TABLE "pharmacy_provider_settings" ADD CONSTRAINT "fk_pharmacy_provider_settings_provider" FOREIGN KEY ("provider_id") REFERENCES "service_providers"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "prescription_pharmacy_requests" ADD CONSTRAINT "prescription_pharmacy_requests_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE;
ALTER TABLE "prescription_pharmacy_requests" ADD CONSTRAINT "prescription_pharmacy_requests_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "documents"("id") ON DELETE RESTRICT;
ALTER TABLE "prescription_pharmacy_requests" ADD CONSTRAINT "prescription_pharmacy_requests_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "service_providers"("id") ON DELETE RESTRICT;
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_consultation_id_fkey" FOREIGN KEY ("consultation_id") REFERENCES "consultations"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "documents"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "pricing_rule_audits" ADD CONSTRAINT "pricing_rule_audits_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "pricing_rule_audits" ADD CONSTRAINT "pricing_rule_audits_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "wallets"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "products" ADD CONSTRAINT "products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "product_categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "provider_profile_branch_assignments" ADD CONSTRAINT "provider_profile_branch_assignments_business_fkey" FOREIGN KEY ("business_id") REFERENCES "businesses"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "provider_profile_branch_assignments" ADD CONSTRAINT "provider_profile_branch_assignments_profile_fkey" FOREIGN KEY ("provider_profile_id") REFERENCES "provider_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "provider_profiles" ADD CONSTRAINT "provider_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "purchase_item_fulfillments" ADD CONSTRAINT "fk_purchase_item_fulfillment_item" FOREIGN KEY ("purchase_item_id") REFERENCES "purchase_items"("id") ON DELETE CASCADE;
ALTER TABLE "purchase_item_fulfillments" ADD CONSTRAINT "purchase_item_fulfillments_decision_actor_id_fkey" FOREIGN KEY ("decision_actor_id") REFERENCES "users"("id") ON DELETE SET NULL;
ALTER TABLE "purchase_item_substitutions" ADD CONSTRAINT "fk_purchase_item_substitutions_item" FOREIGN KEY ("purchase_item_id") REFERENCES "purchase_items"("id") ON DELETE CASCADE;
ALTER TABLE "purchase_item_substitutions" ADD CONSTRAINT "fk_purchase_item_substitutions_prod" FOREIGN KEY ("substitute_product_id") REFERENCES "products"("id") ON DELETE SET NULL;
ALTER TABLE "purchase_item_substitutions" ADD CONSTRAINT "purchase_item_substitutions_proposed_by_fkey" FOREIGN KEY ("proposed_by") REFERENCES "users"("id") ON DELETE SET NULL;
ALTER TABLE "purchase_items" ADD CONSTRAINT "purchase_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "purchase_items" ADD CONSTRAINT "purchase_items_purchase_id_fkey" FOREIGN KEY ("purchase_id") REFERENCES "purchases"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "purchases" ADD CONSTRAINT "purchases_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "appointments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "purchases" ADD CONSTRAINT "purchases_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "purchases" ADD CONSTRAINT "purchases_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "service_providers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "reward_point_transactions" ADD CONSTRAINT "reward_point_transactions_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "reward_point_transactions" ADD CONSTRAINT "reward_point_transactions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "reward_point_transactions" ADD CONSTRAINT "reward_point_transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "wallets"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_permission_id_fkey" FOREIGN KEY ("permission_id") REFERENCES "permissions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "service_provider_payment_methods" ADD CONSTRAINT "sp_payment_methods_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "service_providers"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "service_providers" ADD CONSTRAINT "service_providers_business_id_fkey" FOREIGN KEY ("business_id") REFERENCES "businesses"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "shield_cards" ADD CONSTRAINT "shield_cards_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "shield_cards" ADD CONSTRAINT "shield_cards_issued_business_id_fkey" FOREIGN KEY ("issued_business_id") REFERENCES "businesses"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "store_change_requests" ADD CONSTRAINT "store_change_requests_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE;
ALTER TABLE "store_change_requests" ADD CONSTRAINT "store_change_requests_previous_provider_id_fkey" FOREIGN KEY ("previous_provider_id") REFERENCES "service_providers"("id") ON DELETE SET NULL;
ALTER TABLE "store_change_requests" ADD CONSTRAINT "store_change_requests_requested_provider_id_fkey" FOREIGN KEY ("requested_provider_id") REFERENCES "service_providers"("id") ON DELETE RESTRICT;
ALTER TABLE "store_change_requests" ADD CONSTRAINT "store_change_requests_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "users"("id") ON DELETE SET NULL;
ALTER TABLE "subscription_monthly_allocations" ADD CONSTRAINT "subscription_monthly_allocations_subscription_id_fkey" FOREIGN KEY ("subscription_id") REFERENCES "membership_subscriptions"("id") ON DELETE CASCADE;
ALTER TABLE "users" ADD CONSTRAINT "users_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "departments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "users" ADD CONSTRAINT "users_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "wallet_recharge_intents" ADD CONSTRAINT "wallet_recharge_intents_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE;
ALTER TABLE "wallet_recharge_intents" ADD CONSTRAINT "wallet_recharge_intents_payment_method_id_fkey" FOREIGN KEY ("payment_method_id") REFERENCES "service_provider_payment_methods"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "wallet_recharge_intents" ADD CONSTRAINT "wallet_recharge_intents_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "service_providers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "wallet_recharge_intents" ADD CONSTRAINT "wallet_recharge_intents_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "wallet_recharge_intents" ADD CONSTRAINT "wallet_recharge_intents_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "wallets"("id") ON DELETE RESTRICT;
ALTER TABLE "wallet_transactions" ADD CONSTRAINT "wallet_transactions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "wallet_transactions" ADD CONSTRAINT "wallet_transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "wallets"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "wallets" ADD CONSTRAINT "wallets_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "app"."admin_user" ADD CONSTRAINT "admin_user_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "app"."shield_store"("id") ON DELETE SET NULL;
ALTER TABLE "app"."agent" ADD CONSTRAINT "agent_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE SET NULL;
ALTER TABLE "app"."agent" ADD CONSTRAINT "agent_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "app"."agent"("id") ON DELETE SET NULL;
ALTER TABLE "app"."agent_customer" ADD CONSTRAINT "agent_customer_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "app"."agent"("id") ON DELETE CASCADE;
ALTER TABLE "app"."agent_customer" ADD CONSTRAINT "agent_customer_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE SET NULL;
ALTER TABLE "app"."agent_customer_plan" ADD CONSTRAINT "agent_customer_plan_agent_customer_id_fkey" FOREIGN KEY ("agent_customer_id") REFERENCES "app"."agent_customer"("id") ON DELETE CASCADE;
ALTER TABLE "app"."agent_customer_plan" ADD CONSTRAINT "agent_customer_plan_tier_id_fkey" FOREIGN KEY ("tier_id") REFERENCES "app"."membership_tier"("id") ON DELETE RESTRICT;
ALTER TABLE "app"."agent_customer_plan" ADD CONSTRAINT "agent_customer_plan_wallet_card_id_fkey" FOREIGN KEY ("wallet_card_id") REFERENCES "app"."wallet_card"("id") ON DELETE SET NULL;
ALTER TABLE "app"."agent_geo_node" ADD CONSTRAINT "agent_geo_node_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "app"."agent_geo_node"("id") ON DELETE CASCADE;
ALTER TABLE "app"."agent_wallet_transfer" ADD CONSTRAINT "agent_wallet_transfer_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "app"."agent"("id") ON DELETE CASCADE;
ALTER TABLE "app"."agent_wallet_transfer" ADD CONSTRAINT "agent_wallet_transfer_wallet_entry_id_fkey" FOREIGN KEY ("wallet_entry_id") REFERENCES "app"."wallet_entry"("id") ON DELETE SET NULL;
ALTER TABLE "app"."agent_withdrawal" ADD CONSTRAINT "agent_withdrawal_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "app"."agent"("id") ON DELETE CASCADE;
ALTER TABLE "app"."appointment" ADD CONSTRAINT "appointment_clinic_id_fkey" FOREIGN KEY ("clinic_id") REFERENCES "app"."clinic"("id") ON DELETE SET NULL;
ALTER TABLE "app"."appointment" ADD CONSTRAINT "appointment_dietitian_id_fkey" FOREIGN KEY ("dietitian_id") REFERENCES "app"."dietitian"("id") ON DELETE SET NULL;
ALTER TABLE "app"."appointment" ADD CONSTRAINT "appointment_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."appointment" ADD CONSTRAINT "appointment_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "app"."patient"("id") ON DELETE SET NULL;
ALTER TABLE "app"."approval" ADD CONSTRAINT "approval_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."approval" ADD CONSTRAINT "approval_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "app"."order"("id") ON DELETE SET NULL;
ALTER TABLE "app"."approval" ADD CONSTRAINT "approval_prescription_id_fkey" FOREIGN KEY ("prescription_id") REFERENCES "app"."prescription"("id") ON DELETE SET NULL;
ALTER TABLE "app"."approval_item" ADD CONSTRAINT "approval_item_approval_id_fkey" FOREIGN KEY ("approval_id") REFERENCES "app"."approval"("id") ON DELETE CASCADE;
ALTER TABLE "app"."cart" ADD CONSTRAINT "cart_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."cart_line" ADD CONSTRAINT "cart_line_cart_id_fkey" FOREIGN KEY ("cart_id") REFERENCES "app"."cart"("id") ON DELETE CASCADE;
ALTER TABLE "app"."cart_line" ADD CONSTRAINT "cart_line_prescription_fk" FOREIGN KEY ("prescription_id") REFERENCES "app"."prescription"("id") ON DELETE SET NULL;
ALTER TABLE "app"."cart_line" ADD CONSTRAINT "cart_line_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "app"."product"("id") ON DELETE SET NULL;
ALTER TABLE "app"."clinic_doctor" ADD CONSTRAINT "clinic_doctor_clinic_id_fkey" FOREIGN KEY ("clinic_id") REFERENCES "app"."clinic"("id") ON DELETE CASCADE;
ALTER TABLE "app"."device_push_token" ADD CONSTRAINT "device_push_token_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."health_article_section" ADD CONSTRAINT "health_article_section_article_id_fkey" FOREIGN KEY ("article_id") REFERENCES "app"."health_article"("id") ON DELETE CASCADE;
ALTER TABLE "app"."investor" ADD CONSTRAINT "investor_invested_store_id_fkey" FOREIGN KEY ("invested_store_id") REFERENCES "app"."shield_store"("id") ON DELETE SET NULL;
ALTER TABLE "app"."investor" ADD CONSTRAINT "investor_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE SET NULL;
ALTER TABLE "app"."investor_plan_change_request" ADD CONSTRAINT "investor_plan_change_request_investor_id_fkey" FOREIGN KEY ("investor_id") REFERENCES "app"."investor"("id") ON DELETE CASCADE;
ALTER TABLE "app"."lab_booking" ADD CONSTRAINT "lab_booking_address_id_fkey" FOREIGN KEY ("address_id") REFERENCES "app"."member_address"("id") ON DELETE SET NULL;
ALTER TABLE "app"."lab_booking" ADD CONSTRAINT "lab_booking_lab_package_id_fkey" FOREIGN KEY ("lab_package_id") REFERENCES "app"."lab_package"("id") ON DELETE RESTRICT;
ALTER TABLE "app"."lab_booking" ADD CONSTRAINT "lab_booking_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."lab_booking_patient" ADD CONSTRAINT "lab_booking_patient_lab_booking_id_fkey" FOREIGN KEY ("lab_booking_id") REFERENCES "app"."lab_booking"("id") ON DELETE CASCADE;
ALTER TABLE "app"."lab_booking_patient" ADD CONSTRAINT "lab_booking_patient_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "app"."patient"("id") ON DELETE SET NULL;
ALTER TABLE "app"."lab_profile" ADD CONSTRAINT "lab_profile_lab_package_id_fkey" FOREIGN KEY ("lab_package_id") REFERENCES "app"."lab_package"("id") ON DELETE CASCADE;
ALTER TABLE "app"."member_address" ADD CONSTRAINT "member_address_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."member_address" ADD CONSTRAINT "member_address_patient_fk" FOREIGN KEY ("patient_id") REFERENCES "app"."patient"("id") ON DELETE SET NULL;
ALTER TABLE "app"."membership_tier_load" ADD CONSTRAINT "membership_tier_load_tier_id_fkey" FOREIGN KEY ("tier_id") REFERENCES "app"."membership_tier"("id") ON DELETE CASCADE;
ALTER TABLE "app"."notification" ADD CONSTRAINT "notification_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."order" ADD CONSTRAINT "order_billed_wallet_card_fk" FOREIGN KEY ("billed_wallet_card_id") REFERENCES "app"."wallet_card"("id") ON DELETE SET NULL;
ALTER TABLE "app"."order" ADD CONSTRAINT "order_delivery_address_id_fkey" FOREIGN KEY ("delivery_address_id") REFERENCES "app"."member_address"("id") ON DELETE SET NULL;
ALTER TABLE "app"."order" ADD CONSTRAINT "order_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."order" ADD CONSTRAINT "order_payment_method_id_fkey" FOREIGN KEY ("payment_method_id") REFERENCES "app"."payment_method"("id") ON DELETE SET NULL;
ALTER TABLE "app"."order" ADD CONSTRAINT "order_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "app"."shield_store"("id") ON DELETE SET NULL;
ALTER TABLE "app"."order_line" ADD CONSTRAINT "order_line_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "app"."order"("id") ON DELETE CASCADE;
ALTER TABLE "app"."order_line" ADD CONSTRAINT "order_line_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "app"."product"("id") ON DELETE SET NULL;
ALTER TABLE "app"."order_receipt" ADD CONSTRAINT "order_receipt_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "app"."order"("id") ON DELETE CASCADE;
ALTER TABLE "app"."order_track_step" ADD CONSTRAINT "order_track_step_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "app"."order"("id") ON DELETE CASCADE;
ALTER TABLE "app"."patient" ADD CONSTRAINT "patient_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."prescription" ADD CONSTRAINT "prescription_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."prescription" ADD CONSTRAINT "prescription_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "app"."patient"("id") ON DELETE RESTRICT;
ALTER TABLE "app"."prescription" ADD CONSTRAINT "prescription_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "app"."shield_store"("id") ON DELETE SET NULL;
ALTER TABLE "app"."prescription_medicine" ADD CONSTRAINT "prescription_medicine_prescription_id_fkey" FOREIGN KEY ("prescription_id") REFERENCES "app"."prescription"("id") ON DELETE CASCADE;
ALTER TABLE "app"."prescription_medicine" ADD CONSTRAINT "prescription_medicine_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "app"."product"("id") ON DELETE SET NULL;
ALTER TABLE "app"."prescription_order" ADD CONSTRAINT "prescription_order_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "app"."order"("id") ON DELETE SET NULL;
ALTER TABLE "app"."prescription_order" ADD CONSTRAINT "prescription_order_prescription_id_fkey" FOREIGN KEY ("prescription_id") REFERENCES "app"."prescription"("id") ON DELETE CASCADE;
ALTER TABLE "app"."prescription_order" ADD CONSTRAINT "prescription_order_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "app"."shield_store"("id") ON DELETE SET NULL;
ALTER TABLE "app"."product" ADD CONSTRAINT "product_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "app"."product_category"("id") ON DELETE SET NULL;
ALTER TABLE "app"."product" ADD CONSTRAINT "product_subcategory_id_fkey" FOREIGN KEY ("subcategory_id") REFERENCES "app"."product_subcategory"("id") ON DELETE SET NULL;
ALTER TABLE "app"."product_detail" ADD CONSTRAINT "product_detail_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "app"."product"("id") ON DELETE CASCADE;
ALTER TABLE "app"."product_faq" ADD CONSTRAINT "product_faq_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "app"."product"("id") ON DELETE CASCADE;
ALTER TABLE "app"."product_subcategory" ADD CONSTRAINT "product_subcategory_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "app"."product_category"("id") ON DELETE CASCADE;
ALTER TABLE "app"."referral" ADD CONSTRAINT "referral_invitee_member_id_fkey" FOREIGN KEY ("invitee_member_id") REFERENCES "app"."users"("id") ON DELETE SET NULL;
ALTER TABLE "app"."referral" ADD CONSTRAINT "referral_inviter_member_id_fkey" FOREIGN KEY ("inviter_member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."reward_point_transaction" ADD CONSTRAINT "reward_point_transaction_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."users" ADD CONSTRAINT "member_home_store_id_fkey" FOREIGN KEY ("home_store_id") REFERENCES "app"."shield_store"("id") ON DELETE SET NULL;
ALTER TABLE "app"."users" ADD CONSTRAINT "member_referred_by_member_id_fkey" FOREIGN KEY ("referred_by_member_id") REFERENCES "app"."users"("id") ON DELETE SET NULL;
ALTER TABLE "app"."wallet" ADD CONSTRAINT "wallet_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "app"."users"("id") ON DELETE CASCADE;
ALTER TABLE "app"."wallet_card" ADD CONSTRAINT "wallet_card_sold_by_agent_fk" FOREIGN KEY ("sold_by_agent_id") REFERENCES "app"."agent"("id") ON DELETE SET NULL;
ALTER TABLE "app"."wallet_card" ADD CONSTRAINT "wallet_card_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "app"."shield_store"("id") ON DELETE SET NULL;
ALTER TABLE "app"."wallet_card" ADD CONSTRAINT "wallet_card_tier_id_fkey" FOREIGN KEY ("tier_id") REFERENCES "app"."membership_tier"("id") ON DELETE RESTRICT;
ALTER TABLE "app"."wallet_card" ADD CONSTRAINT "wallet_card_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "app"."wallet"("id") ON DELETE CASCADE;
ALTER TABLE "app"."wallet_entry" ADD CONSTRAINT "wallet_entry_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "app"."order"("id") ON DELETE SET NULL;
ALTER TABLE "app"."wallet_entry" ADD CONSTRAINT "wallet_entry_wallet_card_id_fkey" FOREIGN KEY ("wallet_card_id") REFERENCES "app"."wallet_card"("id") ON DELETE SET NULL;
ALTER TABLE "app"."wallet_entry" ADD CONSTRAINT "wallet_entry_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "app"."wallet"("id") ON DELETE CASCADE;
ALTER TABLE "neon_auth"."account" ADD CONSTRAINT "account_userId_fkey" FOREIGN KEY ("userId") REFERENCES "neon_auth"."user"("id") ON DELETE CASCADE;
ALTER TABLE "neon_auth"."invitation" ADD CONSTRAINT "invitation_inviterId_fkey" FOREIGN KEY ("inviterId") REFERENCES "neon_auth"."user"("id") ON DELETE CASCADE;
ALTER TABLE "neon_auth"."invitation" ADD CONSTRAINT "invitation_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "neon_auth"."organization"("id") ON DELETE CASCADE;
ALTER TABLE "neon_auth"."member" ADD CONSTRAINT "member_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "neon_auth"."organization"("id") ON DELETE CASCADE;
ALTER TABLE "neon_auth"."member" ADD CONSTRAINT "member_userId_fkey" FOREIGN KEY ("userId") REFERENCES "neon_auth"."user"("id") ON DELETE CASCADE;
ALTER TABLE "neon_auth"."session" ADD CONSTRAINT "session_userId_fkey" FOREIGN KEY ("userId") REFERENCES "neon_auth"."user"("id") ON DELETE CASCADE;