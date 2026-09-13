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
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
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
