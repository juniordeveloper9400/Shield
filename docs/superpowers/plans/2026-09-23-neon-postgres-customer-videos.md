# Neon Postgres Customer Videos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store customer-review video bytes in Neon Postgres and provide resumable admin uploads plus HTTP range playback to all clients.

**Architecture:** A new `app.customer_review_video_media` table holds incomplete and completed `bytea` uploads. Authenticated staff endpoints append validated 768 KiB chunks and finalize by size/checksum; a public controller serves completed media with range semantics while the existing catalogue continues returning `videoUrl`.

**Tech Stack:** Neon/Postgres, Drizzle ORM and SQL, NestJS/Express, React/TypeScript/Vite, Web Crypto, Flutter `video_player`, Jest and Node test runner.

**Spec:** `docs/superpowers/specs/2026-09-23-neon-customer-video-storage-design.md`

## Global Constraints

- Store the actual video bytes in Neon Postgres; do not use Supabase or object storage.
- Accept only MP4, WebM and MOV, default to 50 MB and cap configuration at 200 MB.
- Upload in ordered 786432-byte chunks with duplicate retry protection.
- Only Admin and Super Admin may mutate media; public users may read completed media only.
- Preserve the existing customer-review catalogue response shape.
- Never log or return video bodies, base64 chunks, database URLs, staff tokens or SQL text.
- Preserve legacy video URLs and ignore them during Neon-media cleanup.
- Preserve unrelated worktree changes.

## Review Focus

- Duplicate chunk retries must not append data twice; Task 2 exercises this.
- Invalid, skipped, oversized and post-completion chunks must leave stored bytes unchanged; Task 2 exercises each case.
- Normal, open-ended, suffix and unsatisfiable byte ranges must produce correct headers and bytes; Task 3 exercises each case.
- Replacement must switch metadata before deleting old media, and failed metadata saves must remove only the new orphan; Task 4 exercises ordering.
- Incomplete or referenced media must never be exposed or deleted incorrectly; Tasks 2 and 3 exercise both protections.

---

### Task 1: Database schema and migration

**Files:**
- Create: `backend/db/migrations/0061_customer_review_video_media.sql`
- Modify: `backend/db/app_schema.sql`
- Modify: `backend/db/APP_SCHEMA.md`
- Modify: `backend/api/src/db/schema/app-catalogue.ts`
- Modify: `backend/api/test/integration/create-test-db.ts`

**Interfaces:**
- Produces: `customerReviewVideoMedia` with `id`, `contentType`, `byteLength`, `sha256`, `data`, `nextChunk`, `uploadComplete`, `createdAt`, `completedAt`.
- Consumed by: Task 2 upload service and Task 3 playback service.

- [ ] **Step 1: Write a failing schema contract test**

Add `backend/api/test/unit/customer-review-video-media-schema.spec.ts` that imports the Drizzle table and asserts its SQL column names through `getTableColumns`:

```ts
expect(Object.keys(getTableColumns(customerReviewVideoMedia))).toEqual([
  'id', 'contentType', 'byteLength', 'sha256', 'data', 'nextChunk',
  'uploadComplete', 'createdAt', 'completedAt',
]);
```

- [ ] **Step 2: Verify RED**

Run `npm test -- --runInBand test/unit/customer-review-video-media-schema.spec.ts` from `backend/api`.

Expected: FAIL because `customerReviewVideoMedia` is not exported.

- [ ] **Step 3: Add schema and migration**

Implement the exact table from the approved spec. In Drizzle, use `uuid`,
`text`, `bigint({ mode: 'number' })`, `customType<{ data: Buffer }>` for
`bytea`, `integer`, `boolean` and `timestamp({ withTimezone: true })`. Add MIME,
positive-length and nonnegative-index checks. Mirror it in the integration test
database and schema snapshot.

- [ ] **Step 4: Verify GREEN**

Run:

```powershell
npm test -- --runInBand test/unit/customer-review-video-media-schema.spec.ts
npm run typecheck
```

Expected: PASS and no TypeScript errors.

- [ ] **Step 5: Commit**

