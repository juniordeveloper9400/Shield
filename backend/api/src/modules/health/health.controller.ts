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
}
