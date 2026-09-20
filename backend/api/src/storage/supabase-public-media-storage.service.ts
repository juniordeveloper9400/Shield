import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from '../config/env';
import type { PublicMediaStorage, PublicMediaUpload } from './public-media-storage';

/** Supabase signed upload links are valid for two hours; not configurable. */
const SIGNED_UPLOAD_TTL_SECONDS = 2 * 60 * 60;
const REQUEST_TIMEOUT_MS = 10_000;

/**
 * {@link PublicMediaStorage} on Supabase Storage.
 *
 * Talks to the Storage REST API with the project's service-role (or secret)
 * key, which bypasses row-level security — so that key must only ever exist on
 * this server. Admins never see it: it mints a single-use signed upload link
 * per file, and that link is all the browser gets.
 *
 * The bucket must be **public** (objects are read by plain URL in the app) and
 * is used for nothing but these videos. Set its file-size limit and allowed
 * MIME types in Supabase too, as a second line of defence behind this API's
 * own checks.
 */
@Injectable()
export class SupabasePublicMediaStorage implements PublicMediaStorage {
  private readonly baseUrl: string;
  private readonly bucket: string;
  private readonly apiKey: string;

  constructor(config: ConfigService<Env, true>) {
    this.baseUrl = (config.get('SUPABASE_URL', { infer: true }) ?? '').replace(/\/+$/, '');
    this.apiKey = config.get('SUPABASE_SERVICE_ROLE_KEY', { infer: true }) ?? '';
    this.bucket = config.get('SUPABASE_PUBLIC_BUCKET', { infer: true }) ?? '';
  }

  isConfigured(): boolean {
    return Boolean(this.baseUrl && this.apiKey && this.bucket);
  }

  async createUpload({ key }: { key: string }): Promise<PublicMediaUpload> {
    const response = await this.request('POST', `/object/upload/sign/${this.bucket}/${encodeKey(key)}`, {
      // Never overwrite an existing object: every clip gets a fresh random key.
      headers: { 'x-upsert': 'false' },
      body: '{}',
    });
    const data = (await response.json().catch(() => null)) as { url?: unknown; token?: unknown } | null;

    let uploadUrl: string;
    if (typeof data?.url === 'string' && data.url) {
      uploadUrl = this.absolute(data.url);
    } else if (typeof data?.token === 'string' && data.token) {
      uploadUrl = `${this.baseUrl}/storage/v1/object/upload/sign/${this.bucket}/${encodeKey(key)}?token=${encodeURIComponent(data.token)}`;
    } else {
      throw new Error('Supabase Storage did not return an upload link.');
    }

    return {
      uploadUrl,
      publicUrl: this.publicUrl(key),
      method: 'PUT',
      headers: { 'x-upsert': 'false' },
      // Videos are immutable once uploaded (a replacement gets a new key), so
      // let the CDN and every device cache them for a year.
      fields: { cacheControl: '31536000' },
      expiresInSeconds: SIGNED_UPLOAD_TTL_SECONDS,
    };
  }

  keyFromPublicUrl(url: string): string | null {
    const prefix = `${this.baseUrl}/storage/v1/object/public/${this.bucket}/`;
    if (!this.baseUrl || !this.bucket || !url.startsWith(prefix)) return null;
    const rest = url.slice(prefix.length).split(/[?#]/)[0];
    let key: string;
    try {
      key = decodeURIComponent(rest);
    } catch {
      return null;
    }
    return key && !key.split('/').includes('..') ? key : null;
  }

  async delete(key: string): Promise<void> {
    await this.request('DELETE', `/object/${this.bucket}`, {
      body: JSON.stringify({ prefixes: [key] }),
    });
  }

  private publicUrl(key: string): string {
    return `${this.baseUrl}/storage/v1/object/public/${this.bucket}/${encodeKey(key)}`;
  }

  /** Supabase returns the signed link relative to `/storage/v1` (older builds, already prefixed). */
  private absolute(url: string): string {
    if (/^https?:\/\//i.test(url)) return url;
    return url.startsWith('/storage/v1') ? `${this.baseUrl}${url}` : `${this.baseUrl}/storage/v1${url}`;
  }

  private async request(
    method: 'POST' | 'DELETE',
    path: string,
    init: { headers?: Record<string, string>; body?: string },
  ): Promise<Response> {
    let response: Response;
    try {
      response = await fetch(`${this.baseUrl}/storage/v1${path}`, {
        method,
        headers: {
          apikey: this.apiKey,
          // Legacy service_role keys are JWTs and are also sent as the bearer
          // token; the newer sb_secret_… keys are not JWTs and go in apikey only.
          ...(this.apiKey.startsWith('eyJ') ? { Authorization: `Bearer ${this.apiKey}` } : {}),
          'Content-Type': 'application/json',
          ...init.headers,
        },
        body: init.body,
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });
    } catch {
      throw new Error('Could not reach Supabase Storage. Check SUPABASE_URL and the server’s connection.');
    }
    if (response.ok) return response;
    throw new Error(await describeFailure(response, this.bucket));
  }
}

/** Each path segment percent-encoded, the slashes between them kept. */
function encodeKey(key: string): string {
  return key.split('/').map(encodeURIComponent).join('/');
}

async function describeFailure(response: Response, bucket: string): Promise<string> {
  const body = (await response.json().catch(() => null)) as { message?: unknown; error?: unknown } | null;
  const detail = String(body?.message ?? body?.error ?? response.statusText ?? '').trim();
  if (response.status === 401 || response.status === 403) {
    return 'Supabase rejected the service key. Check SUPABASE_SERVICE_ROLE_KEY belongs to this project.';
  }
  if (response.status === 404) {
    return `Supabase can't find the storage bucket “${bucket}”. Create it (public) or fix SUPABASE_PUBLIC_BUCKET.`;
  }
  return `Supabase Storage responded ${response.status}${detail ? `: ${detail}` : ''}.`;
}
