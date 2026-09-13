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
    // Object storage for prescription images and other member uploads —
    // see backend/docs/security.md. Optional outside production; tests use
    // an in-memory double (test/integration/fake-object-storage.ts).
    OBJECT_STORAGE_ENDPOINT: z.string().optional(),
    OBJECT_STORAGE_REGION: z.string().default('auto'),
    OBJECT_STORAGE_BUCKET: z.string().optional(),
    OBJECT_STORAGE_ACCESS_KEY: z.string().optional(),
    OBJECT_STORAGE_SECRET_KEY: z.string().optional(),
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
      for (const key of ['OBJECT_STORAGE_ENDPOINT', 'OBJECT_STORAGE_BUCKET', 'OBJECT_STORAGE_ACCESS_KEY', 'OBJECT_STORAGE_SECRET_KEY'] as const) {
        if (!val[key]) ctx.addIssue({ code: 'custom', path: [key], message: `${key} is required in production` });
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
