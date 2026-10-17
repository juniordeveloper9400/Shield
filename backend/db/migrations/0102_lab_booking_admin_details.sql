-- Booking-only corrections; never update a member's account or saved patient.
BEGIN;
ALTER TABLE app.lab_booking ADD COLUMN IF NOT EXISTS contact_name text;
ALTER TABLE app.lab_booking ADD COLUMN IF NOT EXISTS contact_phone text;
ALTER TABLE app.lab_booking ADD COLUMN IF NOT EXISTS address_phone_override text;
ALTER TABLE app.lab_booking_patient ADD COLUMN IF NOT EXISTS details jsonb;
COMMIT;
