# Sentry (crash and error reporting)

Sentry is wired into all four applications, each reporting to its own DSN so an issue in one never gets mixed into another's stream. Every wiring follows the same rule the rest of this repo already uses for optional integrations: leaving the DSN unset simply leaves Sentry disabled — it is never a build or boot failure.

A DSN is not a secret. It only identifies which Sentry project events go to; it grants no read access to anything and is meant to travel in client-side code (the same way a Firebase web config does). It is fine in `.env.example` placeholders, build scripts, and the shipped JS/APK.

## 1. Create the account and projects

1. Sign up (or sign in) at [sentry.io](https://sentry.io), or use an existing organization if your team already has one.
2. Create one project per app, so each gets its own DSN and issue stream:

   | App | Sentry platform to pick | Where its DSN goes |
   | --- | --- | --- |
   | `backend/api` | Node.js → NestJS | `backend/api/.env`'s `SENTRY_DSN` |
   | Root Flutter app (`lib/`) | Flutter | root `.env`'s `SENTRY_DSN` |
   | `shield agent_invester/` | Flutter (a second project, or reuse the one above — see note below) | `shield agent_invester/.env`'s `SENTRY_DSN`, and the Vercel project's `SENTRY_DSN` env var for its web build |
   | `shieldweb` | React | `shieldweb/.env.local`'s `VITE_SENTRY_DSN`, and the Vercel project's `VITE_SENTRY_DSN` env var |

   The two Flutter apps *can* share one Sentry project (Sentry tags events by platform/release regardless), but separate projects make "which app is this crash from" a given rather than something read off event tags — worth the extra project on a free plan.

3. For each project, get its DSN: **Project → Settings → Client Keys (DSN)**. It looks like `https://<key>@<org>.ingest.<region>.sentry.io/<project_id>`.

4. Invite anyone who needs to see issues under **Organization Settings → Members**. Access is managed entirely on sentry.io — there is nothing to configure in this repo for who can *see* events, only for which project *receives* them.

## 2. Wire each app's DSN in

Every app already has the code-side integration; only the DSN needs supplying, the same way `DATABASE_URL` already works in this repo.

- **`backend/api`**: `SENTRY_DSN=` in `.env` (copy `.env.example` first if you have not). Read by `src/instrument.ts`, which must stay the very first import in `src/main.ts` — Sentry's Nest/HTTP instrumentation has to wrap modules before they load. `src/common/filters/http-exception.filter.ts` reports every unhandled (truly-500) exception; an expected 4xx (bad input, wrong password, not-found) is never sent, so it never counts against the project's event quota.
- **Root Flutter app**: `SENTRY_DSN=` in the repo-root `.env`. `flutter run --dart-define-from-file=.env` picks it up automatically for local dev (it has no `&`, unlike `DATABASE_URL`, so this works cleanly on Windows too); `build_apk.ps1` reads the same line and compiles it into the release APK; `flutter build web` needs `--dart-define=SENTRY_DSN=<dsn>` (or the same `--dart-define-from-file=.env`) passed by hand — see [Deployment](deployment.md).
- **`shield agent_invester/`**: same `.env` convention for local dev and `build_apk.ps1`. Its web build runs on Vercel via `vercel-build.sh`, which reads a `SENTRY_DSN` Vercel **project environment variable** (Project Settings → Environment Variables) rather than a committed file — set it there and redeploy.
- **`shieldweb`**: `VITE_SENTRY_DSN=` in `shieldweb/.env.local` for local dev. For the hosted console, set `VITE_SENTRY_DSN` as a Vercel project environment variable and redeploy — Vite embeds it at build time, so a value changed after the fact needs a new build to take effect.

## 3. Verify it is actually reporting

Trigger one real error per app and confirm it lands in that project's **Issues** list within a minute or two:

- **`backend/api`**: hit any route with something that throws before it reaches a normal `HttpException` (or temporarily throw inside a handler), then check `Sentry.captureException` fired — the response still comes back as the usual `{"error": {"code": "INTERNAL", ...}}` envelope; Sentry only sees the exception, never the response. **`src/main.ts` is not what runs in production** — `vercel.json` points at `api/index.js`, a separate, hand-written entrypoint for the same reason `bodyParser`'s limit is set in both places (see that file's own comment). `api/index.js` must `require('../dist/instrument')` as its own first line, same rule as `main.ts`'s `import './instrument'` — miss it there and the DSN is set, deploys look fine, and the project still never receives a single event, because `Sentry.init()` simply never ran in the process actually serving requests.
- **Flutter apps**: `FlutterError.onError` and `PlatformDispatcher.instance.onError` are installed by `SentryFlutter.init` — a widget-build error or an uncaught async error already surfaces. `appRunner` is intentionally not used here (see `main.dart`'s comment), so a crash that happens before `SentryFlutter.init` finishes (extremely early in `main()`) will not be captured — that is an accepted, narrow gap, not a bug.
- **`shieldweb`**: `Sentry.init` in `main.tsx` catches uncaught exceptions and unhandled promise rejections by default. Throw from a component temporarily, confirm the issue appears, then remove the test throw.

## 4. Optional next steps, not done here

- **Performance tracing** (`tracesSampleRate`) is left at `0` in every app — Sentry's performance product bills against the same event quota as errors, separately from this repo's own OpenTelemetry tracing plan (`backend/docs/tech-stack.md`). Raise it (0.0-1.0) per app only if Sentry's own tracing is wanted too.
- **Source maps / symbolication** (readable stack traces instead of minified JS or obfuscated Dart) are not uploaded anywhere yet. That is a separate Sentry CLI step (`sentry-cli sourcemaps upload` for `shieldweb`, Sentry's Flutter/dSYM and ProGuard mapping upload for the two apps' release builds) — worth doing once real crashes start arriving and a stack trace is hard to read as shipped.
- **Alerting** (Slack/email on new issues) is configured per project on sentry.io, under **Alerts** — nothing in this repo gates that.
