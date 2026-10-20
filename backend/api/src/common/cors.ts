/**
 * Which browser origins may call this API.
 *
 * Native apps (the Android/iOS Flutter builds) and server-to-server calls send
 * no `Origin` header at all, so they are always let through. A browser origin
 * must be on the list: the web console and the Flutter web builds' own hosts,
 * localhost for development, and anything added through
 * `CORS_ALLOWED_ORIGINS` (comma-separated, exact origins such as
 * `https://admin.example.com`) — set that on the deployment when a new domain
 * (a custom domain, a new Vercel project) starts calling the API.
 */
export const DEFAULT_ALLOWED_ORIGINS = [
  'https://shield-web-liart.vercel.app',
  'https://shield-webapp.vercel.app',
  'https://shield-webapp-xq85.vercel.app',
  'https://shieldappweb.vercel.app',
  'https://shield-lilac-six.vercel.app',
];

const LOCALHOST = /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/;

export function parseAllowedOrigins(extra: string | undefined): string[] {
  const added = (extra ?? '')
    .split(',')
    .map((o) => o.trim().replace(/\/+$/, ''))
    .filter(Boolean);
  return [...new Set([...DEFAULT_ALLOWED_ORIGINS, ...added])];
}

export function isOriginAllowed(origin: string | undefined, allowed: string[], isProduction: boolean): boolean {
  // No Origin header: a native app, curl or another server — not a browser
  // page, so CORS does not apply to it.
  if (!origin) return true;
  if (allowed.includes(origin.replace(/\/+$/, ''))) return true;
  // Local development only; a production deployment never trusts localhost.
  return !isProduction && LOCALHOST.test(origin);
}
