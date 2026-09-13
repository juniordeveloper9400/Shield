import { Inject, Injectable, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Pool } from 'pg';
import { drizzle, NodePgDatabase } from 'drizzle-orm/node-postgres';
import * as schema from './schema';
import type { Env } from '../config/env';

export const DRIZZLE = Symbol('DRIZZLE');
export type Database = NodePgDatabase<typeof schema>;

/**
 * One bounded pool per instance, routed through Neon's pooler — see
 * backend/docs/trd.md "Non-functional requirements". This replaces the
 * current pattern of every client opening its own connection directly.
 */
@Injectable()
export class DrizzleService implements OnModuleDestroy {
  readonly pool: Pool;
  readonly db: Database;

  constructor(config: ConfigService<Env, true>) {
    this.pool = new Pool({
      connectionString: config.get('DATABASE_URL', { infer: true }),
      max: 15,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 10_000,
    });
    this.db = drizzle(this.pool, { schema });
  }

  async onModuleDestroy() {
    await this.pool.end();
  }
}

export const DrizzleProvider = {
  provide: DRIZZLE,
  useFactory: (svc: DrizzleService) => svc.db,
  inject: [DrizzleService],
};

export const InjectDb = () => Inject(DRIZZLE);
