// Must be the very first import in main.ts — before reflect-metadata, before
// anything else — so Sentry's Nest/HTTP instrumentation wraps modules before
// they load. See https://docs.sentry.io/platforms/javascript/guides/nestjs/.
//
// Safe to import unconditionally: the SDK itself treats a missing/empty
// `dsn` as "stay disabled" (its own documented no-op behavior), the same
// contract every other optional integration in this service already
// follows (Redis, Supabase Storage) — nothing here needs its own
// `if (SENTRY_DSN)` guard.
import * as Sentry from '@sentry/nestjs';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  // Off by default — tracing/performance monitoring counts separately
  // against a Sentry plan's quota from error events, and this service
  // already has its own OpenTelemetry tracing story (see
  // backend/docs/tech-stack.md). Raise this (0.0–1.0) only if Sentry's own
  // performance product is wanted too.
  tracesSampleRate: 0,
});
