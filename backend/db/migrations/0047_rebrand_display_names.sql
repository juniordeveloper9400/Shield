-- ============================================================================
--  0047 · Display names: SHIELD -> Sahakar 360
-- ============================================================================
--  The product is now called Sahakar 360. This renames the stored display text
--  that still carries the old name, so the apps, the console and printed
--  invoices all read the same:
--
--    app.shield_store.name        'SHIELD Pharmacy Melattur' -> 'Sahakar 360 Pharmacy Melattur'
--    app.admin_user.name          'SHIELD Admin'             -> 'Sahakar 360 Admin'
--    app.clinic.name              'SHIELD Dental Care, ...'  -> 'Sahakar 360 Dental Care, ...'
--    app.health_article.author    'SHIELD Health Desk'       -> 'Sahakar 360 Health Desk'
--    app.payment_method.blurb     'Pay from your SHIELD wallet'
--
--  Deliberately NOT touched: identifiers and history — referral codes
--  (`SHIELD-1234`), promo codes (`SHIELD20`), store codes (`SHD-…`), the plan
--  tier names ('Silver Shield', …), past wallet ledger labels, uploaded file
--  names, and the schema/table names themselves (`app.shield_store`).
--
--  Idempotent — a re-run finds nothing left to replace:
--    dart run backend/db/apply_migration.dart backend/db/migrations/0047_rebrand_display_names.sql --yes
--
--  To undo, replace 'Sahakar 360' with 'SHIELD' in the same columns.
-- ============================================================================

SET search_path TO app, public;

UPDATE app.shield_store    SET name   = replace(name,   'SHIELD', 'Sahakar 360') WHERE name   LIKE '%SHIELD%';
UPDATE app.admin_user      SET name   = replace(name,   'SHIELD', 'Sahakar 360') WHERE name   LIKE '%SHIELD%';
UPDATE app.clinic          SET name   = replace(name,   'SHIELD', 'Sahakar 360') WHERE name   LIKE '%SHIELD%';
UPDATE app.health_article  SET author = replace(author, 'SHIELD', 'Sahakar 360') WHERE author LIKE '%SHIELD%';
UPDATE app.payment_method  SET blurb  = replace(blurb,  'SHIELD', 'Sahakar 360') WHERE blurb  LIKE '%SHIELD%';
