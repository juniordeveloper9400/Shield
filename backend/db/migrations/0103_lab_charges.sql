-- Additive rate settings only. Does not alter historical bookings or invoices.
CREATE TABLE IF NOT EXISTS app.lab_charge (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('TECHNICIAN', 'DISTANCE')),
  config JSONB NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE UNIQUE INDEX IF NOT EXISTS lab_charge_one_active_kind
  ON app.lab_charge(kind) WHERE is_active;
INSERT INTO app.lab_charge (name, kind, config, is_active)
SELECT 'Home collection distance', 'DISTANCE',
  '{"firstKm":3,"firstAmount":20,"secondKm":5,"secondAmount":50,"extraPerKm":15}'::jsonb, TRUE
WHERE NOT EXISTS (SELECT 1 FROM app.lab_charge WHERE kind = 'DISTANCE');
