import { Controller, Get, HttpStatus, Inject, Res } from '@nestjs/common';
import type { Response } from 'express';
import { sql } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { Public } from '../../common/decorators/public.decorator';

@Controller()
export class HealthController {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  /** Liveness — process is up. No dependency checks; must always be fast. */
  @Public()
  @Get('healthz')
  liveness() {
    return { status: 'ok' };
  }

  /** Readiness — safe to receive traffic (DB is reachable). */
  @Public()
  @Get('readyz')
  async readiness(@Res() res: Response) {
    try {
      await this.db.execute(sql`select 1`);
      res.status(HttpStatus.OK).json({ status: 'ok', db: 'up' });
    } catch (err) {
      res.status(HttpStatus.SERVICE_UNAVAILABLE).json({ status: 'unavailable', db: 'down', error: (err as Error).message });
    }
  }

  // TEMPORARY — second manual check that Sentry receives events, this time
  // with HttpExceptionFilter awaiting Sentry.flush() before responding (see
  // its own doc) — the first attempt returned a 500 correctly but nothing
  // ever reached the shield-backend project, most likely the serverless
  // function freezing before the SDK's async send completed. Remove once
  // confirmed in the Issues tab.
  @Public()
  @Get('_sentry-test')
  sentryTest(): never {
    throw new Error('Sentry test event #2 (with flush) — safe to ignore, this route is being removed');
  }
}
