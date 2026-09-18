/**
 * Vercel serverless entrypoint. Deliberately plain CommonJS (not compiled
 * by Vercel's function bundler) requiring the already-`tsc`-built app in
 * ../dist — Nest's DI depends on `emitDecoratorMetadata`, which Vercel's
 * esbuild-based function bundler does not emit, so the decorator-driven
 * bootstrap has to happen at `pnpm build` time, not at bundle time.
 *
 * The Nest app is created once per warm serverless instance (`cachedServer`)
 * and its underlying Express instance is reused across invocations — same
 * pattern as main.ts's bootstrap(), minus the app.listen().
 */
const { NestFactory } = require('@nestjs/core');
const { AppModule } = require('../dist/app.module');

let cachedServer;

async function bootstrap() {
  // No bufferLogs here: it holds every Logger call (including runtime
  // request errors, not just bootstrap output) until app.useLogger() is
  // called, which nothing here ever does — so buffered logs never reach
  // Vercel's log viewer at all, not even on crash.
  //
  // bodyParser: false, replaced below with the same higher-limit parsers
  // main.ts's own bootstrap() uses — see that file's doc comment for why:
  // Nest's default 100kb JSON limit silently rejects any request carrying
  // an image (every prescription scan, receipt, and bill photo in this app
  // travels as a base64 data: URI inside a plain JSON body). This is the
  // entrypoint Vercel actually serves in production, so the fix has to
  // land here too, not just in the plain-Node bootstrap.
  const app = await NestFactory.create(AppModule, { bodyParser: false });
  app.useBodyParser('json', { limit: '15mb' });
  app.useBodyParser('urlencoded', { extended: true, limit: '15mb' });
  app.enableCors({ origin: true, credentials: true });
  await app.init();
  return app.getHttpAdapter().getInstance();
}

module.exports = async (req, res) => {
  if (!cachedServer) {
    cachedServer = await bootstrap();
  }
  return cachedServer(req, res);
};