```powershell
git add backend/db/migrations/0061_customer_review_video_media.sql backend/db/app_schema.sql backend/db/APP_SCHEMA.md backend/api/src/db/schema/app-catalogue.ts backend/api/test/integration/create-test-db.ts backend/api/test/unit/customer-review-video-media-schema.spec.ts
git commit -m "db: add customer review video media"
```

### Task 2: Chunk upload lifecycle

**Files:**
- Create: `backend/api/src/modules/catalogue/review-video-media.service.ts`
- Create: `backend/api/test/unit/review-video-media.service.spec.ts`
- Modify: `backend/api/src/modules/catalogue/dto.ts`
- Modify: `backend/api/src/modules/catalogue/catalogue.module.ts`
- Modify: `backend/api/src/modules/catalogue/catalogue-admin.controller.ts`
- Modify: `backend/api/src/config/env.ts`

**Interfaces:**
- Consumes: `customerReviewVideoMedia` from Task 1 and `DATABASE_URL` through the existing database provider.
- Produces: `createUpload`, `appendChunk`, `completeUpload`, `deleteUnreferenced`, `cleanupIncomplete` service methods and staff routes from the spec.

- [ ] **Step 1: Write failing service tests**

Test with the integration database or a transaction-capable repository seam:

```ts
const upload = await service.createUpload({
  contentType: 'video/mp4', byteLength: bytes.length, sha256: digest(bytes),
});
await service.appendChunk(upload.id, 0, bytes.subarray(0, 3).toString('base64'));
await service.appendChunk(upload.id, 0, bytes.subarray(0, 3).toString('base64'));
expect((await service.status(upload.id)).storedBytes).toBe(3);
expect((await service.status(upload.id)).nextChunk).toBe(1);
```

Add separate tests for skipped index (409 + expected index), malformed base64,
chunk larger than 786432 bytes, accumulated bytes over declaration, append
after completion, wrong final length, wrong SHA-256, successful completion,
referenced-media deletion refusal and stale incomplete cleanup.

- [ ] **Step 2: Verify RED**

Run `npm test -- --runInBand test/unit/review-video-media.service.spec.ts`.

Expected: FAIL because the service does not exist.

- [ ] **Step 3: Implement DTO validation and service**

Add Zod schemas:

```ts
createReviewVideoMediaSchema = z.object({
  contentType: z.enum(['video/mp4', 'video/webm', 'video/quicktime']),
  byteLength: z.number().int().positive(),
  sha256: z.string().regex(/^[a-f0-9]{64}$/),
});
reviewVideoChunkSchema = z.object({ data: z.string().min(1) });
```

Use a database transaction and `SELECT ... FOR UPDATE` for append/finalize.
Strictly validate base64 by re-encoding decoded bytes without padding before
accepting it. Append with `data = data || ${chunk}` only at `next_chunk`; return
current state for an earlier retry. Hash final bytes by reading fixed-size
database slices through Node `createHash('sha256')`, avoiding both an optional
database extension and loading the full file into Node memory.

- [ ] **Step 4: Add staff routes**

Add create, status, chunk PUT, complete, delete and stale-cleanup endpoints to
`CatalogueAdminController`. Validate UUIDs and nonnegative integer indices.
Return the media URL as `/v1/public/catalogue/review-video-media/<id>`.

- [ ] **Step 5: Verify GREEN**

Run:

```powershell
npm test -- --runInBand test/unit/review-video-media.service.spec.ts
npm run typecheck
npm run build
```

Expected: all pass.

- [ ] **Step 6: Commit**

```powershell
git add backend/api/src/modules/catalogue/review-video-media.service.ts backend/api/test/unit/review-video-media.service.spec.ts backend/api/src/modules/catalogue/dto.ts backend/api/src/modules/catalogue/catalogue.module.ts backend/api/src/modules/catalogue/catalogue-admin.controller.ts backend/api/src/config/env.ts
git commit -m "feat: add chunked Neon video uploads"
```

### Task 3: Public HTTP range playback and cleanup integration

