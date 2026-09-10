# Admin Console TRD

## Runtime

- React 18, TypeScript, Vite, React Router 6.
- Tailwind CSS 3 with PostCSS/Autoprefixer.
- `@neondatabase/serverless` query layer under `shieldweb/src/api/`.
- Vercel/SPA deployment configuration with `dist` output.

## Application boundaries

`src/main.tsx` composes `BrowserRouter` and `AuthProvider`; `src/App.tsx` defines routes; pages compose UI; API modules own SQL; `permissions.ts` defines role/module policy.

## Current security boundary

There is no trusted backend boundary. Credentials, database URL, queries, and client-side permission logic are browser-visible. This is an internal-only state, not a production architecture.

## Target architecture

Introduce server-managed authentication, short-lived sessions, server-side role/branch authorization, validated mutations, audit events, and a server-owned Neon connection. Keep the browser API contract thin and typed.

## Build gates

Run `npm run typecheck` and `npm run build`. Add route-refresh and role smoke checks. Do not deploy publicly until the target security architecture is implemented and tested.
