-- Per-account sidebar/module override (shieldweb's Staff Login "Edit"
-- page) — NULL (the default, every existing row) means "everything the
-- role grants", unchanged from today's behaviour. A non-null array
-- narrows that account to exactly the module keys listed, checked by
-- ModuleGuard on every request alongside (never instead of) the existing
-- role check. See common/module-routes.ts for the route-to-module map.
ALTER TABLE app.admin_user
  ADD COLUMN IF NOT EXISTS modules text[];
