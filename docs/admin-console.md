# Admin Console

`shieldweb/` is a React 18 + TypeScript + Vite + Tailwind operations console. Its entry point is `shieldweb/src/main.tsx`; routes are defined in `shieldweb/src/App.tsx`.

## Routes

The current console includes login, dashboard, stores, products, orders, prescriptions, activations, lab orders, lab tests, appointments, users, user details, admins, agent approvals, deliveries, and no-access views. Parameterized routes include activation, user/member detail, and agent approval detail pages.

### Deliveries

`DeliveriesPage` (`/deliveries`) is the `DELIVERY` role's own portal — "available to deliver" (unclaimed cash orders at their branch) and "my deliveries" (claimed, with "mark cash collected" and status-advance actions) — plus a simpler store-scoped assignment view for admin/superadmin/pharmacy to hand a cash order to a specific delivery boy. Backed by `src/api/deliveries.ts`, which is deliberately still direct-to-Neon like the rest of the console's data screens (see [Current authentication implementation](#current-authentication-implementation) below) rather than the unused `backend/api` `StaffCommerceController`.

### Orders → Bills

A member order is reviewed on **Orders** first and only reaches **Bills** when an admin converts it. `OrderReviewModal` (`src/components/orders/OrderReviewModal.tsx`) follows the same two steps as the prescription review:

1. **Items** — set each line's stock status (Stock available, Out of stock, Not possible, Customer not needed); "Process ✓" groups the lines by status. These statuses are counter-only and never shown in the member's app. "Next: Details →" moves on.
2. **Details** — edit the member's name and phone (with call and WhatsApp buttons beside the phone, same as prescriptions), the branch, and, for a pending cash order, the delivery boy. **Submit** saves the statuses and details (`saveOrderReview`), then the button becomes **Convert to bill →**, which stamps the order (`markOrderConvertedToBill`) and opens that order's bill on the Bills page.

`BillsPage` lists only orders where `app."order".converted_to_bill_at` is set, so a freshly received order never shows there. Pricing, sending the invoice and the OTP-gated payment collection happen from Bills (see [Bill collection OTP](#bill-collection-otp)). A new bill starts with the "Stock available" lines only; other lines can be added by hand. The prescription review modal's "Convert to bill →" stamps its linked order the same way. Orders no longer have their own "Manage bill" or "Remove bill" actions; those live on Bills.

The **Call** and **WhatsApp** buttons beside the phone on the Details step (on Orders, and on a prescription's Details step for its linked order) also record the first time staff contacted the member (`markOrderStoreContacted` → `app."order".store_contacted_at`, migration `0045_order_store_contacted_at.sql`). That is what moves the order to **Store contact** in the member's app (see [Order tracking](architecture.md#order-tracking)); clicking again never changes the date, and a cancelled order is not stamped.

This depends on migration `backend/db/migrations/0044_order_review_and_bill_conversion.sql` (new `app.order_line.stock_status`, `app."order".reviewed_at` and `converted_to_bill_at`). It backfills any order that already has a bill as converted, so existing bills stay visible. Until the migration is applied, the Orders and Bills pages will fail to load their queries.

### Agent approval queue

`AgentApprovalsPage` lists every `app.agent_request` still `PENDING` (`src/api/agents.ts listPendingAgents`); `AgentApprovalDetailPage` confirms the level/parent/area and calls `approveAgent` (inserts the real `app.agent` row, links `agent_request.agent_id`, marks the request `APPROVED`) or `rejectAgent` (marks `REJECTED` with a reason, no `agent` row — the app's team tree unlocks the slot). These requests come from the app's own OTP-verified registration flow (`shield/` and `shield agent_invester/`), which never writes `app.agent` directly.

A user can also be made an agent directly, bypassing the request queue: `UserDetailPage`'s "Convert to agent" (`convertToAgent` in `src/api/users.ts`) creates the `app.agent` row on the spot. Every level below national must pick a real named slot — a cascading region → state → district → assembly → lsgd → ward picker (`src/api/geo.ts`, reading `app.region`/`state`/`district`/`assembly`/`lsgd`/`ward`) sized to however many tiers that level needs — so the new agent gets a real `area_id` and locks into a slot in the team tree instead of floating with no area. A slot already held by an approved agent is refused, same as the request-approval path.

### Category images (Banners → Categories)

`CategoryBannerPanel` (`src/components/banners/`, data in `src/api/categoryBanners.ts`) edits `app.product_category` and `app.product_subcategory`. Three separate image slots feed the storefront's "Shop by categories" surfaces:

- **Chip image** (`product_category.image`) — the artwork on the category's chip in the home strip.
- **Tile image** (`product_subcategory.image`) — one per sub-category, uploaded beside its label; the card in the home panel and the Categories tab.
- **Promotional banner** (`product_category.banner_image`) — the top of the category's listing.

Chip and tile images are stored as resized WebP data URIs (PNG on a browser whose canvas cannot encode WebP), so transparent cut-outs keep their alpha on the category's tint; banners stay JPEG. A blank image falls back to the slot's icon (`icon_name`). Rows seeded before uploads existed may hold a bundled asset path, which the console previews as "Bundled artwork".

Both apps read this data: the member app straight from Neon (`lib/data/neon/category_repository.dart`), and `shield agent_invester/` through the backend API's public catalogue routes (`lib/data/backend/category_repository.dart`). The API caches those lists for 5 minutes and the console writes to Neon directly, so a change reaches the agent / investor app within about 5 minutes; the member app sees it on its next catalogue load.

### Customer videos (Supabase Storage)

"What our customers have to say" on the app home screen is managed from **Customer Videos** (`CustomerVideosPage`, data in `src/api/customerReviewVideos.ts` over `app.customer_review_video`). Each clip is an **uploaded video file** stored in a public Supabase Storage bucket — YouTube links are no longer accepted, and the apps have no YouTube player any more. The video files live in Supabase Storage, not in a Postgres table; the table row only keeps the clip's name, caption, poster image and the video's public URL.

How a clip gets there: the console never holds the Supabase key. On save it asks the backend (`POST /v1/staff/catalogue/review-videos/upload-url`, `SUPERADMIN`/`ADMIN` only) for a single-use signed upload link — the backend checks the file type and size first, and mints the link with the service-role key, which only ever exists on the server — then sends the file straight to Supabase with progress, and saves the row with the clip's public URL as `video_url`. The console also grabs a poster frame from the file in the browser (`src/lib/videoPoster.ts`) and stores it as the row's `thumbnail`, so the app draws the reel from images and never downloads a video just to show a card; an admin-chosen image overrides it. Replacing a video, deleting a clip, or a save that fails after the upload removes the now-unused file from the bucket (`POST .../review-videos/media/delete`, restricted to this feature's `review-videos/` prefix in our own bucket). Accepted: MP4, WebM or MOV. The size limit is `REVIEW_VIDEO_MAX_MB` on the backend (50 by default, hard ceiling 200) and is checked before the upload starts.

In the apps (`shield agent_invester/` and the root app), tapping a card opens a full-screen viewer (`review_video_player_screen.dart`, built on `video_player`): tap the sides or swipe for the previous/next clip, tap the middle to pause, mute, swipe down or close to leave; a finished clip moves on by itself. Only `http(s)` non-YouTube URLs are shown — rows from before uploads existed (a YouTube link, or a bundled `assets/reviews/…` path whose file no longer ships) are flagged in the console list and skipped in the app until someone uploads a video for them. The agent / investor app reads through the backend's public catalogue route, which caches for about a minute.

**One-time Supabase setup** (until this is done the console reports "Video storage isn't set up yet" and uploads are refused):

1. In your Supabase project, open **Storage → New bucket**. Name it `customer-reviews` (or anything, and set `SUPABASE_PUBLIC_BUCKET` to match) and turn **Public bucket** on — the apps read the videos by plain URL. Use this bucket for nothing else.
2. On that bucket, set **Restrict file size** (50 MB on the free plan — Supabase caps every file at that; higher only on a paid plan, and then raise `REVIEW_VIDEO_MAX_MB` to match) and **Restrict MIME types** to `video/mp4, video/webm, video/quicktime`. The API checks these too; this is the second lock.
3. From **Project Settings → API**, copy the project URL and the `service_role` key (or a secret key). Set these on the backend (`backend/api`, e.g. the Vercel project's environment variables; see `backend/api/.env.example`) and redeploy: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_PUBLIC_BUCKET`, and optionally `REVIEW_VIDEO_MAX_MB`.

The service-role key bypasses row-level security, so treat it like a database password: server-side only, never in the console, the apps or git. Supabase Storage answers browser uploads and playback with CORS enabled, so no bucket CORS rule is needed.

The signed-link request, the upload flow, error handling and both apps' viewers are covered by tests, but those use a stand-in for Supabase — the first real upload against your project has not been exercised. Try one short clip from the console and open it in the app once step 3 is done.

## Roles

Permission definitions and landing paths live in `shieldweb/src/config/permissions.ts`. Current roles are `superadmin`, `admin`, `pharmacy`, `lab`, `appointments`, and `delivery` (migration `0031_wallet_cash_delivery.sql`, adding `app.admin_role.DELIVERY`); pharmacy and delivery access are both scoped by `storeCode`.

Creating a staff account (any role) is done from `AdminsPage`'s "Add staff account" form (`POST /v1/staff/admins`, `SUPERADMIN` only) — this was previously backend-only, no console UI.

## Current authentication implementation

The code currently authenticates against the credential list in `shieldweb/src/config/admins.ts` and persists only the login id in browser `localStorage` via `AuthContext`. It does not currently use Firebase Email/Password or resolve admin identity from `app.admin_user`, despite older README text saying otherwise. Do not copy or publish the credentials from that source file.

This must be replaced with a server-side authentication and authorization boundary before public or high-trust deployment. See [Security](security.md).

## Data access

Each `shieldweb/src/api/*.ts` module is a thin query layer over Neon. Pages call API modules rather than embedding SQL. The browser bundle currently receives the database URL, so this console should be treated as internal-only until queries move behind a server API.

## Local commands

### Bill collection OTP

The Bills and Orders invoice modal sends member SMS codes through Firebase
Phone Authentication in project `shield-zabnix`, separately from staff login.
The exact admin website hostname must be registered under Firebase Console →
Authentication → Settings → Authorized domains. Each production, custom, or
preview hostname used for collection must be registered individually. A
`Hostname match not found (auth/captcha-check-failed)` response rejects the
website before an SMS is sent; changing frontend code or Android fingerprints
does not authorize a missing web hostname.

After adding the hostname, reload the admin page and send a new code. The modal
accepts six-digit SMS codes, resets the verification when resending, and cleans
up reCAPTCHA after each send attempt and when closing. Local Indian numbers and
numbers already prefixed with `+91` are normalized to one recipient format.
Wallet collection is invoked by the UI only after Firebase confirms the code;
an unsuccessful collection after verification requires a fresh code. This is
still a client-side gate over the existing direct database API, not server-side
OTP enforcement; the existing security limitations above remain.

Run `npm run test:otp` from `shieldweb/` with Node 22.18+ for the OTP regression
tests, plus the typecheck and build commands below. A real SMS and successful
bill settlement still need end-to-end verification on the authorized hostname.

```powershell
Set-Location shieldweb
npm install
npm run typecheck
npm run build
npm run dev
```

Vite normally serves at `http://localhost:5173`. Vercel is configured to build `dist` and rewrite routes to `index.html`; see [Deployment](deployment.md).
