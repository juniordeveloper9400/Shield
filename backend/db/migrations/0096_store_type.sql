-- Lets the console categorise a branch as a standalone pharmacy, a
-- standalone lab, or both (the existing default behaviour) — see
-- CatalogueService.createStore/updateStore, which always derives
-- offers_lab_collection from this rather than trusting it independently.
DO $$ BEGIN
  CREATE TYPE app.store_type AS ENUM ('PHARMACY', 'LAB', 'PHARMACY_LAB');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE app.shield_store
  ADD COLUMN IF NOT EXISTS store_type app.store_type NOT NULL DEFAULT 'PHARMACY_LAB';

-- Backfill from the existing flag: no branch has ever been lab-only before
-- this, so every existing row stays exactly what it already behaved as —
-- a pharmacy, with or without lab collection.
UPDATE app.shield_store
SET store_type = (CASE WHEN offers_lab_collection THEN 'PHARMACY_LAB' ELSE 'PHARMACY' END)::app.store_type;
