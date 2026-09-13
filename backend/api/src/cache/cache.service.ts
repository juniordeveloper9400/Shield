import { Inject, Injectable, Logger } from '@nestjs/common';
import type Redis from 'ioredis';
import { REDIS_CLIENT } from './redis.client';

/**
 * Cache-aside pattern for the highest-read-volume paths in the system
 * (catalogue, and later anything similarly read-heavy) — see
 * backend/docs/trd.md "Non-functional requirements". A Redis outage
 * degrades to "always miss, hit Postgres every time", never to a 500 —
 * losing the speedup is fine, losing availability is not.
 */
@Injectable()
export class CacheService {
  private readonly logger = new Logger(CacheService.name);

  constructor(@Inject(REDIS_CLIENT) private readonly redis: Redis) {}

  async getOrSet<T>(key: string, ttlSeconds: number, load: () => Promise<T>): Promise<T> {
    try {
      const cached = await this.redis.get(key);
      if (cached !== null) return JSON.parse(cached) as T;
    } catch (err) {
      this.logger.warn(`Cache read failed for "${key}", falling through to DB: ${(err as Error).message}`);
    }

    const value = await load();

    try {
      await this.redis.set(key, JSON.stringify(value), 'EX', ttlSeconds);
    } catch (err) {
      this.logger.warn(`Cache write failed for "${key}": ${(err as Error).message}`);
    }

    return value;
  }

  /** Deletes one or more exact keys, or key patterns (containing "*") on a staff write. */
  async invalidate(...keysOrPatterns: string[]): Promise<void> {
    for (const pattern of keysOrPatterns) {
      try {
        if (pattern.includes('*')) {
          const keys = await this.redis.keys(pattern);
          if (keys.length > 0) await this.redis.del(...keys);
        } else {
          await this.redis.del(pattern);
        }
      } catch (err) {
        this.logger.warn(`Cache invalidate failed for "${pattern}": ${(err as Error).message}`);
      }
    }
  }
}
