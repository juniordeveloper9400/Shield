import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import type { Env } from './config/env';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const config = app.get(ConfigService<Env, true>);

  // Every client (Flutter web build, shieldweb, shield agent_invester) is a
  // browser or app origin calling this API over HTTPS — see
  // backend/docs/migration-plan.md. Tighten to an explicit allowlist once
  // those origins are finalized for production.
  app.enableCors({ origin: true, credentials: true });

  const port = config.get('PORT', { infer: true });
  await app.listen(port);
  Logger.log(`SHIELD backend listening on :${port}`, 'Bootstrap');
}

bootstrap().catch((err) => {
  Logger.error('Fatal error during bootstrap', err instanceof Error ? err.stack : String(err), 'Bootstrap');
  process.exit(1);
});
