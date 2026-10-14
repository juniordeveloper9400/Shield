-- Lets the admin console assign who collects a lab booking's sample
-- (mandatory before a HOME_COLLECTION booking is confirmed — see
-- BookingService.updateLabBookingStatus) and override the booking's own
-- collection address without ever touching the member's saved address book.
ALTER TABLE app.lab_booking
  ADD COLUMN IF NOT EXISTS assigned_staff_id bigint REFERENCES app.admin_user(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS address_override text;
