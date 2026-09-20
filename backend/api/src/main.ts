import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import type { Env } from './config/env';

async function bootstrap() {
  // bodyParser: false — Nest's own default (Express's body-parser) caps a
  // JSON body at 100kb, silently rejecting the request (a 413, never
  // reaching a controller or even the Zod pipe) before anything here gets a
  // chance to log it. Every image this app moves — a prescription scan, a
  // wallet-card/order receipt, a bill photo — travels as a base64 data: URI
  // inside a plain JSON body, and even one compressed to ~250KB raw becomes
  // well over 100kb once base64-encoded; a receipt (up to 5MB raw, see
  // `receipt_form.dart`'s kReceiptMaxBytes) is nowhere close to fitting.
  // Replaced below with the same parsers at a limit that comfortably covers
  // every real payload this API accepts.
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bufferLogs: true,
    bodyParser: false,
  });
  app.useBodyParser('json', { limit: '15mb' });
  app.useBodyParser('urlencoded', { extended: true, limit: '15mb' });
  const config = app.get(ConfigService<Env, true>);

  // Every client (Flutter web build, shieldweb, shield agent_invester) is a
  // browser or app origin calling this API over HTTPS — see
  // backend/docs/migration-plan.md. Tighten to an explicit allowlist once
  // those origins are finalized for production.
  app.enableCors({ origin: true, credentials: true });

  const port = config.get('PORT', { infer: true });
  await app.listen(port);
  Logger.log(`Sahakar 360 backend listening on :${port}`, 'Bootstrap');
}

bootstrap().catch((err) => {
  Logger.error('Fatal error during bootstrap', err instanceof Error ? err.stack : String(err), 'Bootstrap');
  process.exit(1);
});
