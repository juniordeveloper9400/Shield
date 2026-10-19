-- Carries whether the member applied their Health Pass coupon at checkout
-- (and which plan), so the lab/admin can see it was invoked and settle the
-- bill at that plan's home-care rate. A visual confirmation on the member's
-- own screens, not something the booking's own price is computed from.
ALTER TABLE app.lab_booking
  ADD COLUMN IF NOT EXISTS health_pass_applied boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS health_pass_tier text;
