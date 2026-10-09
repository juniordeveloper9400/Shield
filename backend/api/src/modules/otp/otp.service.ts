import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from '../../config/env';

const VERIFY_URL = 'https://control.msg91.com/api/v5/widget/verifyAccessToken';

export interface VerifyMsg91Result {
  ok: boolean;
  reason?: string;
}

/**
 * Confirms an MSG91 Widget access-token server-side — the replacement for
 * what Firebase Phone Auth used to do silently client-side in
 * `shieldweb/src/lib/deliveryOtp.ts`: prove whoever typed the OTP code
 * really holds a specific phone, before any money-moving action (wallet
 * collection) is allowed to proceed. The access-token alone proves nothing
 * on its own — MSG91's widget runs entirely in the browser, so a token the
 * browser merely *claims* is valid must still be checked against MSG91's
 * own servers with the Auth Key, which never leaves the backend.
 *
 * KNOWN GAP, same as the Firebase version it replaces: nothing calls this
 * from `collectBillWithWallet` itself — the money-moving endpoint still
 * trusts that the browser only calls it after this check succeeds. Fixing
 * that is a separate, bigger change to the wallet-collection endpoints
 * themselves, not part of swapping the OTP provider.
 *
 * STATUS: MSG91's own docs would not render for automated fetching, and a
 * live test response was never captured during setup — the field this
 * reads the verified phone number from (`verifiedPhoneFrom`) is a
 * best-effort guess across the field names MSG91's docs and widget
 * callbacks commonly use. The raw response is logged (server-side only,
 * never returned to the client) specifically so the first real call in
 * practice can be read back out of the logs and this function corrected
 * to match exactly, before this is relied on for real collections.
 */
@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(private readonly config: ConfigService<Env, true>) {}

  async verifyMsg91AccessToken(accessToken: string, expectedPhone: string): Promise<VerifyMsg91Result> {
    const authkey = this.config.get('MSG91_AUTH_KEY', { infer: true });
    if (!authkey) {
      return { ok: false, reason: 'OTP verification is not configured on the server yet.' };
    }

    let body: unknown;
    try {
      const res = await fetch(VERIFY_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ authkey, 'access-token': accessToken }),
      });
      body = await res.json().catch(() => null);
      // See this class's own doc — this is the one place the real shape of
      // MSG91's response can actually be read, until a confirmed sample
      // replaces the guesswork in verifiedPhoneFrom below.
      this.logger.log(`MSG91 verifyAccessToken response: ${JSON.stringify(body)}`);
      if (!res.ok) {
        return { ok: false, reason: `MSG91 rejected the token (HTTP ${res.status}).` };
      }
    } catch (error) {
      this.logger.error('MSG91 verifyAccessToken request failed', error instanceof Error ? error.stack : error);
      return { ok: false, reason: 'Could not reach MSG91 to verify the code.' };
    }

    if (isFailureShape(body)) {
      return { ok: false, reason: 'That code is not right or has expired.' };
    }

    const verifiedPhone = verifiedPhoneFrom(body);
    if (!verifiedPhone) {
      this.logger.warn('MSG91 verifyAccessToken: could not find a phone number in the response — see the logged response above.');
      return { ok: false, reason: 'Could not confirm which phone this code verified.' };
    }

    if (!lastTenDigitsMatch(verifiedPhone, expectedPhone)) {
      return { ok: false, reason: 'That code verified a different phone number than the one on this bill.' };
    }

    return { ok: true };
  }
}

/** The last 10 digits, country code and punctuation stripped — Indian
 *  numbers compare equal whether or not either side carries a `+91`. */
export function lastTenDigits(phone: string): string {
  return phone.replace(/\D/g, '').slice(-10);
}

export function lastTenDigitsMatch(a: string, b: string): boolean {
  const da = lastTenDigits(a);
  const db = lastTenDigits(b);
  return da.length === 10 && da === db;
}

/** `{type: 'error' | 'failure', ...}` is the shape MSG91's own widget
 *  callbacks use elsewhere; checked defensively since this endpoint's own
 *  response shape was never confirmed against a real call. */
export function isFailureShape(body: unknown): boolean {
  if (!body || typeof body !== 'object') return false;
  const type = (body as Record<string, unknown>).type;
  return type === 'error' || type === 'failure';
}

/** Best-effort search for a phone number in MSG91's response — see this
 *  file's own doc on why this isn't a single confirmed field access. Tries
 *  every field name MSG91's docs/callbacks are known to use, one level of
 *  nesting deep under `message`/`data`. */
export function verifiedPhoneFrom(body: unknown): string | null {
  if (!body || typeof body !== 'object') return null;
  const obj = body as Record<string, unknown>;
  const candidates = [
    obj.mobile,
    obj.identifier,
    obj.phone,
    obj.msisdn,
    typeof obj.message === 'string' ? obj.message : undefined,
    ...flatFieldsOf(obj.message),
    ...flatFieldsOf(obj.data),
  ];
  for (const candidate of candidates) {
    if (typeof candidate === 'string' && /\d{10}/.test(candidate)) {
      return candidate;
    }
  }
  return null;
}

function flatFieldsOf(value: unknown): unknown[] {
  if (!value || typeof value !== 'object') return [];
  const obj = value as Record<string, unknown>;
  return [obj.mobile, obj.identifier, obj.phone, obj.msisdn];
}
