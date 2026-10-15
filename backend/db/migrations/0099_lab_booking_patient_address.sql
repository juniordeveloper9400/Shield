-- Lets each patient on a lab booking carry their own collection address,
-- instead of the one address the whole booking shares today — see
-- BookingService.bookLabTest/updateLabBookingDetails. Both new columns are
-- nullable and mirror app.lab_booking's own address_id/address_override
-- pair exactly; a null patient-level value falls back to the booking's own
-- address, so every booking made before this migration keeps behaving
-- exactly as it did (one shared address, just read from the booking row
-- instead of a patient row).
ALTER TABLE app.lab_booking_patient
  ADD COLUMN IF NOT EXISTS address_id bigint REFERENCES app.member_address(id),
  ADD COLUMN IF NOT EXISTS address_override text;
