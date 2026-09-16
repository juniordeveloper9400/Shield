-- ============================================================================
--  0034 · Backfill icon_name / panel_tint for the seeded categories
-- ============================================================================
--  Migration 0004 (and backend/db/seed_app.dart's _seedCategories /
--  _seedSubcategories) inserted app.product_category and
--  app.product_subcategory rows with no icon_name or panel_tint. The app and
--  the console both fall back to a generic outline icon
--  (Icons.category_outlined) for a blank/unrecognized icon_name — that generic
--  glyph showing for every "Shop by categories" chip and sub-category tile is
--  this gap, not a rendering bug.
--
--  This backfills the same icons/tints the bundled Dart seed
--  (lib/module/categories/category_catalogue.dart) already uses for these
--  exact titles, so the live data matches what the app shipped with. Only
--  touches rows that are still blank, so it never overwrites an icon an
--  admin has since picked in the console, and is safe to re-run.
--
--    dart run backend/db/apply_migration.dart backend/db/migrations/0034_backfill_category_icons.sql --yes
-- ============================================================================

SET search_path TO app, public;

-- --- product_category -------------------------------------------------
UPDATE app.product_category SET icon_name = 'spa_outlined', panel_tint = 'panelGreen'
  WHERE slug = 'personal-care' AND (icon_name IS NULL OR icon_name = '');
UPDATE app.product_category SET icon_name = 'monitor_heart_outlined', panel_tint = 'panelCream'
  WHERE slug = 'health-conditions' AND (icon_name IS NULL OR icon_name = '');
UPDATE app.product_category SET icon_name = 'medication_outlined', panel_tint = 'panelBlue'
  WHERE slug = 'vitamins-supplements' AND (icon_name IS NULL OR icon_name = '');
UPDATE app.product_category SET icon_name = 'bloodtype_outlined', panel_tint = 'panelPink'
  WHERE slug = 'diabetes-care' AND (icon_name IS NULL OR icon_name = '');
UPDATE app.product_category SET icon_name = 'medical_services_outlined', panel_tint = 'panelSlate'
  WHERE slug = 'surgicals' AND (icon_name IS NULL OR icon_name = '');
UPDATE app.product_category SET icon_name = 'biotech_outlined', panel_tint = 'pageTint'
  WHERE slug = 'lab-tests' AND (icon_name IS NULL OR icon_name = '');

-- --- product_subcategory ------------------------------------------------
WITH icons(cat_slug, label, icon_name) AS (
  VALUES
    ('personal-care',        'Skin Care',             'face_retouching_natural_outlined'),
    ('personal-care',        'Hair Care',              'content_cut_rounded'),
    ('personal-care',        'Oral Care',              'clean_hands_outlined'),
    ('personal-care',        'Bath & Body',            'shower_outlined'),
    ('personal-care',        'Men Grooming',           'face_outlined'),
    ('personal-care',        'Feminine Care',          'favorite_outline_rounded'),

    ('health-conditions',    'Bone and Joint Care',    'accessibility_new_rounded'),
    ('health-conditions',    'Digestive Care',         'local_dining_outlined'),
    ('health-conditions',    'Eye Care',               'remove_red_eye_outlined'),
    ('health-conditions',    'Pain Relief',             'healing_outlined'),
    ('health-conditions',    'Smoking Cessation',      'smoke_free_rounded'),
    ('health-conditions',    'Liver Care',             'water_drop_outlined'),

    ('vitamins-supplements', 'Multivitamins',          'medication_liquid_outlined'),
    ('vitamins-supplements', 'Vitamin D',              'wb_sunny_outlined'),
    ('vitamins-supplements', 'Protein Powder',         'fitness_center_rounded'),
    ('vitamins-supplements', 'Omega & Fish Oil',       'set_meal_outlined'),
    ('vitamins-supplements', 'Calcium',                'emoji_food_beverage_outlined'),
    ('vitamins-supplements', 'Immunity',               'shield_outlined'),

    ('diabetes-care',        'Glucometers',            'speed_rounded'),
    ('diabetes-care',        'Test Strips',            'receipt_long_outlined'),
    ('diabetes-care',        'Sugar Substitutes',      'coffee_outlined'),
    ('diabetes-care',        'Diabetic Food',          'rice_bowl_outlined'),
    ('diabetes-care',        'Foot Care',              'airline_seat_legroom_normal_rounded'),
    ('diabetes-care',        'Insulin Support',        'vaccines_outlined'),

    ('surgicals',            'Gloves & Masks',         'masks_outlined'),
    ('surgicals',            'Bandages & Dressings',   'healing_outlined'),
    ('surgicals',            'Syringes & Needles',     'vaccines_outlined'),
    ('surgicals',            'Supports & Braces',      'accessibility_new_rounded'),
    ('surgicals',            'First Aid Kits',         'medical_services_outlined'),
    ('surgicals',            'Mobility Aids',          'airline_seat_recline_normal_rounded'),

    ('lab-tests',            'Full Body Checkup',      'fact_check_outlined'),
    ('lab-tests',            'Blood Tests',            'bloodtype_outlined'),
    ('lab-tests',            'Thyroid Profile',        'biotech_outlined'),
    ('lab-tests',            'Vitamin Tests',          'science_outlined')
)
UPDATE app.product_subcategory sc
   SET icon_name = icons.icon_name
  FROM icons
  JOIN app.product_category c ON c.slug = icons.cat_slug
 WHERE sc.category_id = c.id
   AND lower(sc.label) = lower(icons.label)
   AND (sc.icon_name IS NULL OR sc.icon_name = '');
