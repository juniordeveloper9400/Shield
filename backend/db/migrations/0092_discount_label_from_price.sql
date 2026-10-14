-- The admin console no longer accepts a free-typed discount label (it could
-- say anything, independent of the real price/MRP gap). Backend now derives
-- it from price vs MRP on every create/update (see CatalogueService.
-- discountLabelFor) — this backfills every existing row the same way, so
-- products nobody edits again still show a label that matches their actual
-- price.
UPDATE app.product
SET discount_label = CASE
  WHEN mrp > 0 AND mrp > price AND ROUND((mrp - price) / mrp * 100) > 0
    THEN ROUND((mrp - price) / mrp * 100)::int || '% off'
  ELSE NULL
END;
