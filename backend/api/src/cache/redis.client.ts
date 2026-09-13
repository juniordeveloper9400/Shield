import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import type { Env } from '../config/env';

export const REDIS_CLIENT = Symbol('REDIS_CLIENT');

export const RedisProvider = {
  provide: REDIS_CLIENT,
  useFactory: (config: ConfigService<Env, true>) => {
    const client = new Redis(config.get('REDIS_URL', { infer: true }), {
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      // Never let a Redis outage take catalogue reads down with it —
      // CacheService catches connection errors and falls through to
      // Postgres. This just keeps ioredis itself from logging a storm of
      // reconnect noise when Redis genuinely isn't there (e.g. local dev
      // without it running).
      retryStrategy: () => null,
    });
    client.on('error', () => {
      /* swallowed deliberately — CacheService logs the operation that failed */
    });
    return client;
  },
  inject: [ConfigService],
};
