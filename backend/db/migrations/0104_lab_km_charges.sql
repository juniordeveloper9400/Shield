-- Extend saved settings with km charges calculated from a DISTANCE rate note.
-- Existing rule data, orders and invoices are preserved.
BEGIN;
ALTER TABLE app.lab_charge DROP CONSTRAINT IF EXISTS lab_charge_kind_check;
ALTER TABLE app.lab_charge ADD CONSTRAINT lab_charge_kind_check CHECK (kind IN ('TECHNICIAN', 'DISTANCE', 'KM'));
DROP INDEX IF EXISTS app.lab_charge_one_active_kind;
CREATE UNIQUE INDEX lab_charge_one_active_kind ON app.lab_charge(kind)
  WHERE is_active AND kind <> 'KM';
COMMIT;
