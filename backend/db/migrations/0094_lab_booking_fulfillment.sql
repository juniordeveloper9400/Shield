-- Lets a member choose how their lab sample reaches the lab at booking
-- time: the lab visits them (home collection, the existing default
-- behaviour) or they visit the branch themselves (store visit). Only home
-- collection needs a delivery address; see BookingService.bookLabTest.
DO $$ BEGIN
  CREATE TYPE app.lab_booking_fulfillment AS ENUM ('HOME_COLLECTION', 'STORE_VISIT');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE app.lab_booking
  ADD COLUMN IF NOT EXISTS fulfillment_type app.lab_booking_fulfillment NOT NULL DEFAULT 'HOME_COLLECTION';