**Files:**
- Create: `backend/api/src/modules/catalogue/review-video-range.ts`
- Create: `backend/api/test/unit/review-video-range.spec.ts`
- Modify: `backend/api/src/modules/catalogue/catalogue-public.controller.ts`
- Modify: `backend/api/src/modules/catalogue/review-video-media.service.ts`
- Modify: `backend/api/src/modules/catalogue/catalogue.service.ts`
- Modify: `backend/api/test/integration/review-video-upload.e2e-spec.ts`
- Delete: `backend/api/src/storage/supabase-public-media-storage.service.ts`
- Delete: `backend/api/test/unit/supabase-public-media-storage.spec.ts`

**Interfaces:**
- Consumes: completed media rows and slices from Task 2.
- Produces: `parseVideoRange(range, totalLength, cap)` and public GET/HEAD media endpoint.

- [ ] **Step 1: Write failing pure range tests**

Cover:

```ts
expect(parseVideoRange(undefined, 10, 2_097_152)).toEqual({ kind: 'full', start: 0, end: 9 });
expect(parseVideoRange('bytes=2-5', 10, cap)).toEqual({ kind: 'partial', start: 2, end: 5 });
expect(parseVideoRange('bytes=7-', 10, cap)).toEqual({ kind: 'partial', start: 7, end: 9 });
expect(parseVideoRange('bytes=-3', 10, cap)).toEqual({ kind: 'partial', start: 7, end: 9 });
expect(parseVideoRange('bytes=20-30', 10, cap)).toEqual({ kind: 'unsatisfiable' });
```

Also reject multiple ranges and cap an oversized requested range at 2 MiB.

- [ ] **Step 2: Verify RED**

Run `npm test -- --runInBand test/unit/review-video-range.spec.ts`.

Expected: FAIL because the parser does not exist.

- [ ] **Step 3: Implement parser and playback controller**

Use Express `Request`/`Response` with `@Res()` to set exact headers. Query
metadata without `data`, then use `substring(data from $start for $length)`.
HEAD sends no body. Partial GET returns 206. Invalid ranges return 416. Full
files up to 2 MiB return in one slice; larger full requests loop over 2 MiB
slices and honor `res.write()` backpressure before `res.end()`.

- [ ] **Step 4: Integrate metadata cleanup and absolute URLs**

Remove `PUBLIC_MEDIA_STORAGE` from the catalogue service. Parse only exact
backend media paths. On metadata update/delete, delete the old media only after
the metadata mutation and only when no remaining row references the same path.
Resolve relative Neon media paths against `PUBLIC_API_BASE_URL` in public feed
responses; leave legacy absolute URLs unchanged.

- [ ] **Step 5: Add route integration tests**

Exercise incomplete 404, HEAD, full GET, normal/open/suffix range, 416,
Admin-only upload mutations, safe replacement and referenced delete refusal.
Assert binary response bytes and every range header.

- [ ] **Step 6: Verify GREEN**

Run:

```powershell
npm test -- --runInBand test/unit/review-video-range.spec.ts test/integration/review-video-upload.e2e-spec.ts
npm run typecheck
npm run build
```

Expected: all pass.

- [ ] **Step 7: Commit**

```powershell
git add backend/api/src/modules/catalogue/review-video-range.ts backend/api/test/unit/review-video-range.spec.ts backend/api/src/modules/catalogue/catalogue-public.controller.ts backend/api/src/modules/catalogue/review-video-media.service.ts backend/api/src/modules/catalogue/catalogue.service.ts backend/api/test/integration/review-video-upload.e2e-spec.ts backend/api/src/storage/supabase-public-media-storage.service.ts backend/api/test/unit/supabase-public-media-storage.spec.ts
git commit -m "feat: stream customer videos from Neon"
```

### Task 4: Admin chunk uploader

**Files:**
- Create: `shieldweb/src/lib/reviewVideoUpload.ts`
- Create: `shieldweb/tests/reviewVideoUpload.test.mjs`
- Modify: `shieldweb/src/api/customerReviewVideos.ts`
- Modify: `shieldweb/src/pages/CustomerVideosPage.tsx`
- Modify: `shieldweb/package.json`

**Interfaces:**
- Consumes: Task 2 create/status/chunk/complete/delete endpoints.
- Produces: `uploadReviewVideo(file, token, onProgress)` returning `{ mediaId, publicUrl }` and `discardReviewVideoMedia(mediaId, token)`.

