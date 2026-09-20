import { ConfigService } from '@nestjs/config';
import { SupabasePublicMediaStorage } from '../../src/storage/supabase-public-media-storage.service';

const PROJECT = 'https://abcdefgh.supabase.co';
const LEGACY_KEY = 'eyJhbGciOiJIUzI1NiJ9.service-role-payload.signature';
const SECRET_KEY = 'sb_secret_abcdef0123456789';

function storage(overrides: Record<string, string | undefined> = {}) {
  const values: Record<string, string | undefined> = {
    SUPABASE_URL: `${PROJECT}/`,
    SUPABASE_SERVICE_ROLE_KEY: LEGACY_KEY,
    SUPABASE_PUBLIC_BUCKET: 'customer-reviews',
    ...overrides,
  };
  return new SupabasePublicMediaStorage({ get: (key: string) => values[key] } as unknown as ConfigService<never, true>);
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

describe('SupabasePublicMediaStorage', () => {
  let fetchMock: jest.SpyInstance;

  beforeEach(() => {
    fetchMock = jest.spyOn(global, 'fetch');
  });
  afterEach(() => {
    fetchMock.mockRestore();
  });

  const lastCall = () => {
    const [url, init] = fetchMock.mock.calls.at(-1) as [string, RequestInit & { headers: Record<string, string> }];
    return { url, init };
  };

  it('is only configured once the project URL, the key and a bucket are all set', () => {
    expect(storage().isConfigured()).toBe(true);
    expect(storage({ SUPABASE_URL: undefined }).isConfigured()).toBe(false);
    expect(storage({ SUPABASE_SERVICE_ROLE_KEY: undefined }).isConfigured()).toBe(false);
    expect(storage({ SUPABASE_PUBLIC_BUCKET: '' }).isConfigured()).toBe(false);
  });

  describe('createUpload', () => {
    it('asks Supabase for a signed upload link and returns it with the permanent public URL', async () => {
      fetchMock.mockResolvedValue(
        json({ url: '/object/upload/sign/customer-reviews/review-videos/abc.mp4?token=tok123', token: 'tok123' }),
      );

      const upload = await storage().createUpload({ key: 'review-videos/abc.mp4' });

      const { url, init } = lastCall();
      expect(url).toBe(`${PROJECT}/storage/v1/object/upload/sign/customer-reviews/review-videos/abc.mp4`);
      expect(init.method).toBe('POST');
      expect(init.headers['x-upsert']).toBe('false'); // never overwrite an existing clip
      expect(upload.uploadUrl).toBe(
        `${PROJECT}/storage/v1/object/upload/sign/customer-reviews/review-videos/abc.mp4?token=tok123`,
      );
      expect(upload.publicUrl).toBe(`${PROJECT}/storage/v1/object/public/customer-reviews/review-videos/abc.mp4`);
      expect(upload.method).toBe('PUT');
      expect(upload.headers).toEqual({ 'x-upsert': 'false' });
      expect(upload.fields).toEqual({ cacheControl: '31536000' });
      expect(upload.expiresInSeconds).toBe(7200);
    });

    it('builds the link from the token when Supabase only returns that, and tolerates an already-prefixed path', async () => {
      fetchMock.mockResolvedValueOnce(json({ token: 'tok 1' }));
      const fromToken = await storage().createUpload({ key: 'review-videos/a.mp4' });
      expect(fromToken.uploadUrl).toBe(
        `${PROJECT}/storage/v1/object/upload/sign/customer-reviews/review-videos/a.mp4?token=tok%201`,
      );

      fetchMock.mockResolvedValueOnce(
        json({ url: '/storage/v1/object/upload/sign/customer-reviews/review-videos/b.mp4?token=t' }),
      );
      const prefixed = await storage().createUpload({ key: 'review-videos/b.mp4' });
      expect(prefixed.uploadUrl).toBe(
        `${PROJECT}/storage/v1/object/upload/sign/customer-reviews/review-videos/b.mp4?token=t`,
      );
    });

    it('sends a legacy service_role key as both apikey and bearer, but a new sb_secret key as apikey only', async () => {
      // A fresh Response per call — a body can only be read once.
      fetchMock.mockImplementation(() => Promise.resolve(json({ token: 't' })));

      await storage().createUpload({ key: 'review-videos/a.mp4' });
      expect(lastCall().init.headers).toMatchObject({ apikey: LEGACY_KEY, Authorization: `Bearer ${LEGACY_KEY}` });

      await storage({ SUPABASE_SERVICE_ROLE_KEY: SECRET_KEY }).createUpload({ key: 'review-videos/a.mp4' });
      expect(lastCall().init.headers.apikey).toBe(SECRET_KEY);
      expect(lastCall().init.headers.Authorization).toBeUndefined();
    });

    it('percent-encodes the key in the URLs it builds', async () => {
      fetchMock.mockResolvedValue(json({ token: 't' }));
      const upload = await storage().createUpload({ key: 'review-videos/a b.mp4' });
      expect(lastCall().url).toContain('review-videos/a%20b.mp4');
      expect(upload.publicUrl).toBe(`${PROJECT}/storage/v1/object/public/customer-reviews/review-videos/a%20b.mp4`);
    });

    it('turns Supabase failures into messages an admin can act on', async () => {
      const failures: [number, unknown, RegExp][] = [
        [401, { message: 'Invalid JWT' }, /rejected the service key/],
        [403, { message: 'nope' }, /rejected the service key/],
        [404, { message: 'Bucket not found' }, /can't find the storage bucket “customer-reviews”/],
        [500, { message: 'boom' }, /responded 500: boom/],
      ];
      for (const [status, body, message] of failures) {
        fetchMock.mockResolvedValueOnce(json(body, status));
        await expect(storage().createUpload({ key: 'review-videos/a.mp4' })).rejects.toThrow(message);
      }
    });

    it('says so when Supabase cannot be reached, and when it returns no link', async () => {
      fetchMock.mockRejectedValueOnce(new TypeError('fetch failed'));
      await expect(storage().createUpload({ key: 'review-videos/a.mp4' })).rejects.toThrow(/Could not reach Supabase/);

      fetchMock.mockResolvedValueOnce(json({}));
      await expect(storage().createUpload({ key: 'review-videos/a.mp4' })).rejects.toThrow(/did not return an upload link/);
    });
  });

  describe('keyFromPublicUrl', () => {
    const publicPrefix = `${PROJECT}/storage/v1/object/public/customer-reviews`;

    it('maps only this bucket’s public URLs back to a key', () => {
      const s = storage();
      expect(s.keyFromPublicUrl(`${publicPrefix}/review-videos/abc.mp4`)).toBe('review-videos/abc.mp4');
      expect(s.keyFromPublicUrl(`${publicPrefix}/review-videos/abc.mp4?download=1#t=2`)).toBe('review-videos/abc.mp4');
      expect(s.keyFromPublicUrl(`${publicPrefix}/review-videos/a%20b.mp4`)).toBe('review-videos/a b.mp4');
    });

    it('ignores anything else — another bucket, project or host, YouTube, a bundled path', () => {
      const s = storage();
      for (const url of [
        `${PROJECT}/storage/v1/object/public/other-bucket/review-videos/abc.mp4`,
        `https://other.supabase.co/storage/v1/object/public/customer-reviews/review-videos/abc.mp4`,
        `${PROJECT}.evil.com/storage/v1/object/public/customer-reviews/review-videos/abc.mp4`,
        `${PROJECT}/storage/v1/object/sign/customer-reviews/review-videos/abc.mp4`,
        'https://www.youtube.com/shorts/dvLRFi4zBWk',
        'assets/reviews/tirur_store.mp4',
        '',
      ]) {
        expect(s.keyFromPublicUrl(url)).toBeNull();
      }
    });

    it('refuses a path that climbs out of the prefix', () => {
      const s = storage();
      expect(s.keyFromPublicUrl(`${publicPrefix}/review-videos/../secret.txt`)).toBeNull();
      expect(s.keyFromPublicUrl(`${publicPrefix}/review-videos/%2e%2e/secret.txt`)).toBeNull();
    });

    it('matches nothing while unconfigured', () => {
      expect(storage({ SUPABASE_URL: undefined }).keyFromPublicUrl(`${publicPrefix}/review-videos/abc.mp4`)).toBeNull();
    });
  });

  describe('delete', () => {
    it('removes the object by key with a DELETE on the bucket', async () => {
      fetchMock.mockResolvedValue(json([{ name: 'review-videos/abc.mp4' }]));
      await storage().delete('review-videos/abc.mp4');

      const { url, init } = lastCall();
      expect(url).toBe(`${PROJECT}/storage/v1/object/customer-reviews`);
      expect(init.method).toBe('DELETE');
      expect(JSON.parse(String(init.body))).toEqual({ prefixes: ['review-videos/abc.mp4'] });
    });

    it('throws when Supabase refuses, so the caller can log it', async () => {
      fetchMock.mockResolvedValue(json({ message: 'boom' }, 500));
      await expect(storage().delete('review-videos/abc.mp4')).rejects.toThrow(/responded 500/);
    });
  });
});
