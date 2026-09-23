# Neon Customer Video Storage Design

## Goal

Store uploaded customer-review videos in Neon Object Storage and keep their
catalogue metadata in the existing Neon Postgres table. Remove the customer
video feature's dependency on Supabase Storage. Admins must be able to upload,
replace, reorder, hide and delete clips, and the member app, member web build
and agent/investor app must continue to display the same active-video feed.

## Scope

This change covers the customer-video upload and playback path only. It does
not move prescription images or other files. Existing video metadata rows stay
valid. Existing HTTP video URLs remain readable until an admin replaces or
deletes those clips.

## Storage architecture

The Neon project will have a `customer-reviews` Object Storage bucket with
`public_read` access. The bucket is declared in a root `neon.ts` configuration
and provisioned against the linked Neon project with `neon deploy`.

Neon Object Storage exposes an S3-compatible endpoint and credentials. The
backend receives those values through server-only environment variables. The
admin browser never receives a storage access key or secret. The backend uses
the AWS S3 client already installed in `backend/api` to mint a short-lived
presigned `PUT` URL for one random object key under `review-videos/`.

The browser uploads directly to Object Storage. This avoids Vercel function
request-body limits and avoids routing large video bodies through Postgres or
the API. Once the upload succeeds, the admin saves the stable public object URL
in `app.customer_review_video.video_url`, alongside the existing name, caption,
thumbnail, active flag and sort order.

The public bucket is dedicated to customer-review videos. No private member or
medical files may be written to it.

## Configuration

The backend will use storage-neutral variables:

- `PUBLIC_MEDIA_ENDPOINT`: Neon Object Storage's S3-compatible endpoint.
- `PUBLIC_MEDIA_REGION`: endpoint region, defaulting to `auto` when Neon does
  not require a specific AWS region value.
- `PUBLIC_MEDIA_BUCKET`: defaults to `customer-reviews`.
- `PUBLIC_MEDIA_ACCESS_KEY`: server-only Neon storage access key.
- `PUBLIC_MEDIA_SECRET_KEY`: server-only Neon storage secret.
- `PUBLIC_MEDIA_PUBLIC_BASE_URL`: the public-read base URL for the bucket.
- `REVIEW_VIDEO_MAX_MB`: application-side upload limit, default 50 and hard
  ceiling 200.

The deployment setup will map Neon CLI-injected S3-compatible credentials to
these variables in the backend environment. Secrets remain in local ignored
environment files and the deployment provider. Supabase variables will no
longer control this feature.

The storage service is considered configured only when endpoint, bucket,
access key, secret key and public base URL are all non-empty. An incomplete
configuration returns a clear `STORAGE_NOT_CONFIGURED` response without
exposing which secret is missing.

## Upload flow

1. An Admin or Super Admin chooses an MP4, WebM or MOV file on Customer Videos.
2. The console checks the extension/MIME type and the configured maximum size.
3. It requests an upload ticket from
   `POST /v1/staff/catalogue/review-videos/upload-url` using its staff token.
4. The backend repeats validation and creates a random key such as
   `review-videos/<uuid>.mp4`.
5. The backend returns a short-lived presigned `PUT` URL, the permanent public
   URL, required request headers and expiry.
6. The console uploads the bytes directly to Neon Object Storage and displays
   progress.
7. The console creates or updates the Postgres metadata row with the public
   URL and generated or selected thumbnail.
8. If metadata saving fails after upload, the console asks the backend to
   delete the orphaned object on a best-effort basis.

Uploads use a new random key rather than overwriting. This keeps CDN caching
safe and makes replacement atomic from the viewer's perspective.

## Playback and public feed

The existing public catalogue response remains unchanged: it returns the
stored `videoUrl` and thumbnail. Both Flutter trees continue accepting normal
HTTPS non-YouTube URLs, so no client contract or database migration is needed.

The bucket's `public_read` setting permits direct playback and byte-range
requests from mobile and web video players. The permanent URL must therefore
point directly at the public Neon object, not at the Vercel API.

The existing active-feed cache is invalidated after create, update, reorder,
visibility change or delete, preserving the current refresh behavior.

## Replacement and deletion

When a clip is replaced, the new upload and metadata update complete before
the old object is removed. If deleting the old object fails, the saved clip
still points to the new working object and the backend logs the cleanup error.

Deleting a metadata row first verifies that its URL belongs to the configured
public base URL and resolves to a key under `review-videos/`. The backend never
deletes an arbitrary URL or an object outside that prefix. Legacy Supabase,
YouTube and bundled-asset URLs are ignored by object cleanup.

## Error handling

- Missing Neon storage configuration: return HTTP 503 with an actionable
  storage-setup message.
- Invalid type or excessive size: return HTTP 400 before issuing an upload URL.
- Neon credential, bucket or connectivity failure: return HTTP 502 with a safe
  operational message and log the detailed server error.
- Direct browser upload failure: retain the form and selected file so the admin
  can retry.
- Metadata-save failure after upload: attempt object cleanup and retain a clear
  form error.

No response or log may contain an access key, secret key, signed query string,
database URL or other credential.

## Migration and rollout

No Postgres schema migration is required because `video_url` already stores an
HTTPS URL. Existing rows remain untouched.

Rollout order:

1. Link the repository to the intended Neon project.
2. Provision the `customer-reviews` public-read bucket with `neon deploy`.
3. Put the generated storage credentials and public base URL into the backend
   deployment environment.
4. Deploy the backend containing the Neon storage provider.
5. Deploy the admin console if its error copy or upload contract changed.
6. Upload a short real clip, play it in the admin preview and verify it in both
   Flutter clients.
7. Remove obsolete Supabase environment values after successful verification.

The backend change remains deployable before the bucket is configured: video
listing continues working, while new uploads fail closed with the setup error.

## Testing

Backend unit tests will cover configuration detection, presigned upload output,
public URL/key conversion, path encoding, deletion prefix protection and safe
mapping of S3 failures. Integration tests will cover staff authorization, MIME
and size validation, configured and unconfigured upload routes, and deletion.

Admin tests will cover the upload-ticket contract and actionable error text.
The admin type check and production build must pass. Existing customer-video
tests in the root member app and `shield agent_invester/` must pass to prove
that the unchanged public feed remains compatible.

After provisioning, one real upload and playback check is required because
mocked S3 tests cannot verify the live Neon endpoint, bucket access mode, CORS
or public URL shape.

## Security and operational limits

Only Admin and Super Admin staff can mint upload URLs or delete media. Signed
upload URLs expire quickly and target one random key. The backend validates
file type and size before signing, and the bucket must enforce matching limits
where Neon exposes those controls.

Public review videos are intentionally public. Names, captions and thumbnails
must not contain confidential medical information. Storage use and egress
should be monitored in Neon; the current Neon Free plan includes 5 GB of Object
Storage per project, subject to Neon's current plan terms.
