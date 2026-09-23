# Neon Postgres Customer Video Storage Design

## Goal

Store each uploaded customer-review video inside the existing Neon Postgres
database. Admins must be able to upload, replace, reorder, hide and delete
clips, while the member app, member web build and agent/investor app stream the
same active-video feed without Supabase or external object storage.

## Current behavior and migration boundary

`app.customer_review_video` currently stores metadata and a `video_url`. Older
rows point to bundled assets, YouTube or external HTTP URLs. No prior version
stored uploaded video bytes in Postgres.

Existing URLs remain readable until an admin replaces or deletes their rows.
New uploads are stored in Neon and use a backend media URL in `video_url`. The
public catalogue response remains unchanged, so current clients continue to
consume `videoUrl` without learning how the bytes are stored.

## Data model

Add `app.customer_review_video_media`:

```sql
CREATE TABLE app.customer_review_video_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_type text NOT NULL,
  byte_length bigint NOT NULL,
  sha256 text NOT NULL,
  data bytea NOT NULL DEFAULT ''::bytea,
  next_chunk integer NOT NULL DEFAULT 0,
  upload_complete boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  CHECK (content_type IN ('video/mp4', 'video/webm', 'video/quicktime')),
  CHECK (byte_length > 0),
  CHECK (next_chunk >= 0)
);
```

`data` contains the actual video bytes. `byte_length` and `sha256` describe the
complete client file. `next_chunk` makes ordered chunk writes idempotent.
`upload_complete` prevents partial media from being played or attached to a
published clip.

`app.customer_review_video.video_url` remains text. A completed Neon upload is
stored as `/v1/public/catalogue/review-video-media/<uuid>`. No foreign key is
added to legacy URL text. Ownership is derived only when the URL exactly
matches that backend path.

## Upload protocol

Large files must not pass through one serverless request. The admin splits a
file into 768 KiB binary chunks and sends each as base64 JSON. Base64 expands a
chunk to about 1 MiB, leaving room under common serverless request limits.

Only Admin and Super Admin may use these endpoints:

1. `POST /v1/staff/catalogue/review-video-media`
   - Input: `contentType`, `byteLength`, `sha256`.
   - Validates MIME type and `REVIEW_VIDEO_MAX_MB`.
   - Creates an incomplete media row and returns `id`, `nextChunk` and
     `chunkSizeBytes: 786432`.
2. `PUT /v1/staff/catalogue/review-video-media/:id/chunks/:index`
   - Input: `{ data: "<base64>" }`.
   - Locks the media row.
   - If `index === next_chunk`, decodes and appends the bytes, then increments
     `next_chunk`.
   - If `index < next_chunk`, treats the retry as successful without appending
     a duplicate.
   - If `index > next_chunk`, returns a conflict containing the expected index.
   - Refuses writes after completion or beyond declared `byte_length`.
3. `POST /v1/staff/catalogue/review-video-media/:id/complete`
   - Locks the row and verifies actual length and SHA-256 against the declared
     values.
   - Marks it complete and returns the permanent backend media URL.
   - A checksum mismatch leaves the media incomplete and returns an error.
4. `DELETE /v1/staff/catalogue/review-video-media/:id`
   - Deletes incomplete abandoned uploads, or complete media that is no longer
     referenced by a customer-video row.
   - Refuses deletion while a metadata row still references it.

Each chunk update uses one transaction with a row lock. A retry cannot
duplicate bytes, two concurrent chunks cannot reorder data, and a completed
upload cannot be mutated.

The admin computes SHA-256 with the browser Web Crypto API before starting.
Upload progress is based on accepted chunks. Within one open form, the media ID
and next index remain in memory so a network failure resumes instead of
restarting.

## Metadata save and replacement

The admin completes the media upload before creating or updating
`app.customer_review_video`. It then saves the returned backend media URL using
the existing metadata API.

For replacement, the metadata row switches to the new completed media URL in
one successful update. Only afterward does the backend delete the old Neon
media, and only if no other metadata row references it. A failed metadata save
leaves the old clip unchanged and triggers best-effort deletion of the new
unreferenced media.

Deleting a customer-video row deletes its referenced Neon media after the row
is removed. Legacy bundled, YouTube, Supabase or other HTTP URLs never produce a
Neon media ID and therefore never trigger byte deletion.

## Playback endpoint

`GET /v1/public/catalogue/review-video-media/:id` is public because customer
review clips are public marketing content. It serves only completed rows.

The endpoint supports:

