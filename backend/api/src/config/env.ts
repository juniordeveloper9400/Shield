import { z } from 'zod';

/**
 * Fails fast on missing/malformed config instead of surfacing a confusing
 * error three layers deep the first time a route touches the missing value.
 * Firebase is optional in non-production so a dev without credentials yet
 * can still boot the service and work on everything else.
 */
const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().int().positive().default(3000),
    DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
    JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET must be at least 32 characters'),
    JWT_REFRESH_SECRET: z.string().min(32, 'JWT_REFRESH_SECRET must be at least 32 characters'),
    FIREBASE_PROJECT_ID: z.string().optional(),
    FIREBASE_ADMIN_CREDENTIALS: z.string().optional(),
    FIREBASE_ADMIN_CREDENTIALS_FILE: z.string().optional(),
    // Optional outside production: CacheService degrades to "always miss,
    // always hit the DB" if Redis is unreachable — see cache/cache.service.ts.
    REDIS_URL: z.string().default('redis://localhost:6379'),
    // Private S3-compatible object storage — currently unused (prescription
    // images are stored as base64 in app.prescription.image directly, see
    // prescription.service.ts). Kept optional for a future re-migration back to
    // S3-compatible storage.
    OBJECT_STORAGE_ENDPOINT: z.string().optional(),
    OBJECT_STORAGE_REGION: z.string().default('auto'),
    OBJECT_STORAGE_BUCKET: z.string().optional(),
    OBJECT_STORAGE_ACCESS_KEY: z.string().optional(),
    OBJECT_STORAGE_SECRET_KEY: z.string().optional(),
    // Supabase Storage — no longer used. Customer review video bytes now live
    // in Neon Postgres (`app.customer_review_video_media`, see
    // modules/catalogue/review-video-media.service.ts); these three are kept,
    // still optional and unread by anything, only until the Neon storage
    // migration is verified in production (see docs/superpowers/specs/
    // 2026-09-23-neon-customer-video-storage-design.md's rollout notes) —
    // remove them once that is confirmed rather than now, so a rollback has
    // nothing extra to restore.
    // Blank (the checked-in .env.example's default before Supabase is set
    // up) must validate the same as unset — plain `.optional()` already
    // accepts '' for every other field here; `.url()` doesn't, so it needs
    // an explicit pass-through instead of rejecting local/test boot outright.
    SUPABASE_URL: z.preprocess((v) => (v === '' ? undefined : v), z.string().url().optional()),
    SUPABASE_SERVICE_ROLE_KEY: z.string().optional(),
    SUPABASE_PUBLIC_BUCKET: z.string().default('customer-reviews'),
    // Largest review video the API will hand out an upload link for. Supabase's
    // free plan caps every file at 50 MB; raise this (and the bucket's own
    // limit in Supabase) on a paid plan. The hard ceiling is 200 MB.
    REVIEW_VIDEO_MAX_MB: z.coerce.number().positive().max(200).default(50),
    // Error tracking (see instrument.ts). Optional everywhere, same as every
    // other integration here that degrades gracefully unset: leaving it
    // blank just means Sentry stays disabled, not a boot failure.
    SENTRY_DSN: z.string().optional(),
  })
  .superRefine((val, ctx) => {
    if (val.NODE_ENV === 'production') {
      if (!val.FIREBASE_PROJECT_ID) {
        ctx.addIssue({ code: 'custom', path: ['FIREBASE_PROJECT_ID'], message: 'required in production' });
      }
      if (!val.FIREBASE_ADMIN_CREDENTIALS && !val.FIREBASE_ADMIN_CREDENTIALS_FILE) {
        ctx.addIssue({
          code: 'custom',
          path: ['FIREBASE_ADMIN_CREDENTIALS'],
          message: 'FIREBASE_ADMIN_CREDENTIALS or FIREBASE_ADMIN_CREDENTIALS_FILE is required in production',
        });
      }
    }
  });

export type Env = z.infer<typeof envSchema>;

export function validateEnv(config: Record<string, unknown>): Env {
  const result = envSchema.safeParse(config);
  if (!result.success) {
    const issues = result.error.issues.map((i) => `  - ${i.path.join('.')}: ${i.message}`).join('\n');
    throw new Error(`Invalid environment configuration:\n${issues}`);
  }
  return result.data;
}