- [ ] **Step 1: Write failing uploader tests**

Use a fake API transport and real `Blob`/`File` data to verify 786432-byte
splitting, lowercase SHA-256, ordered indices, retry from server `nextChunk`,
monotonic progress, complete-after-last-chunk, cancel cleanup and preservation
of the original save error when cleanup fails.

- [ ] **Step 2: Verify RED**

Run `npm run test:review-video-upload`.

Expected: FAIL because the script/module does not exist.

- [ ] **Step 3: Implement uploader and API calls**

Use `crypto.subtle.digest('SHA-256', await file.arrayBuffer())`. Convert each
slice to base64 without spreading the entire file into function arguments.
When a 409 includes `expectedIndex`, continue there. Surface all other API
errors through the existing `ApiError` path.

- [ ] **Step 4: Replace form upload flow**

Remove signed-upload/Supabase calls. Keep `File`, preview URL, generated poster
and fields on recoverable failure. Save metadata only after completion. On
failed metadata save, delete only the new media. On successful replacement,
allow the backend metadata update to clean the old media. Cancel deletes an
incomplete media ID before closing.

- [ ] **Step 5: Verify GREEN**

Run:

```powershell
npm run test:review-video-upload
npm run test:review-video
npm run typecheck
npm run build
```

Expected: all pass.

- [ ] **Step 6: Commit**

```powershell
git -C shieldweb add src/lib/reviewVideoUpload.ts tests/reviewVideoUpload.test.mjs src/api/customerReviewVideos.ts src/pages/CustomerVideosPage.tsx package.json
git -C shieldweb commit -m "feat: upload customer videos to Neon"
```

### Task 5: Documentation, migration and full verification

**Files:**
- Modify: `docs/admin-console.md`
- Modify: `docs/deployment.md`
- Modify: `docs/database.md`
- Modify: `backend/docs/tech-stack.md`

**Interfaces:**
- Consumes: completed backend/admin flow.
- Produces: deployment instructions and verified live behavior.

- [ ] **Step 1: Update operational documentation**

Document chunking, Neon storage growth, playback route, `PUBLIC_API_BASE_URL`,
the 50 MB default, stale-upload cleanup, rollout order and rollback limitation.
Remove active Supabase setup instructions while retaining accurate historical
notes only where necessary.

- [ ] **Step 2: Run focused automated verification**

Backend:

```powershell
Set-Location backend/api
npm test -- --runInBand test/unit/customer-review-video-media-schema.spec.ts test/unit/review-video-media.service.spec.ts test/unit/review-video-range.spec.ts test/integration/review-video-upload.e2e-spec.ts
npm run typecheck
npm run build
```

Admin:

```powershell
Set-Location shieldweb
npm run test:review-video-upload
npm run test:review-video
npm run typecheck
npm run build
```

Flutter clients:

```powershell
C:\src\flutter\bin\flutter.bat test test\customer_reviews_refresh_test.dart test\customer_reviews_test.dart test\backend_customer_review_repository_test.dart -j 2
Set-Location 'shield agent_invester'
C:\src\flutter\bin\flutter.bat test test\customer_reviews_refresh_test.dart test\customer_reviews_test.dart -j 2
```

Expected: every command exits 0.

- [ ] **Step 3: Apply migration and deploy backend/admin**

Run the repository migration tool against the configured Neon database only
after its dry-run/connectivity check. Deploy backend before admin. Verify the
public playback route and authenticated create route, then deploy `shieldweb`.

- [ ] **Step 4: Exercise the real workflow**

Upload a short non-sensitive MP4, seek in admin/member web/member APK/agent app,
replace it, and delete it. Query only counts and byte lengths to confirm one
completed media row appears, replacement removes the old unreferenced row and
final deletion removes the test row. Never print binary data.

- [ ] **Step 5: Repository audit and commit**

Run `git diff --check`, `git status --short`, and a secret-pattern scan excluding
ignored env files and generated outputs. Commit only the documentation:

```powershell
git add docs/admin-console.md docs/deployment.md docs/database.md backend/docs/tech-stack.md
git commit -m "docs: document Neon customer video storage"
```