- `HEAD`, returning content type, total length, cache headers and
  `Accept-Ranges: bytes` without reading `data`.
- Full `GET`, returning 200 and the video body when no range is requested.
- A single `Range: bytes=start-end`, returning 206 with `Content-Range`,
  `Content-Length`, `Content-Type` and `Accept-Ranges`.
- Open-ended and suffix ranges.
- 416 with `Content-Range: bytes */<length>` for invalid or unsatisfiable
  ranges.

Range bodies are selected in Postgres with `substring(data from <one-based>
for <length>)`. A single response is capped at 2 MiB. A full GET for a larger
file is streamed as sequential database slices with backpressure, so neither
the API nor Postgres driver must duplicate the full video in memory.

Responses use `Cache-Control: public, max-age=31536000, immutable`. Uploaded
media IDs never change; replacement creates a new ID, making immutable caching
safe.

## Public catalogue and clients

The active customer-video feed keeps returning `videoUrl`, name, caption and
thumbnail. For Neon media, `videoUrl` is resolved against the configured
backend public base URL before it reaches clients, ensuring Flutter receives an
absolute HTTPS URL.

Both Flutter clients already accept non-YouTube HTTP(S) video URLs and use
`video_player`, which issues range requests where supported. The member web
build uses the same Flutter implementation. Client code changes are required
only if compatibility tests expose an assumption that URLs are always external
or absolute.

## Limits and cleanup

`REVIEW_VIDEO_MAX_MB` defaults to 50 and has a hard ceiling of 200. The API
checks declared size at creation and accumulated size on every chunk. The
completion checksum protects against truncation, corruption and false declared
lengths.

An authenticated staff cleanup endpoint removes incomplete media older than 24
hours. It returns the number removed and is safe to call repeatedly. The admin
also deletes its incomplete media when the form is cancelled after an upload
has started. Database operations never delete completed referenced media.

Postgres storage and restore history grow with every upload and replacement.
Operations documentation must explain how to monitor Neon logical size, remove
unused clips and lower the video limit if needed.

## Error handling

- Invalid type, size, chunk encoding or checksum: HTTP 400 with a clear form
  message.
- Missing or unauthorized staff session: HTTP 401/403.
- Out-of-order chunk: HTTP 409 with the expected chunk index so the client can
  resume.
- Missing or incomplete media during playback: HTTP 404.
- Invalid range: HTTP 416.
- Database connectivity failure: safe HTTP 503/500 response without database
  URLs, SQL text, binary data or secrets.

The form retains its selected file, metadata, generated thumbnail and progress
state after a recoverable failure. Retrying continues from the server-confirmed
next chunk.

## Security

Only authenticated Admin and Super Admin staff can create, append, complete or
delete media. Public users can only read completed media by unguessable UUID.
Every mutation validates UUID, numeric indices, MIME type, declared size,
decoded chunk size and final checksum.

Logs contain media ID, chunk index, status and byte counts only. They never
contain base64 bodies, raw video bytes, database URLs, staff tokens or member
data.

## Rollout and rollback

1. Apply the new database migration.
2. Deploy the backend with chunk upload and range playback endpoints.
3. Deploy the admin console using those endpoints.
4. Upload a short non-sensitive MP4 and verify seeking in admin, member web,
   member APK and agent/investor app.
5. Replace and delete the test clip, confirming unreferenced media removal.
6. Remove unused Supabase customer-video environment values after verification.

Rollback keeps the migration and stored media table intact. Restore the prior
backend/admin deployment; existing Neon media URLs will not play on the old
backend, so rollback must occur before production clips are switched, or the
new playback route must remain deployed. No migration down script deletes video
bytes automatically.

## Testing

Database and backend tests cover ordered append, duplicate retry, skipped
index, oversize prevention, final length/checksum validation, incomplete-media
404, full playback, HEAD, normal/open/suffix ranges, invalid ranges, reference
protected deletion and stale incomplete cleanup.

Admin tests cover chunk splitting, SHA-256 encoding, progress, retry from
`nextChunk`, completion, cancel cleanup, replacement ordering and preservation
of form state after failure.

Existing customer-video tests in both Flutter trees must pass. Add an HTTP
video compatibility test only if an existing repository or player abstraction
can exercise absolute backend media URLs meaningfully without mirroring the
implementation.

Required release verification includes backend tests/typecheck/build, admin
tests/typecheck/build, both focused Flutter customer-video suites, one real
upload, seeking in all clients, replacement and deletion.
