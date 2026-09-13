import type { Config } from 'drizzle-kit';

export default {
  schema: './src/db/schema/index.ts',
  out: './src/db/migrations',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL ?? '',
  },
  // This service never generates a DESTRUCTIVE recreate migration against the
  // shared `app` schema — only additive changes to its own `backend` schema,
  // or changes reviewed and applied through backend/db/ tooling for `app`.
  // See backend/docs/erd.md and backend/docs/migration-plan.md Phase 0.
} satisfies Config;
