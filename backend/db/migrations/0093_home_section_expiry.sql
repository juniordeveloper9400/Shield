-- Lets the console set an expiry when it adds a product to a home-feed
-- section (Popular Items / Deals You Love / Offer of the Day). Past that
-- moment the product stops showing in that section on its own — the
-- is_popular/is_deal/is_offer_of_day flag is left as-is (so the console can
-- still see and edit what was set); member-facing reads just stop counting
-- the flag once its "until" has passed. See CatalogueService.
ALTER TABLE app.product
  ADD COLUMN IF NOT EXISTS popular_until timestamptz,
  ADD COLUMN IF NOT EXISTS deal_until timestamptz,
  ADD COLUMN IF NOT EXISTS offer_of_day_until timestamptz;
