# SHIELD Implementation Log

Append-only record of implementation passes. Newest entries go at the bottom.

> **Note:** This log was re-initialised on 2026-08-18 after the repository
> working tree was cleared. Entries prior to that point were lost with the
> previous `log.md` and are not recoverable from this file.

---

## 1. Flutter App Scaffold: Customer Home Shell, Bottom Navigation, and Brand Assets (2026-08-18 20:05:00 IST)

**High-level description**: Created a new Flutter application from scratch after the previous `frontend/` and `backend/` trees were removed from the working directory. The app targets Flutter web and reproduces the supplied customer-home reference design. The project was authored file-by-file rather than via `flutter create`, because that command was unavailable in the session.

- Project files created:
  - `pubspec.yaml` — package `shield`, Flutter SDK `^3.10.0`, assets declared for `assets/logos/`
  - `web/index.html` — minimal web host page using `flutter_bootstrap.js`
  - `assets/logos/shield_mark.png`, `assets/logos/shield_wordmark.png` — copied from the retained `logos/` folder
- Application structure created:
  - `lib/main.dart` — `ShieldApp` root, Material 3, brand-seeded `ColorScheme`
  - `lib/theme/app_colors.dart` — initial palette
  - `lib/screens/app_shell.dart` — `IndexedStack` over the four destinations, persistent promo strip + bottom navigation
  - `lib/screens/home_screen.dart` — home composition
  - `lib/screens/categories_screen.dart`, `orders_screen.dart`, `account_screen.dart`, `placeholder_screen.dart`
  - `lib/widgets/bottom_nav.dart` — four-tab bar with top active-indicator, icon-above-label, animated indicator, text-scale clamped to 1.3 so the 64px bar cannot overflow
  - `lib/widgets/coupon_bar.dart` — sticky promotional strip, dismisses on Apply
  - home section widgets — `home_header.dart`, `promo_banner.dart`, `circular_badge.dart`, `prescription_card.dart`, `app_offer_card.dart`
- Notable implementation detail:
  - `circular_badge.dart` implements a `CustomPainter` that lays out each glyph individually along a circular arc, advancing by `glyphWidth / radius`, so the "TOP BRANDS / DOCTOR APPROVED" seal wraps evenly around the shield mark
- Deliberate deviations from the reference:
  - the presenter photograph in the hero banner was omitted; only the two logo files were available as image assets
  - the store-listing mockup was rebranded to "SHIELD – Online Health App" rather than reproducing the third-party product name from the reference
- Platform scope:
  - web only; no `android/`, `ios/`, or `windows/` platform folders exist because `flutter create` could not be run

### Files Modified/Created
**Created**: `pubspec.yaml`, `web/index.html`, `assets/logos/*`, `lib/main.dart`, `lib/theme/app_colors.dart`, `lib/screens/*.dart`, `lib/widgets/bottom_nav.dart`, `lib/widgets/coupon_bar.dart`, `lib/widgets/home/*.dart`

**Verification Commands**:
- `flutter pub get`
- `flutter analyze` — no issues found
- `flutter run -d chrome --web-port 53431` — 0 render overflows, 0 asset 404s, 0 exceptions

---

## 2. Logo-Derived Theme, Category Browser, Offer Carousel, and Store Panel (2026-08-18 20:20:00 IST)

**High-level description**: Rebuilt the colour system so every value derives from the SHIELD logo artwork instead of placeholder blues, and extended the home screen with the three sections shown in the second batch of reference screenshots: an expanded app-download panel, a swipeable offer carousel, and a "Shop by categories" browser.

- Brand colour extraction:
  - sampled `assets/logos/shield_mark.png` directly rather than estimating values
  - shield body resolves to `#2C57A6`; check mark resolves to `#93C73F`
  - both confirmed at multiple sample points across each shape
- `lib/theme/app_colors.dart` rewritten:
  - `brandBlue` `#2C57A6` and `brandGreen` `#93C73F` are the two source values
  - shades derived from them: `brandNavy`, `brandBlueDeep`, `brandGreenDeep`, `brandGreenDark`
  - tints derived from them: `pageTint`, `bannerTop`, `bannerBottom`, `offerTint`, `categoryPanel`, `greenTint`, `creamTint`
  - text and line colours retuned to blue-leaning neutrals so they sit with the brand hue
  - removed the previous `brandPurple` and `brandGold` accents, which were not present in the logo
- Home screen additions:
  - `lib/module/home/category_section.dart` — stateful "Shop by categories" block; four selectable category chips (Personal Care, Health Conditions, Vitamins & Supplements, Diabetes Care), each driving a six-card sub-category grid with "Up to 50% off" pricing lines and a contextual "View all … products »" action. The active chip visually merges into the panel beneath it.
  - `lib/module/home/promo_carousel.dart` — three-page `PageView` offer carousel with an animated page-dot indicator and a stylised coupon ticket rendered from widgets
  - `lib/module/home/app_offer_card.dart` — extended with a downloads/rating statistics row (`1Cr+ Downloads · 4.5 · 5.61L reviews`) and a full-width "Download App" call to action carrying Play and Apple glyphs
- Accent reassignment following the palette change:
  - "Branded Substitutes" emphasis and the Same Effect / Same Composition badges moved from purple/gold to `brandGreenDeep`
  - the sticky coupon strip moved to `brandGreenDark` for legible white text
- Directory alignment:
  - home section widgets now live under `lib/module/home/`; the newly added carousel was placed there to match

### Files Modified/Created
**Created**: `lib/module/home/category_section.dart`, `lib/module/home/promo_carousel.dart`

**Modified**: `lib/theme/app_colors.dart`, `lib/module/home/app_offer_card.dart`, `lib/module/home/promo_banner.dart`, `lib/widgets/coupon_bar.dart`, `lib/screens/home_screen.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter run -d chrome --web-port 53431`

---

## 3. Feature Module Extraction: Categories, Orders, Account, Wallet, and Cart (2026-08-18 20:40:00 IST)

**High-level description**: Replaced the three placeholder tab screens with real feature modules and added two new ones, so every destination under `lib/module/` owns its own screen instead of sharing a generic empty state. The header wallet and cart buttons, which previously had no behaviour, now open their modules.

- Modules created under `lib/module/`:
  - `categories/categories_screen.dart` — four grouped category sections (Personal Care, Health Conditions, Vitamins & Supplements, Diabetes Care) rendered as 4-column icon grids
  - `orders/orders_screen.dart` — order history cards carrying id, placed-on date, item count, total, and a colour-coded status chip; status colours are defined on an enhanced enum (`delivered`, `outForDelivery`, `processing`, `cancelled`)
  - `account/account_screen.dart` — profile card plus three grouped menu blocks; the Wallet and Cart rows push their respective modules
  - `wallet/wallet_screen.dart` — gradient balance card built from the two logo colours, quick top-up chips, and a credit/debit transaction ledger
  - `cart/cart_screen.dart` — stateful cart with quantity steppers, live bill recalculation (26% SHIELD discount + delivery fee), a checkout bar, and an empty state that replaces the list when the last line is removed
- Wiring changes:
  - `lib/screens/app_shell.dart` now resolves its three non-home destinations from `lib/module/` instead of `lib/screens/`
  - `lib/module/home/home_header.dart` — `_CircleAction` gained `onTap` and `tooltip` parameters; the wallet and cart buttons push `WalletScreen` and `CartScreen`
- Files removed:
  - `lib/screens/categories_screen.dart`, `lib/screens/orders_screen.dart`, `lib/screens/account_screen.dart`, `lib/screens/placeholder_screen.dart` — superseded by the modules above; the shared placeholder had no remaining callers
- Note on scope:
  - all module data is currently hard-coded in-file; there is no backend in this repository, so the screens present representative fixtures rather than live records

### Files Modified/Created
**Created**: `lib/module/categories/categories_screen.dart`, `lib/module/orders/orders_screen.dart`, `lib/module/account/account_screen.dart`, `lib/module/wallet/wallet_screen.dart`, `lib/module/cart/cart_screen.dart`

**Modified**: `lib/screens/app_shell.dart`, `lib/module/home/home_header.dart`

**Removed**: `lib/screens/categories_screen.dart`, `lib/screens/orders_screen.dart`, `lib/screens/account_screen.dart`, `lib/screens/placeholder_screen.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter run -d chrome --web-port 53431`

---

## 4. Brand Mark Adopted as Application Logo and Web App Icon (2026-08-18 20:55:00 IST)

**High-level description**: Replaced the header wordmark with the shield mark and promoted that mark to the application icon across the web target. The source artwork was cropped before use, because roughly 45% of `shield_mark.png` is empty padding which made the logo render undersized wherever it appeared.

- Artwork analysis:
  - `shield_mark.png` is 4500x4500 with a fully transparent background
  - measured content bounding box is x 1096..3404, y 1020..3480 (2308x2460), centred exactly on the image midpoint
  - the remaining area is transparent padding, so the visible mark occupied only about half of each rendered box
- Assets generated from a 2700x2700 centred crop, high-quality bicubic resampling:
  - `assets/logos/shield_logo.png` — 1024x1024, transparent, in-app logo
  - `web/favicon.png` — 64x64
  - `web/icons/Icon-192.png`, `web/icons/Icon-512.png` — standard PWA icons
  - `web/icons/Icon-maskable-192.png`, `web/icons/Icon-maskable-512.png` — white background with a 16% inset so the mark survives Android's maskable safe-area crop
- Application changes:
  - `lib/module/home/home_header.dart` — the `shield_wordmark.png` image was replaced by `shield_logo.png` at 34px, followed by a "SHIELD" text lockup in `brandBlue`. The wordmark artwork is a dense four-line composition ("MISSION S.H.I.E.L.D" plus tagline and strapline) and was illegible at header scale.
  - `lib/module/home/circular_badge.dart`, `lib/module/home/app_offer_card.dart`, `lib/module/wallet/wallet_screen.dart` — repointed from `shield_mark.png` to the cropped `shield_logo.png`
- Web shell changes:
  - `web/manifest.json` created — name/short_name SHIELD, `theme_color` `#2C57A6` taken from the logo blue, standalone display, four icon entries
  - `web/index.html` — added `theme-color` meta, `icon`, `apple-touch-icon`, and `manifest` links
- Retained files:
  - `assets/logos/shield_mark.png` and `assets/logos/shield_wordmark.png` are still present and still bundled; nothing references the wordmark at present

### Files Modified/Created
**Created**: `assets/logos/shield_logo.png`, `web/favicon.png`, `web/icons/Icon-192.png`, `web/icons/Icon-512.png`, `web/icons/Icon-maskable-192.png`, `web/icons/Icon-maskable-512.png`, `web/manifest.json`

**Modified**: `web/index.html`, `lib/module/home/home_header.dart`, `lib/module/home/circular_badge.dart`, `lib/module/home/app_offer_card.dart`, `lib/module/wallet/wallet_screen.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter run -d chrome --web-port 53431`

---

## 5. Product Showcases, Customer Reviews, and Responsive Overflow Fixes (2026-08-18 21:15:00 IST)

**High-level description**: Added three product-showcase strips and a customer-reviews wall to the home screen, generated avatar image assets for the reviews, and introduced a widget-test suite. The suite immediately exposed seven genuine responsive layout defects at phone widths that the wide desktop browser run had never triggered; all were fixed.

- Assets generated:
  - `assets/avatars/avatar_1.png` … `avatar_5.png` — 256x256 circular reviewer portraits, brand-tinted with initials, drawn programmatically
  - `pubspec.yaml` — `assets/avatars/` registered
- Home additions:
  - `lib/module/home/product_showcase.dart` — reusable titled strip with an optional subtitle, "View all" action, and a horizontal row of product cards. Cards carry a tinted thumbnail, discount ribbon, name, pack size, price with struck-through MRP, and an ADD action. Three fixture catalogues are exposed via `ProductCatalogue`: `newArrivals`, `bestSellers`, `dealsOfTheDay`.
  - `lib/module/home/customer_reviews.dart` — "What our customers say" wall with an aggregate rating summary and horizontally scrolling review cards, each showing an avatar image, star rating, body text, and a verified-purchase marker
  - `lib/screens/home_screen.dart` — three `ProductShowcase` sections ("New on SHIELD", "Best Sellers", "Deals of the Day") followed by `CustomerReviews`
- Test suite added:
  - `test/home_screen_test.dart` — pumps the home screen at a 4200px-tall surface so every section lays out in a single pass, including those a normal viewport leaves unbuilt. Covers section presence, review avatars, product cards, and a 320px narrow-viewport case.
- Responsive defects found by the suite and fixed:
  - `category_section.dart` — sub-category card overflowed 48px; the fixed 44px thumbnail now sits in an `Expanded`/`FittedBox` so it shrinks instead, and the grid `childAspectRatio` moved from 0.86 to 0.74
  - `promo_banner.dart` — the two claim badges overflowed 102px in a `Row`; replaced with a `Wrap`
  - `app_offer_card.dart` — the store-statistics `Row` overflowed 185px; replaced with a `Wrap`. The offer label, rating text, download-button label, and store-mockup caption gained `Flexible`/`maxLines` guards.
  - `promo_carousel.dart` — the promo copy column overflowed 97px and the coupon ticket 11px; title size reduced 23→20 with single-line ellipsis, coupon percentage 34→28 and "OFF" 20→16
  - `home_header.dart` — the brand lockup row overflowed 22px at 320px; the "SHIELD" label is now `Flexible` with ellipsis
- Note on scope:
  - product cards use tinted Material icons rather than photography, and reviewer portraits are generated initial avatars; both are placeholders pending real imagery

### Files Modified/Created
**Created**: `lib/module/home/product_showcase.dart`, `lib/module/home/customer_reviews.dart`, `test/home_screen_test.dart`, `assets/avatars/avatar_1.png` … `avatar_5.png`

**Modified**: `lib/screens/home_screen.dart`, `pubspec.yaml`, `lib/module/home/category_section.dart`, `lib/module/home/promo_banner.dart`, `lib/module/home/app_offer_card.dart`, `lib/module/home/promo_carousel.dart`, `lib/module/home/home_header.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 3/3 passed
- `flutter run -d chrome --web-port 53431`

---

## 6. Header Hamburger Wired to a Slide-In Menu Drawer (2026-08-18 21:35:00 IST)

**High-level description**: Implemented the navigation drawer behind the header hamburger, which until now was a dead control. The drawer follows the supplied reference: a titled bar with a circular close affordance, a tinted account strip, twelve browse links, and a shaded account group at the end.

- Module created:
  - `lib/module/menu/menu_drawer.dart` — `MenuDrawer` takes an `onSelectTab` callback so menu selections drive the existing bottom-navigation model rather than pushing duplicate routes
  - drawer width is 86% of the viewport, square-edged to match the reference
  - `_MenuHeader` — "Menu" title plus a circular outlined close button
  - `_AccountStrip` — phone number over an "Add more user details >" action, on a left-to-right gradient interpolating the two logo colours at low saturation (`#CFE4F7` → `#E2F4E4`)
  - `_MenuRow` — label plus chevron, with an optional transparent variant so the shaded bottom group reads as one block (`#F3F4F6`)
- Routing behaviour:
  - the twelve browse links close the drawer and switch to the Categories destination
  - "My orders" switches to Orders, "Account" switches to Account
  - "Refer & earn" closes the drawer; no destination exists for it yet
- Wiring changes:
  - `lib/screens/app_shell.dart` — `Scaffold.drawer` now hosts `MenuDrawer`, with `onSelectTab` updating `_index`
  - `lib/module/home/home_header.dart` — the hamburger calls `Scaffold.maybeOf(context)?.openDrawer()`; `maybeOf` is used deliberately so the header stays safe when hosted by a Scaffold without a drawer, which is how the home widget tests mount it
- Test suite added:
  - `test/menu_drawer_test.dart` — four cases covering drawer open, close-button dismissal, tab switching via "My orders", and reaching the Account destination
  - the tab-switching cases scroll the drawer list before tapping, because the shaded account group sits past the fold at a 900px viewport, and scope their finders to the `Drawer` subtree since "Account" also appears as a bottom-navigation label

### Files Modified/Created
**Created**: `lib/module/menu/menu_drawer.dart`, `test/menu_drawer_test.dart`

**Modified**: `lib/screens/app_shell.dart`, `lib/module/home/home_header.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 7/7 passed
- `flutter run -d chrome --web-port 53431`

---

## 7. Header Trailing Actions Pinned to the Right Edge (2026-08-18 21:50:00 IST)

**High-level description**: Fixed the wallet and cart buttons sitting inset from the right edge of the home header instead of flush against it. The defect was introduced in entry 5 while guarding the brand lockup against narrow-viewport overflow.

- Root cause:
  - the "SHIELD" label had been wrapped in `Flexible` alongside a `Spacer`
  - `Flexible` defaults to `FlexFit.loose`, so the label takes only its intrinsic width and the unused remainder of its flex slot is not consumed
  - `RenderFlex` hands that leftover to `mainAxisAlignment`, which defaults to `MainAxisAlignment.start`, placing the slack *after* the final child — so both action buttons were pushed inward
- Fix:
  - `lib/module/home/home_header.dart` — the label now uses `Expanded` (tight fit) and the `Spacer` was removed; the label fills the slack itself and the trailing actions stay pinned right, while `maxLines: 1` + ellipsis keeps the narrow-viewport guard intact
  - `lib/screens/home_screen.dart` — header right padding reduced from 12 to 8 so the trailing circle sits closer to the edge
- Regression test added:
  - `test/home_screen_test.dart` — "wallet and cart actions are pinned to the right edge" measures `getTopRight` of both action icons at a 400px viewport and asserts the cart's right edge is within 24px of the viewport edge
  - the assertion was confirmed to fail against the pre-fix layout, measuring 61.6px of inset, so it genuinely guards the behaviour rather than passing vacuously

### Files Modified/Created
**Modified**: `lib/module/home/home_header.dart`, `lib/screens/home_screen.dart`, `test/home_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 8/8 passed
- deliberate revert check — the new assertion fails at 61.6px inset without the fix

---

## 8. Full-Screen Menu Drawer with Account Dashboard (2026-08-18 22:10:00 IST)

**High-level description**: Widened the navigation drawer to take over the entire viewport instead of sliding partway across it, and added an at-a-glance dashboard panel at the top of the menu.

- `lib/module/menu/menu_drawer.dart`:
  - drawer `width` changed from `MediaQuery.sizeOf(context).width * 0.86` to the full viewport width
  - added `_DashboardPanel` — a "Dashboard" heading over four tappable stat tiles on a `pageTint` background, placed above the browse links
  - tiles: Wallet balance `₹3,472`, Active orders `2`, Cart items `4`, Reward points `1,240`
  - tile column count is resolved by `LayoutBuilder`: two per row below 520px, four across above it, with widths computed from the available constraint so the `Wrap` never overflows
  - `_StatTile` wraps its value in a `FittedBox(scaleDown)` so long figures shrink rather than clip
  - added `_push` helper so the wallet and cart tiles close the drawer and then push their screens, while the orders and rewards tiles switch bottom-navigation destinations via the existing `_go`
  - class doc comment updated: the menu is no longer a partial slide-in
- Tests added to `test/menu_drawer_test.dart`:
  - drawer fills the full screen width (asserts a measured 400px against a 400px viewport)
  - dashboard panel shows all four stat labels and the wallet figure
  - wallet tile closes the drawer and lands on the wallet screen
- Existing test adjusted:
  - "hamburger opens the menu drawer" previously asserted `Health Library` was present on open. The dashboard panel consumes vertical space, so the tail of the link list now falls past the fold and is not built by the lazy `ListView`. The assertion now scrolls the entry into view first, which also proves it stays reachable.

### Files Modified/Created
**Modified**: `lib/module/menu/menu_drawer.dart`, `test/menu_drawer_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 11/11 passed
- `flutter run -d chrome --web-port 53431` — 0 overflows, 0 exceptions

---

## 9. Refer & Earn Level Ladder with Journey Map (2026-08-18 22:35:00 IST)

**High-level description**: Added a refer-and-earn feature: an entry card in the home feed, and a dedicated screen presenting the reward ladder as a serpentine journey map with the member's current level called out.

- Domain model — `lib/module/refer/referral_level.dart`:
  - `ReferralLevel` carries the level number, title, human-readable requirement, `directRequired`, `networkRequired`, reward, and whether the reward is cash
  - a level clears only when **both** thresholds are met, which encodes the stated rule that level 2 needs 2 direct referrals *and* those members to add members of their own
  - `ReferralProgress` holds `directReferrals` and `networkSize` and derives `currentLevel`, `nextLevel`, and `progressTowards`
  - `currentLevel` stops at the first uncleared rung, so a lopsided member (many direct referrals, no network growth) cannot skip ahead
  - `ReferralLadder` publishes five levels: Starter (1 referral → 100 points), Builder (2 + network 2 → ₹200), Connector (4 + network 8 → ₹500), Champion (8 + network 24 → ₹1,200), Ambassador (16 + network 60 → ₹3,000)
- Journey map — `lib/module/refer/journey_map.dart`:
  - nodes alternate left and right down the screen, joined by a cubic connector drawn with a `CustomPainter`
  - the connector is solid up to the level the member can currently reach and dashed beyond it; the dashed variant is produced by walking `Path.computeMetrics()` and re-extracting segments
  - connector endpoints are derived from a shared `nodeInset` constant so the curve always meets the node centres regardless of viewport width
  - node states: cleared (green, check), current (blue, level number, glow), locked (outlined, padlock)
  - each node pairs with a card showing the requirement, a reward chip, and — on the current level only — a `n/m referred` counter
- Screen — `lib/module/refer/refer_earn_screen.dart`:
  - gradient standing card with the current level, an `n of 5` badge, referred/network/earned metrics, a progress bar towards the next level, and the shortfall spelled out
  - referral code card with a clipboard copy action
- Home entry — `lib/module/home/refer_earn_card.dart`:
  - gradient card placed between the product showcases and the reviews wall, showing the current level and remaining referrals, pushing `ReferEarnScreen` on tap
- Dead ends wired up:
  - the drawer's "Refer & earn" row previously only closed the drawer; it now opens the screen
  - the account screen's "Refer & Earn" row had an empty `onTap`; it now opens the screen
- Tests — `test/refer_earn_test.dart`:
  - unit coverage for the ladder rules, including the lopsided case (16 direct referrals with no network still reports level 1) and clamped progress
  - widget coverage for the current-level display, all five rungs rendering, a beginner state showing "Not started", and a 320px narrow viewport

### Files Modified/Created
**Created**: `lib/module/refer/referral_level.dart`, `lib/module/refer/journey_map.dart`, `lib/module/refer/refer_earn_screen.dart`, `lib/module/home/refer_earn_card.dart`, `test/refer_earn_test.dart`

**Modified**: `lib/screens/home_screen.dart`, `lib/module/menu/menu_drawer.dart`, `lib/module/account/account_screen.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 20/20 passed

---

## 10. Refer & Earn Card Promoted to the Top of the Home Feed (2026-08-18 22:50:00 IST)

**High-level description**: Moved the refer-and-earn entry card from near the bottom of the home feed to the first content slot, directly beneath the search field.

- `lib/screens/home_screen.dart`:
  - `ReferEarnCard` relocated from between the product showcases and the reviews wall to immediately after the search field, ahead of the promo banner
- `lib/module/home/refer_earn_card.dart`:
  - the outer wrapper was a `Container` painting a white background, which suited its old position between two white sections but would have cut a white band across the tinted top of the page
  - replaced with a plain `Padding`, so the card is background-agnostic and its own gradient supplies the fill; bottom padding carries the gap to the banner
- Test added to `test/home_screen_test.dart`:
  - "refer & earn card sits in the top section" measures vertical offsets and asserts the card falls below the search field and above the promo banner, so the placement is pinned rather than incidental

### Files Modified/Created
**Modified**: `lib/screens/home_screen.dart`, `lib/module/home/refer_earn_card.dart`, `test/home_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 21/21 passed

---

## 11. Referral Share Action and Detail-Driven Journey Map (2026-08-18 23:10:00 IST)

**High-level description**: Replaced the referral-code copy button with a real share action, and expanded each level card on the journey map to expose the underlying detail counts rather than only a headline requirement.

- Dependency added:
  - `share_plus ^13.3.0` — chosen over a hand-rolled share sheet so the action invokes the platform share dialog (`navigator.share` on web) instead of presenting share targets it cannot actually reach
- `lib/module/refer/refer_earn_screen.dart`:
  - `_CopyButton` replaced by `_ShareButton`; the clipboard import was dropped
  - shares a subject and a message carrying the referral code
  - the call is wrapped so platforms without a share sheet surface a "Sharing is not available here" notice rather than failing silently; the `ScaffoldMessenger` is captured before the await to avoid using context across an async gap
- `lib/module/refer/journey_map.dart`:
  - added `_DetailBar` — a labelled progress row rendering `have/need` for one threshold
  - every level card now shows a "Referred" bar, plus a "Network" bar where the level gates on network size (levels 2-5; level 1 does not)
  - displayed figures are capped at the requirement, so a cleared level reads `1/1` rather than `3/1`
  - bar colour resolves from state: green once the threshold is met, blue while in progress, grey while the level is locked
  - the reward chip is now accompanied by an explicit status word — Cleared / In progress / Locked
- Tests — `test/refer_earn_test.dart`:
  - detail-count coverage asserting bar counts per level, the capped `1/1` display, the in-progress `3/4` and `5/8` figures, and the status-word distribution across the ladder
  - a case asserting the screen offers Share and no longer offers Copy
  - the detail finders are scoped to `JourneyMap`, because the standing card carries its own "Referred" metric and would otherwise inflate the counts

### Files Modified/Created
**Modified**: `pubspec.yaml`, `lib/module/refer/refer_earn_screen.dart`, `lib/module/refer/journey_map.dart`, `test/refer_earn_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 23/23 passed

---

## 12. Prescription Upload Flow and Unified Home Card (2026-08-18 23:35:00 IST)

**High-level description**: Consolidated the home prescription block into one tappable card and added the dedicated upload screen it opens, reproducing the supplied reference.

- Dependency added:
  - `image_picker` — the camera and gallery tiles perform real selection rather than presenting inert buttons; on web this resolves through `image_picker_for_web`
- Screen created — `lib/module/prescription/upload_prescription_screen.dart`:
  - title and subtitle, two large source tiles ("Use Camera", "Use Gallery"), guidance box, pharmacist-call card, and a pinned "Proceed" bar
  - guidance box reproduces the three stated rules, including the supported-format list and the 5 MB cap
  - `maxBytes` is a named constant so the enforced limit and the printed rule cannot drift apart
  - selecting a file shows a confirmation strip with its name and human-readable size; a file over 5 MB flips the strip to an error treatment and keeps "Proceed" disabled
  - "Proceed" stays disabled until a valid file is present
  - picker failures (no camera, denied permission, unsupported browser) surface a notice instead of throwing
- Home card rewritten — `lib/module/home/prescription_card.dart`:
  - previously two rows inside a bordered container with no action; now a single `InkWell` card covering the upload half and the call-to-order number, opening the upload screen on tap anywhere
  - the Upload and call affordances are wrapped in `IgnorePointer` so they read as explicit actions while the whole card remains one tap target
  - the order number is exposed as `orderPhone` so tests assert against the same source as the UI
- Tests — `test/upload_prescription_test.dart`:
  - screen content, the disabled "Proceed" state before any selection, a 320px narrow viewport, and a unit check that `maxBytes` equals the advertised 5 MB
  - home-card coverage asserting both halves live inside a single `PrescriptionCard`, and that tapping it opens the upload screen
- Note on a test-only overflow:
  - the guidance heading initially failed the widget tests with a 10px overflow while the browser reported none. `flutter_test` substitutes a block test font whose every glyph is a full em square, so text-heavy rows measure far wider under test than in a real browser. The heading was wrapped in `Expanded` so it wraps instead of overflowing, which removes the false failure and hardens the real layout.

### Files Modified/Created
**Created**: `lib/module/prescription/upload_prescription_screen.dart`, `test/upload_prescription_test.dart`

**Modified**: `pubspec.yaml`, `lib/module/home/prescription_card.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 29/29 passed

---

## 13. Referral Second Gate Changed from Network Size to Subscriptions (2026-08-18 23:55:00 IST)

**High-level description**: Reworked the refer-and-earn ladder so the second condition on each level is the number of referred members who have taken a **subscription**, replacing the previous network-size measure. Level 2 now reads "refer 2 members, and at least 2 of them subscribe".

- `lib/module/refer/referral_level.dart`:
  - `ReferralLevel.networkRequired` renamed to `subscriptionsRequired`
  - `ReferralProgress.networkSize` renamed to `subscribedReferrals`
  - added `effectiveSubscriptions`, which clamps the subscriber count to the referral total — a subscriber must be someone the member referred, so inconsistent upstream data cannot unlock a level that was not earned. `isLevelCleared` reads the clamped value rather than the raw field.
  - ladder thresholds restated in subscription terms: L1 refer 1 (no subscription) → 100 points; L2 refer 2 with 2 subscribed → ₹200; L3 refer 4 with 3 subscribed → ₹500; L4 refer 8 with 6 subscribed → ₹1,200; L5 refer 16 with 12 subscribed → ₹3,000
  - requirement strings rewritten to describe subscriptions
  - sample progress changed from `(3 referrals, network 5)` to `(3 referrals, 2 subscribed)`, which still resolves to level 2
- `lib/module/refer/journey_map.dart`:
  - the second detail bar is now labelled "Subscribed" and reads `effectiveSubscriptions` against `subscriptionsRequired`
  - the bar is omitted on levels with no subscription requirement, which remains level 1 only
- `lib/module/refer/refer_earn_screen.dart`:
  - the standing card's second metric changed from "In network" to "Subscribed"
- Tests — `test/refer_earn_test.dart`:
  - the level-2 rule case now covers three states: two referrals with no subscribers, with one subscriber, and with both subscribed — only the last clears
  - new case asserting `effectiveSubscriptions` clamps a bogus 9-subscribers-from-1-referral record down to 1 and refuses to advance the level
  - the lopsided case restated: 16 referrals with nobody subscribed still reports level 1
  - detail-count assertions updated to the new figures (level 3 in progress at 3/4 referred and 2/3 subscribed)

### Files Modified/Created
**Modified**: `lib/module/refer/referral_level.dart`, `lib/module/refer/journey_map.dart`, `lib/module/refer/refer_earn_screen.dart`, `test/refer_earn_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 30/30 passed

---

## 14. Prescription Source Tiles Sized to Content (2026-08-19 00:10:00 IST)

**High-level description**: Removed the dead vertical space in the "Use Camera" and "Use Gallery" tiles on the upload screen. They were pinned to a fixed 152px box, leaving a gap below the label; they now hug their content.

- `lib/module/prescription/upload_prescription_screen.dart`:
  - `_SourceTile` no longer sets `height: 152`; it uses `EdgeInsets.symmetric(vertical: 16, horizontal: 8)` with `MainAxisSize.min`, so height follows icon + gap + label
  - icon trimmed 38 → 34, icon-to-label gap 14 → 10, label line height 1.3 → 1.25
  - measured tile height drops from a fixed 152px to 116px
  - the tile Row is wrapped in `IntrinsicHeight` with `CrossAxisAlignment.stretch`, so both tiles stay matched to the taller of the two. Without this, dropping the fixed height would let the two tiles diverge if one label ever wrapped to a different number of lines.
- Tests — `test/upload_prescription_test.dart`:
  - added a case measuring both tiles: it asserts they are equal to each other and under 130px, so a reintroduced fixed height or padding creep fails the suite
  - the measured value was read back from a deliberately failing assertion (116px) rather than estimated

### Files Modified/Created
**Modified**: `lib/module/prescription/upload_prescription_screen.dart`, `test/upload_prescription_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 31/31 passed

---

## 15. Product Thumbnails Moved to a White Background (2026-08-19 00:25:00 IST)

**High-level description**: Product cards in the home showcases painted a coloured tint panel behind each thumbnail. All product thumbnails now sit on white.

- `lib/module/home/product_showcase.dart`:
  - the thumbnail panel's `color: product.tint` becomes `AppColors.white`
  - `Product.tint` removed along with the twelve per-product tint assignments in `ProductCatalogue`; nothing else read the field, so keeping it would have left a required constructor argument that no longer affects rendering
  - the optional `product.image` path and its icon `errorBuilder` fallback are unchanged
- Scope note:
  - the `tint` values in `category_section.dart` belong to a separate `_Category`/`_SubCategoryCard` pair and were left alone; this pass covers product cards only
- Tests — `test/home_screen_test.dart`:
  - added a case that walks the first `ProductShowcase` subtree and asserts no `Container` paints a `BoxDecoration` in any of the app's tint colours, and that a white-backed panel is present
  - the assertion was checked against a deliberately reverted tint, which produced "Found 3 widgets" and failed as intended, so it is not passing vacuously

### Files Modified/Created
**Modified**: `lib/module/home/product_showcase.dart`, `test/home_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 32/32 passed
- deliberate revert check — the new assertion fails when a tint is reintroduced

---

## 16. Prescription Card Height Fix — Stretching Column (2026-08-19 00:45:00 IST)

**High-level description**: The home "Add a prescription" card was rendering roughly two and a half times taller than its content, leaving a large empty area under the call-to-order row and covering the promo banner it is meant to overlap. Fixed the constraint that caused it.

- Root cause:
  - the card's inner `Column` was written without `mainAxisSize`, which defaults to `MainAxisSize.max`
  - the card sits inside the home screen's `Stack` under `Positioned.fill` → `Align(bottomCenter)`, which passes **loose** vertical constraints down
  - a `MainAxisSize.max` Column under loose constraints expands to the full available height, so the card grew to the height of the whole Stack rather than hugging its two rows
  - this was introduced in entry 12 when the card was rewritten from a plain `Container` into `Material` → `InkWell` → `Container`; the earlier structure happened not to expose the same constraint path
- Fix:
  - `lib/module/home/prescription_card.dart` — the inner `Column` now sets `mainAxisSize: MainAxisSize.min`
  - measured card height drops from 451.4px to 187.0px
- Regression test — `test/upload_prescription_test.dart`:
  - "card hugs its two rows rather than stretching" measures `PrescriptionCard` height on the real home screen and asserts it stays under 190px
  - verified against the reverted code, which measured 451.4px and failed the assertion, so the guard is not vacuous

### Files Modified/Created
**Modified**: `lib/module/home/prescription_card.dart`, `test/upload_prescription_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 33/33 passed
- deliberate revert check — 451.4px without the fix, 187.0px with it

---

## 17. Product Thumbnail Background Removed Entirely (2026-08-19 01:00:00 IST)

**High-level description**: Follow-up to entry 15. The thumbnail area still painted its own panel — white, but a distinct layer nonetheless. That panel is gone, so products now sit directly on the card's pure white surface.

- `lib/module/home/product_showcase.dart`:
  - the thumbnail `Container` carried `decoration: BoxDecoration(color: AppColors.white, borderRadius: ...)`; it is now a plain `SizedBox` + `Padding`, holding size and inset only, with no background layer of its own
  - `AppColors.white` was confirmed to be `#FFFFFF`, so the card surface behind the product is pure white rather than an off-white tint
  - the enclosing card `Container` gained `clipBehavior: Clip.antiAlias`. With the thumbnail panel removed there is no longer a rounded top-corner clip in that layer, so a product image carrying its own fill would otherwise square off the card's corners.
  - the image `errorBuilder` wildcard parameters were tidied to `(_, _, _)` in line with current Dart wildcard rules
- Verification of surrounding surfaces:
  - the `ProductShowcase` section background and the card background are both `AppColors.white`; nothing tinted remains anywhere in the product strip

### Files Modified/Created
**Modified**: `lib/module/home/product_showcase.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 33/33 passed

---

## 18. Lab Tests Section Added to the Categories Screen (2026-08-19 01:20:00 IST)

**High-level description**: Added a diagnostics section to the Categories destination, placed after the existing product groups.

- `lib/module/categories/categories_screen.dart`:
  - new `_CategoryGroup('Lab Tests', ...)` appended to `_groups`, carrying Full Body Checkup, Blood Tests, Thyroid Profile, and Vitamin Tests
  - positioned last deliberately: the four groups above it are products that go into a cart, whereas a lab test is a booking, so it reads as a separate class of item rather than another shelf
- Tests — `test/categories_screen_test.dart` (new file):
  - the section and all four tiles render
  - an ordering assertion comparing vertical offsets, so "Lab Tests" is guaranteed to sit below every other group rather than merely happening to today
  - a 320px narrow-viewport case, since the tiles sit in a four-column grid

### Files Modified/Created
**Created**: `test/categories_screen_test.dart`

**Modified**: `lib/module/categories/categories_screen.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 36/36 passed

---

## 19. Lab Test and Appointment Destinations Added to the Bottom Bar (2026-08-19 01:45:00 IST)

**High-level description**: Extended the bottom navigation from four destinations to six by inserting Lab Test and Appointment, and introduced a single source of truth for tab order so the insertion could not silently misroute the existing destinations.

- Tab contract created — `lib/screens/app_tabs.dart`:
  - `AppTab` enhanced enum carrying label, inactive icon, and active icon for each destination, in display order: Home, Categories, Lab Test, Appointment, Orders, Account
  - the shell, the bottom bar, and the menu drawer now all resolve positions through it
- Why the enum was necessary:
  - `menu_drawer.dart` previously hardcoded `_categoriesTab = 1`, `_ordersTab = 2`, `_accountTab = 3`
  - inserting two destinations at positions 2 and 3 shifted Orders to 4 and Account to 5, so those constants would have pointed the drawer's "My orders" and "Account" rows, and the dashboard tiles, at the new Lab Test and Appointment screens
  - the constants were removed in favour of `AppTab.orders.index` and `AppTab.account.index`, which cannot drift
- Screens created:
  - `lib/module/labtest/lab_test_screen.dart` — free home-collection banner plus five bookable tests, each with parameter count, fasting requirement, discounted price against MRP, report turnaround, and a book action
  - `lib/module/appointment/appointment_screen.dart` — upcoming bookings distinguishing clinic visits from video consults, followed by a bookable doctor list with speciality, experience, and fee
- `lib/widgets/bottom_nav.dart` rebuilt:
  - items are generated from `AppTab.values` rather than a private list
  - bar height 64 → 62, icon 24 → 22, label 12 → 11 to accommodate six destinations
  - the active indicator width is now proportional (`constraints.maxWidth * 0.55`) instead of a fixed 34px, so it stays inside a narrower tab slot
  - labels are wrapped in `FittedBox(scaleDown)`; at six tabs on a 320px phone a label such as "Appointment" cannot render at full size, and scaling is more legible than ellipsing it to "Appoin…"
  - the text-scale clamp tightened from 1.3 to 1.2 for the same reason
- Tests — `test/bottom_nav_test.dart` (new file):
  - asserts the exact tab order as an explicit contract
  - all six labels render; Lab Test and Appointment open their screens
  - **Orders and Account still resolve after the insertion**, which is the regression the enum exists to prevent
  - a 320px narrow-viewport case covering all six labels

### Files Modified/Created
**Created**: `lib/screens/app_tabs.dart`, `lib/module/labtest/lab_test_screen.dart`, `lib/module/appointment/appointment_screen.dart`, `test/bottom_nav_test.dart`

**Modified**: `lib/widgets/bottom_nav.dart`, `lib/screens/app_shell.dart`, `lib/module/menu/menu_drawer.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 42/42 passed

---

## 20. Bottom Bar Reduced to Five with Home Centred and Branded (2026-08-19 02:05:00 IST)

**High-level description**: Removed Orders from the bottom bar, recentred the bar on Home, and replaced the Home glyph with the SHIELD mark drawn larger than its neighbours.

- `lib/screens/app_tabs.dart`:
  - order is now Categories, Lab Test, **Home**, Appointment, Account — five destinations, so Home lands exactly in the middle
  - `AppTab` gained `brandMark` (an optional asset path drawn instead of the icon) and `iconSize`, defaulting to 22
  - only Home sets `brandMark: 'assets/logos/shield_logo.png'` with `iconSize: 29`
- `lib/widgets/bottom_nav.dart`:
  - renders the asset when `brandMark` is set, otherwise the icon
  - the mark keeps its own blue-and-green colours; the inactive state dims it to 55% opacity rather than tinting it grey, which would have destroyed the brand identity
  - the icon slot is a fixed 29px box so the taller centre mark does not shift the other tabs' labels out of alignment
  - bar height 62 → 66 to accommodate the larger mark
- Orders moved to the drawer:
  - `lib/screens/app_shell.dart` — `OrdersScreen` removed from the `IndexedStack`; the shell now opens on `AppTab.home.index` rather than index 0
  - `lib/module/menu/menu_drawer.dart` — the "My orders" row and the dashboard's active-orders tile now `_push(OrdersScreen())` instead of switching tabs
  - `lib/module/orders/orders_screen.dart` — `automaticallyImplyLeading: false` removed. As a tab it had no back affordance and needed none; as a pushed route it would have been a dead end without one.
- Tests — `test/bottom_nav_test.dart` rewritten:
  - asserts the tab list, that the count is odd, and that `AppTab.home.index` equals the midpoint, so "centred" is enforced arithmetically rather than by eye
  - asserts Orders is absent from the tabs
  - asserts only Home carries a brand mark and that its `iconSize` exceeds every other tab's
  - asserts the shield asset actually renders in the bar
  - asserts Orders is still reachable from the drawer and that the pushed screen offers a `BackButton`

### Files Modified/Created
**Modified**: `lib/screens/app_tabs.dart`, `lib/widgets/bottom_nav.dart`, `lib/screens/app_shell.dart`, `lib/module/menu/menu_drawer.dart`, `lib/module/orders/orders_screen.dart`, `test/bottom_nav_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 45/45 passed

---

## 21. Home Brand Mark Enlarged (2026-08-19 02:15:00 IST)

**High-level description**: Increased the SHIELD mark on the centre Home tab, and removed the hardcoded icon-row height that would otherwise have clipped it.

- `lib/screens/app_tabs.dart`:
  - `AppTab.home.iconSize` 29 → 34, against 22 for every other tab
- `lib/widgets/bottom_nav.dart`:
  - the icon row was a fixed `SizedBox(height: 29)`, sized to the previous mark. Left alone it would have cropped the larger asset.
  - replaced with `_iconSlot`, derived from the largest `iconSize` across `AppTab.values`, so future size changes cannot silently clip the mark
  - bar height 66 → 70 so the taller icon row does not squeeze the label

### Files Modified/Created
**Modified**: `lib/screens/app_tabs.dart`, `lib/widgets/bottom_nav.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 45/45 passed

---

## 22. Location Bottom Sheet (2026-08-19 02:40:00 IST)

**High-level description**: Tapping the location line in the home header now opens a bottom sheet for choosing the delivery pincode, matching the supplied reference.

- Module created — `lib/module/location/location_sheet.dart`:
  - `LocationSheet.show()` presents a scroll-controlled modal sheet with rounded top corners, returning the chosen pincode or null when dismissed
  - title row with a circular close affordance; pill-shaped pincode field pre-filled with the pincode in use, carrying a blue circular submit button; "Use current location" and "Manage addresses" rows beneath dividers
  - input is restricted to six digits via `FilteringTextInputFormatter.digitsOnly` and `LengthLimitingTextInputFormatter`; submitting fewer than six shows an inline error and keeps the sheet open
  - the sheet is padded by `MediaQuery.viewInsetsOf(context).bottom` so the on-screen keyboard cannot cover the field
  - `LocationSheet.describe()` renders "400079, Mumbai" for pincodes in a small known-city map and falls back to the bare pincode otherwise, rather than inventing a city name
- `lib/module/home/home_header.dart`:
  - converted from `StatelessWidget` to `StatefulWidget` so a chosen pincode actually persists in the header; the label was previously the hardcoded string '400079, Mumbai'
  - the location row's empty `onTap` now opens the sheet and applies the result
- Tests — `test/location_sheet_test.dart` (new file):
  - unit coverage for `describe()` across known and unknown pincodes
  - sheet opens with the current pincode pre-filled; close leaves the header unchanged; a valid pincode updates the header; an unknown pincode renders without a city; a short pincode is rejected inline
  - note: the first draft used `find.byType(TextField).first`, which matched the **home screen's search field sitting behind the sheet** rather than the sheet's own input, so two cases failed misleadingly. The finders are now scoped with `find.descendant(of: find.byType(LocationSheet), ...)`.
- Known limitation:
  - "Use current location" and "Manage addresses" close the sheet and report that the capability is not connected. No geolocation package or address store exists in this project, and wiring inert share-style targets would have been worse than saying so.

### Files Modified/Created
**Created**: `lib/module/location/location_sheet.dart`, `test/location_sheet_test.dart`

**Modified**: `lib/module/home/home_header.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 51/51 passed

---

## 23. Lab Section Rebuilt with Package Cards and Its Own Bottom Bar (2026-08-19 03:15:00 IST)

**High-level description**: Replaced the placeholder lab screen with the two-screen lab experience from the supplied references: a landing page with sample-collection location, search, a Top Packages strip, booking shortcuts and a coupon banner; a full Top Packages list; and a section-specific bottom bar that takes over from the app's main one while the section is open.

- Data — `lib/module/labtest/lab_package.dart`:
  - `LabPackage` and `LabProfile` models; `LabCatalogue` publishes three packages plus individually bookable profiles
  - a package either lists its profiles directly, or rolls up a parent via `inheritsFrom`/`inheritsSummary` with `extrasLabel`/`extras`, which is how the reference presents Active Life as "Everything in Preventive Plus + 2 more tests"
- `lib/module/labtest/package_card.dart`:
  - one card widget used by both the horizontal strip and the vertical list, so the two presentations cannot drift
  - blue test-count badge, rating/booked/collection/turnaround stats, tinted `n tests · n profiles` strip with "View all", two-column profile breakdown or the inherited-package block, and the price footer with struck-through MRP, saving line, and Book action
  - `fillHeight` flag: inside the fixed-height strip the breakdown area becomes an `Expanded` scroll view so cards of differing content share one height with the footer pinned. Without it the tallest package overflowed its box by 65px.
- `lib/module/labtest/top_packages_screen.dart` — full-page list; takes an optional `onBack` so it works both as a sub-tab and as a pushed route
- `lib/module/labtest/lab_test_screen.dart` rewritten — collection-location header reusing `LocationSheet`, lab search field, Top Packages strip, Book via Call / WhatsApp shortcuts, coupon banner, and the Top Profiles and Tests list
- `lib/module/labtest/lab_section.dart`:
  - `LabSubTab` enum and `LabSection` host the two sub-screens
  - `LabBottomBar` renders Home / Labs Tests / Top Packages, with the Home glyph circled to mark it as the exit from the section rather than another destination inside it
- `lib/screens/app_shell.dart`:
  - while the lab tab is active the shell swaps `ShieldBottomNav` and the promo strip for `LabBottomBar`
  - leaving via the bar's Home item resets the sub-tab, so re-entering starts at the landing page rather than wherever the user left off
- Defects found and fixed during the pass:
  - the extras caption between two `Expanded` dividers overflowed 15px; dividers can shrink but an unbounded `Text` cannot, so it is now `Flexible` with ellipsis
  - the fixed-height strip overflowed 65px, addressed by the `fillHeight` mode above
- Test-expectation corrections:
  - `bottom_nav_test.dart` tapped Lab Test then Appointment; the main bar no longer exists inside the lab section, so the test now asserts Appointment is absent and exits via the lab bar's Home item first
  - `TopPackagesScreen` is offstage inside an `IndexedStack` until selected, so `find.byType` correctly reports nothing beforehand
- Tests — `test/lab_section_test.dart` (new file): landing content, bar takeover, sub-tab switching, exit-and-reset behaviour, the full package breakdown including the inherited block, and a 320px viewport

### Files Modified/Created
**Created**: `lib/module/labtest/lab_package.dart`, `lib/module/labtest/package_card.dart`, `lib/module/labtest/top_packages_screen.dart`, `lib/module/labtest/lab_section.dart`, `test/lab_section_test.dart`

**Modified**: `lib/module/labtest/lab_test_screen.dart`, `lib/screens/app_shell.dart`, `test/bottom_nav_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 58/58 passed

---

## 24. Appointment Destination Rebuilt as a Clinic Directory (2026-08-19 03:50:00 IST)

**High-level description**: Replaced the Appointment placeholder with the two-screen clinic experience from the supplied references: a searchable directory of clinics and hospitals, and a clinic profile listing its bookable doctors.

- Palette decision:
  - the references use a green chrome; the request was for the app's own theme, so the curved headers use the existing `brandBlue → brandNavy` gradient already carried by the wallet card and lab banner
  - the green accents that read as semantic in the reference are kept as brand green: the favourite buttons and the consultation fees use `brandGreenDeep`, and the verified badge matches the rest of the app
- Data — `lib/module/appointment/clinic.dart`:
  - `Clinic` and `Doctor` models; `ClinicDirectory` publishes six clinics with specialities and doctor rosters
  - clinic logos are lettermark tiles rather than image assets, since no clinic artwork exists in the project
- `lib/module/appointment/clinics_screen.dart`:
  - curved brand header with back affordance, title, and an area selector that reuses `LocationSheet`
  - rounded search field filtering on clinic name and type, with an explicit empty state
  - clinic cards carrying logo, name, location, phone, and a favourite toggle held per clinic
- `lib/module/appointment/clinic_detail_screen.dart`:
  - banner with faint medical glyphs, a white logo tile overlapping the curve, and a floating locate button
  - identity block with verified badge, type, location and phone; description clamped to two lines behind a read more / read less toggle
  - Available Doctors section with a doctor search, a filter button that clears the active speciality, horizontally scrolling speciality chips, and doctor rows showing avatar, speciality and fee
  - search and speciality filters compose, and an empty state covers the case where they exclude everything
  - doctor avatars reuse the generated `assets/avatars/` portraits
- `lib/screens/app_shell.dart` — the Appointment destination now resolves to `ClinicsScreen`
- Removed:
  - `lib/module/appointment/appointment_screen.dart`. Its upcoming-bookings and doctor-list content is superseded by the directory; the reference shows no upcoming section, so that content is gone rather than relocated.
- Tests — `test/clinics_test.dart` (new file): directory content, search narrowing, empty state, per-clinic favourite toggling, navigation into the detail screen, and on the detail screen the identity block, read more toggle, speciality chip filtering, doctor search, empty filter state, and a 320px viewport
- `test/bottom_nav_test.dart` — the appointment assertion moved from the removed screen's "Book a consultation" to "Clinics & Hospitals"

### Files Modified/Created
**Created**: `lib/module/appointment/clinic.dart`, `lib/module/appointment/clinics_screen.dart`, `lib/module/appointment/clinic_detail_screen.dart`, `test/clinics_test.dart`

**Modified**: `lib/screens/app_shell.dart`, `test/bottom_nav_test.dart`

**Removed**: `lib/module/appointment/appointment_screen.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 69/69 passed

---

## 25. Clinic Directory Reduced to Meiodia with Dr. Ansar (2026-08-19 04:05:00 IST)

**High-level description**: Cut the clinic directory down to the single real clinic and its single doctor, replacing the six-clinic fixture set introduced in entry 24.

- `lib/module/appointment/clinic.dart`:
  - `ClinicDirectory.clinics` now holds one entry, exposed as `ClinicDirectory.meiodia`
  - name "Meiodia Aesthetic Clinic", type "Skin, Hair & Aesthetic Clinic", Perinthalmanna, 9605558833, verified
  - the roster is a single doctor, `ClinicDirectory.drAnsar` — Dr. Ansar, Dermatology, ₹400
  - `specialities` reduced to `['Dermatology']` so it matches the doctor. A leftover chip such as Cosmetology would have had no doctor behind it, and tapping it would have dropped the list into the empty state for no reason.
  - the removed KIMS Al Shifa, Craft, Moulana, Medicore and Jaza entries were invented fixtures, not supplied data
- `test/clinics_test.dart` rewritten around the single clinic, and gained a data-integrity check asserting every speciality chip has at least one doctor behind it, so the chip/roster mismatch above cannot reappear
- Screens were not changed: the list, search, favourite toggle, detail banner, read more, chip filter and doctor search all work unchanged with one record

### Files Modified/Created
**Modified**: `lib/module/appointment/clinic.dart`, `test/clinics_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 68/68 passed

---

## 26. Category Card Artwork Enlarged to Fill the Card (2026-08-19 04:25:00 IST)

**High-level description**: The sub-category cards under "Shop by categories" were capping their product artwork inside a small tinted tile, so the newly added `assets/categories/*.jpg` bundles rendered far smaller than intended. The artwork now fills the space beneath the labels.

- `lib/module/home/category_section.dart`:
  - `_SubCategoryCard` previously wrapped the image in a 54x54 `Container` with a tint fill and rounded clip, bottom-right aligned. That tile, not the grid cell, was the size limit.
  - the tile is gone: the image now sits directly in the `Expanded` region beneath the labels, `height: double.infinity` with `BoxFit.contain`, aligned bottom-left to match the reference
  - `Expanded` is retained deliberately — the artwork absorbs whatever height the labels leave rather than pushing the fixed-ratio grid cell into overflow
  - `_FallbackIcon` extracted for the no-artwork and failed-decode paths, scaling the icon to the same region so a missing asset does not collapse the card
  - the `tint` argument to `_SubCategoryCard` became dead once the tile was removed and was dropped
- Correction made during the pass:
  - a blanket `sed` removing `final Color tint;` also deleted the field from `_Category`, which the category chips still use for their circular background. The field was restored; only `_SubCategoryCard` lost it.

### Files Modified/Created
**Modified**: `lib/module/home/category_section.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 68/68 passed

---

## 26. Category Card Artwork Enlarged (2026-08-19 04:30:00 IST)

**High-level description**: The sub-category thumbnails in "Shop by categories" rendered small. Two constraints were holding them down; both are lifted so the bundle artwork fills the space available to it.

- `lib/module/home/category_section.dart`:
  - the artwork sat in an `Align` with `height: double.infinity`, so only the leftover **height** bound it and the horizontal space went unused. It now fills a `SizedBox(width: double.infinity)` inside the `Expanded`, with `BoxFit.contain`, so it scales to whichever dimension binds first and still renders uncropped.
  - the grid was fixed at three columns. On a narrow phone that leaves roughly 92px per card, most of it consumed by the two labels. A `LayoutBuilder` now drops to two columns below 340px of panel width, which roughly halves the number of cards per row and gives each one substantially more area.
  - `childAspectRatio` 0.86 → 0.70. The labels occupy a fixed slice off the top of each cell, so additional height passes straight to the artwork.
  - the `errorBuilder` fallback is wrapped in its own `Align` so an unresolved asset still sits bottom-left rather than stretching
- Note:
  - the request referred to a second reference image, but no attachment arrived with the message. The change was made against the existing "Shop by categories" reference and the code as written; if the intended layout differs, the specifics are worth resending.

### Files Modified/Created
**Modified**: `lib/module/home/category_section.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 68/68 passed

---

## 27. Login and Sign-Up Portal (2026-08-19 05:05:00 IST)

**High-level description**: Put the app behind authentication. Added an in-memory auth service with a seeded account, a login screen, a registration screen, and a gate that decides which to show.

- `lib/module/auth/auth_service.dart`:
  - singleton holding a `Map` of accounts and a `ValueNotifier<AuthUser?>` session
  - seeded demo account — username `shield`, password `Shield@2026`
  - `logIn` normalises the username (trimmed, lower-cased) so casing and stray spaces do not lock anyone out; the password is compared exactly
  - `signUp` registers an account and signs it in, returning `SignUpError.usernameTaken` on a collision
  - `reset()` is marked `@visibleForTesting` so the suite starts from a known state
  - **SECURITY**: the seeded credentials are compiled into the bundle and readable by anyone inspecting it. They exist so the UI can be exercised before a backend is wired in, and the class is written to be replaced wholesale by real API calls. No real password should ever be placed here.
- `lib/module/auth/auth_widgets.dart` — shared `AuthHeader`, `AuthField`, `AuthButton`, `AuthError`, `AuthSwitch` so both forms stay consistent
- `lib/module/auth/login_screen.dart` — username and password with show/hide toggle, per-field validation, an inline error for bad credentials, a link to sign-up, and a panel showing the demo credentials while there is no backend
- `lib/module/auth/signup_screen.dart` — name, username (min 3), 10-digit mobile with digits-only formatters, password (min 8), and confirmation; a successful sign-up signs the member straight in
- `lib/screens/auth_gate.dart` — `ValueListenableBuilder` over the session; keyed on the username so signing out tears down the shell rather than leaving the previous member's tab and scroll state behind
- `lib/main.dart` — home is now `AuthGate`
- `lib/module/account/account_screen.dart` — the profile card reads the session instead of the hardcoded "Rahul Nair" / "+91 90000 00002"; "Log out" now calls `AuthService.logOut`
- Defect found by the suite:
  - after a successful sign-up the gate swapped its home to the shell, but `SignUpScreen` had been *pushed* on top of the login route and stayed there covering it. `_submit` now calls `popUntil((r) => r.isFirst)` on success.
- Test adjustments:
  - `bottom_nav_test.dart` and `menu_drawer_test.dart` pump `AppShell` directly; with the account card reading the session they were asserting against a signed-out state. Both now sign in the demo account before mounting.
- Tests — `test/auth_test.dart` (new file): service-level sign-in, case-insensitive usernames, registration, duplicate rejection, re-login after sign-out, session clearing; widget-level gating, empty-field validation, wrong credentials, successful login, sign-up validation and success, taken username, and account display plus log-out returning to the login screen

### Files Modified/Created
**Created**: `lib/module/auth/auth_service.dart`, `lib/module/auth/auth_widgets.dart`, `lib/module/auth/login_screen.dart`, `lib/module/auth/signup_screen.dart`, `lib/screens/auth_gate.dart`, `test/auth_test.dart`

**Modified**: `lib/main.dart`, `lib/module/account/account_screen.dart`, `test/bottom_nav_test.dart`, `test/menu_drawer_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 82/82 passed

---

## 28. Splash Screen, Dismissible Auth Prompt, and Members-Only Add to Cart (2026-08-19 05:40:00 IST)

**High-level description**: Reworked the authentication model. Entry 27 hard-gated the whole app behind login; the app is now browsable without an account, with the auth form offered at launch (dismissible) and *enforced* only where it matters — adding to the cart.

- `lib/screens/splash_screen.dart` — shield mark and wordmark centred on white
- `lib/screens/root_screen.dart` — replaces `auth_gate.dart`:
  - shows the splash for `splashDuration` (1600ms in production), then the shell
  - offers the auth flow once afterwards, and only when signed out
  - the prompt is pushed from a post-frame callback so the shell is mounted before a route lands on top of it
  - `splashDuration` and `promptForAuth` are constructor parameters so tests can shorten the splash and opt out of the prompt
  - still keyed on the session, so signing out clears the previous member's tab and scroll state
- `lib/module/auth/auth_flow.dart`:
  - `AuthFlow.show()` presents the flow as a `fullscreenDialog` route and resolves to whether a member is signed in afterwards. The result is read from the session rather than a returned value, because sign-up finishes by unwinding the stack and cannot hand one back.
  - `AuthFlow.guard()` runs an action when signed in, otherwise opens the flow and only proceeds if it completed
- `lib/module/auth/login_screen.dart` — gained an `isModal` flag: a close affordance in the app bar, and it pops itself once signed in rather than relying on a gate swap
- `lib/module/auth/signup_screen.dart` — close affordance that leaves the whole flow via `popUntil((r) => r.isFirst)`, not just the current step
- `lib/module/home/product_showcase.dart` — the ADD action is wrapped in `AuthFlow.guard`. A signed-out tap opens the auth form and adds nothing; the add only happens if the member completes it.
- Removed: `lib/screens/auth_gate.dart`, superseded by `RootScreen`
- Test note:
  - the add-to-cart cases first used `find.text('ADD').first` with `scrollUntilVisible`, which threw `Bad state: No element` — the showcases sit far down a lazy list, and `.first` cannot be evaluated while nothing matching has been built. The helper now scrolls to the "New on SHIELD" heading, then uses `ensureVisible`.
- `test/auth_test.dart` rewritten: service behaviour, splash-then-shell launch, the prompt appearing, being dismissible, being skipped when already signed in, login validation and success, sign-up validation and stack unwinding, and both add-to-cart paths

### Files Modified/Created
**Created**: `lib/screens/splash_screen.dart`, `lib/screens/root_screen.dart`, `lib/module/auth/auth_flow.dart`

**Modified**: `lib/main.dart`, `lib/module/auth/login_screen.dart`, `lib/module/auth/signup_screen.dart`, `lib/module/home/product_showcase.dart`, `test/auth_test.dart`

**Removed**: `lib/screens/auth_gate.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 84/84 passed

---

## 29. Logo-Only Splash, Checkout-Time Auth, and a Compact Centred Dialog (2026-08-19 06:15:00 IST)

**High-level description**: Reworked the auth touchpoints to a conventional e-commerce shape. The splash carries the mark alone, the account is required only at checkout, and the form is a small centred dialog rather than a full screen.

- `lib/screens/splash_screen.dart` — the "SHIELD" wordmark removed; the mark alone, 156px, centred on white
- `lib/screens/root_screen.dart` — the launch-time auth prompt and its `promptForAuth` flag are gone. The splash now leads straight into the shell.
- `lib/module/auth/auth_dialog.dart` (new) — replaces the two full-screen auth pages:
  - a `Dialog` capped at 380px wide and 82% of viewport height, so it is always smaller than the screen and a long form scrolls inside it rather than growing past the viewport
  - login and sign-up are **modes of one dialog**, switched in place. Previously sign-up was a pushed route, which is what caused the covered-login defect in entry 28; with a mode switch there is no stack to unwind.
  - compact header carrying the mark, the title, and a close affordance
  - `AuthDialog.cardKey` identifies the card, because the widget's own render box spans the whole route and cannot be measured for size
- `lib/module/auth/auth_flow.dart` — `show()` now uses `showDialog` and reads the outcome from the session
- Gate moved:
  - `lib/module/home/product_showcase.dart` — the ADD action is open to everyone again
  - `lib/module/cart/cart_screen.dart` — "Proceed to checkout" is wrapped in `AuthFlow.guard`; a signed-out tap raises the dialog and the checkout only proceeds if it completes
- Removed: `lib/module/auth/login_screen.dart`, `lib/module/auth/signup_screen.dart`
- `test/auth_test.dart` rewritten: splash carries no wordmark, launch raises no dialog, checkout gating in both directions, closing the dialog abandons the checkout, sign-up as a mode switch rather than a pushed route, and adding to the cart while signed out
  - includes a geometric assertion that the card is narrower and shorter than the viewport and has equal gaps either side

### Files Modified/Created
**Created**: `lib/module/auth/auth_dialog.dart`

**Modified**: `lib/screens/splash_screen.dart`, `lib/screens/root_screen.dart`, `lib/module/auth/auth_flow.dart`, `lib/module/home/product_showcase.dart`, `lib/module/cart/cart_screen.dart`, `test/auth_test.dart`

**Removed**: `lib/module/auth/login_screen.dart`, `lib/module/auth/signup_screen.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 83/83 passed

---

## 30. Green Bottom Bar with a Matching Active Tab (2026-08-19 06:45:00 IST)

**High-level description**: Recoloured the bottom navigation from white/blue to the brand green, with the selected destination picked out in the same green rather than a contrasting accent.

- `lib/widgets/bottom_nav.dart`:
  - bar background `AppColors.white` → `AppColors.greenTint`
  - the hairline top border moved from the neutral `border` to `brandGreen` at 40% so it belongs to the bar rather than cutting across it
  - the active tab now carries a rounded pill behind its icon, filled with `brandGreen` at 38% — the same green as the bar, deeper, so the selection reads as part of the bar instead of a foreign colour
  - the pill is an `AnimatedContainer`, so selection fades in over 180ms alongside the existing top indicator
  - active indicator `brandBlue` → `brandGreenDeep`; active icon and label `brandBlue` → `brandGreenDark`; ripple and highlight moved to green
  - inactive destinations are unchanged: no pill, `textBody` icon and label
  - the Home tab's brand mark still keeps its own colours and dims when inactive, so the shield is never tinted green
- `lib/module/labtest/lab_section.dart` — `LabBottomBar` given the same treatment. It replaces the main bar while the lab section is open, so leaving it white would have made entering the section look like a colour change.
- Test added to `test/bottom_nav_test.dart`: asserts the bar's `Material` is `greenTint`, and that every filled selection decoration inside the bar is one of the two brand greens, so a future accent cannot drift back to blue unnoticed

### Files Modified/Created
**Modified**: `lib/widgets/bottom_nav.dart`, `lib/module/labtest/lab_section.dart`, `test/bottom_nav_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 84/84 passed

---

## 31. Active Tab Line and Fill Merged into One Full-Width Block (2026-08-19 07:10:00 IST)

**High-level description**: The active tab was drawn as two detached pieces — a short indicator bar at the top of the cell and a narrower rounded pill around the icon, with a gap between them. They are now a single connected block filling the tab.

- `lib/widgets/bottom_nav.dart`:
  - the `LayoutBuilder` indicator (55% of tab width) and the rounded pill around the icon are both gone
  - the whole tab is now one `AnimatedContainer` whose **top border is the line** and whose background is the fill, so the two cannot separate: they are one box
  - the block spans the entire tab cell rather than hugging the icon
  - inactive tabs draw the same border in `transparent`, keeping an identical 3px inset so the row does not shift when selection moves
  - two named constants replace the inline colours — `ShieldBottomNav.activeLine` (`brandGreenDeep`) and `activeFill` (`brandGreen` at 30%) — so the bar and the lab bar cannot drift apart, and tests reference them instead of literals
- `lib/module/labtest/lab_section.dart` — `_LabBarItem` given the same block, referencing the same two constants
- Tests in `test/bottom_nav_test.dart`:
  - the existing colour case now also asserts the fill's decoration carries the line as its **own top border**, which is what proves the two are joined rather than merely both green
  - a new case asserts exactly one tab is marked and that the block's width equals the viewport divided by the number of destinations, so "fills the section" is measured rather than eyeballed

### Files Modified/Created
**Modified**: `lib/widgets/bottom_nav.dart`, `lib/module/labtest/lab_section.dart`, `test/bottom_nav_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 85/85 passed

---

## 32. Bottom Bar Returned to White (2026-08-19 07:25:00 IST)

**High-level description**: Reverted the bar background introduced in entry 30. The bar is plain white again; only the active tab carries colour.

- `lib/widgets/bottom_nav.dart`:
  - `Material.color` `greenTint` → `AppColors.white`
  - the top hairline returns from `brandGreen` at 40% to the neutral `AppColors.border`, which is the right weight against white
- `lib/module/labtest/lab_section.dart` — `LabBottomBar` reverted to match, so entering the lab section still is not a colour change
- Retained from entries 30–31:
  - the active tab keeps its connected block — `activeLine` on top, `activeFill` beneath, one `BoxDecoration`, spanning the full tab. Against white it now reads as the only coloured element in the bar.
  - inactive tabs still draw a transparent top border of the same width, so selection does not shift the row
- `test/bottom_nav_test.dart` — the bar-colour assertion and its case name updated to white; the connected-block and full-width assertions are unchanged and still pass

### Files Modified/Created
**Modified**: `lib/widgets/bottom_nav.dart`, `lib/module/labtest/lab_section.dart`, `test/bottom_nav_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 85/85 passed

---

## 33. Active-Tab Fill Removed; Line Only (2026-08-19 07:40:00 IST)

**High-level description**: Removed the green wash behind the selected destination. The active tab is now marked by its top line alone.

- `lib/widgets/bottom_nav.dart`:
  - the `activeFill` constant and the fill it painted are gone; the tab's `BoxDecoration` carries only its top border
  - the green `splashColor` and `highlightColor` overrides are removed, so touch feedback falls back to the platform default rather than tinting the tab green on press
  - `activeLine` remains and still spans the full tab width; the active icon and label keep `brandGreenDark`
  - inactive tabs still draw a transparent border of the same width, so selection does not shift the row
- `lib/module/labtest/lab_section.dart` — `LabBottomBar` matched: no fill, no green ripple, line only
- `test/bottom_nav_test.dart`:
  - the marker case now asserts the inverse of what it did before — **no** tab may paint a background — alongside exactly one tab being capped by the green line
  - the width case keys off the bordered container rather than the removed fill, so "the line spans the tab" is still measured

### Files Modified/Created
**Modified**: `lib/widgets/bottom_nav.dart`, `lib/module/labtest/lab_section.dart`, `test/bottom_nav_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 85/85 passed

---

## 34. Pinned Search Bar and a Live Red Cart Badge (2026-08-19 08:20:00 IST)

**High-level description**: The search field and cart now stay on screen while the home feed scrolls, and the cart icon carries a red count badge that rises as products are added.

- Cart state extracted — `lib/module/cart/cart_service.dart` (new):
  - `CartService` is a `ChangeNotifier` owning the lines, so the badge and the cart screen read one list and cannot disagree
  - `itemCount` totals **units, not lines**: adding the same product twice merges into one line with quantity 2 and reports 2
  - `add` merges by product name rather than appending a duplicate row
  - `changeQty` removes a line when it steps to zero
  - the bill lives here too: subtotal, 26% discount, a delivery fee that is zero on an empty cart, and payable
- Badge — `lib/module/cart/cart_badge.dart` (new):
  - `ListenableBuilder` over `CartService`, so the count updates without the host widget rebuilding
  - red bubble (`#D93025`) with a white ring, hidden entirely at zero, capped at `99+` so a large count cannot outgrow the circle
  - `Stack(clipBehavior: Clip.none)` lets the bubble sit proud of the button's circle
- Pinned header — `lib/screens/home_screen.dart`:
  - the home feed moved from `ListView` to `CustomScrollView`
  - the brand header and hero copy sit in a `SliverToBoxAdapter` and scroll away
  - the search field and cart sit in a `SliverAppBar(pinned: true)`, so they stay at the top at any scroll offset; `scrolledUnderElevation` gives it a shadow only once content is beneath it
  - `primary: false`, because the surrounding `SafeArea` already handles the status-bar inset
- Wiring:
  - `lib/module/home/product_showcase.dart` — ADD now calls `CartService.add`; fixture prices carry grouping separators, so the string is stripped before parsing
  - `lib/module/home/home_header.dart` — its cart button is now the same `CartBadge`
  - `lib/module/cart/cart_screen.dart` — reads and mutates `CartService` instead of a private list; the local `_CartLine` class was deleted
- Behaviour change worth noting:
  - the cart now **starts empty** rather than pre-filled with three fixture lines, so the badge is honest on first launch. Two existing test groups depended on those lines and now seed the cart explicitly.
- Tests — `test/cart_badge_test.dart` (new): unit coverage for unit-vs-line counting, removal at zero, bill maths, and the empty-cart fee; widget coverage for the badge being hidden at zero, appearing with a count, incrementing, capping at `99+`, being red, and the cart screen showing what was added
- Test fixes: `test/auth_test.dart` seeds a cart line because an empty cart hides the checkout bar the gate is attached to; `test/home_screen_test.dart` scopes its cart finder to `HomeHeader` now that a second cart icon exists in the pinned bar

### Files Modified/Created
**Created**: `lib/module/cart/cart_service.dart`, `lib/module/cart/cart_badge.dart`, `test/cart_badge_test.dart`

**Modified**: `lib/screens/home_screen.dart`, `lib/module/cart/cart_screen.dart`, `lib/module/home/product_showcase.dart`, `lib/module/home/home_header.dart`, `test/auth_test.dart`, `test/home_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 96/96 passed

---

## 35. Blue Indicator Line, Standard Width, with a Downward Fade (2026-08-19 08:50:00 IST)

**High-level description**: Recoloured the active-tab marker from green to blue, shortened it to a conventional indicator width, and added a blue wash that fades from the line down across the icon.

- `lib/widgets/bottom_nav.dart`:
  - `activeLine` `brandGreenDeep` → `AppColors.brandBlue`
  - new `indicatorWidth = 32`. The line was previously the container's full-width top border; it is now a centred 32px bar, so it reads as a marker rather than an edge.
  - new `activeFade` — `brandBlue` at 16% — drawn as a `LinearGradient` from the top of the tab down to `_fadeHeight`, which is derived as line + gap + icon row. The wash therefore ends before the label instead of filling the cell.
  - the fade sits behind the column in a `Stack` and is revealed by `AnimatedOpacity`, so it exists on every tab and only the selected one shows it — no layout change on selection
  - the line occupies a fixed-height slot whether or not it is drawn, so selecting a tab still cannot shift the row
  - the active icon and label moved from `brandGreenDark` to `brandBlue`. A green icon beneath a blue line and blue wash would have clashed; the marker and the glyph now agree.
- `lib/module/labtest/lab_section.dart` — `_LabBarItem` given the same short line and fade, reading `activeLine`, `activeFade` and `indicatorWidth` from `ShieldBottomNav` so the two bars stay identical
- Tests in `test/bottom_nav_test.dart`:
  - the marker case now asserts exactly one blue line and that `activeLine` is `brandBlue`
  - a new case asserts the rendered line width equals `indicatorWidth` **and** is narrower than a tab, so "standard size" is measured rather than described
  - a new case asserts the gradient runs top-to-bottom, starts at `activeFade`, and ends transparent — so it genuinely fades instead of banding into a block

### Files Modified/Created
**Modified**: `lib/widgets/bottom_nav.dart`, `lib/module/labtest/lab_section.dart`, `test/bottom_nav_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 97/97 passed

---

## 36. Duplicate Cart Icon Removed (2026-08-19 09:05:00 IST)

**High-level description**: The home screen was showing two cart badges at once — one in the scrolling brand header and one in the pinned search bar, both carrying the same count. The header copy is gone; the single cart lives in the pinned bar, which is what keeps it on screen while scrolling.

- Cause:
  - entry 34 added the badge to the pinned bar and, separately, swapped the header's plain cart button for the same `CartBadge`. Both were then rendering simultaneously at the top of the feed.
- `lib/module/home/home_header.dart`:
  - the `CartBadge` and its spacer removed; the wallet is now the header's trailing action and sits at the right edge
  - `cart_badge.dart` import dropped
  - the class doc records why the cart is deliberately absent, so it does not get re-added
- Kept: the pinned `SliverAppBar` still carries the search field and the one `CartBadge`, so the cart is reachable at any scroll offset
- Tests in `test/home_screen_test.dart`:
  - the old "wallet and cart actions are pinned to the right edge" case is replaced by two cases: one asserting **exactly one** cart icon exists on the whole screen and that it is **not** inside `HomeHeader`, and one asserting the wallet is now the header's right-edge action
  - the first of those is the regression guard: a second badge anywhere would fail it

### Files Modified/Created
**Modified**: `lib/module/home/home_header.dart`, `test/home_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 98/98 passed

---

## 37. Active-Tab Fade Reshaped into a Spreading Beam (2026-08-19 09:25:00 IST)

**High-level description**: The wash under the indicator was a uniform full-width rectangle with a vertical gradient. It is now a beam: as narrow as the line where the two meet, widening to the full tab as it descends, and fading out before the label.

- `lib/widgets/bottom_nav.dart`:
  - new `NavBeamClipper`, a `CustomClipper<Path>` producing a trapezoid — top edge equal to `indicatorWidth` centred, bottom edge the full width of the tab
  - the wash is wrapped in `ClipPath` with that clipper, so the gradient is cut to the beam rather than painting a block
  - `topWidth` is clamped to half the box width, so a tab narrower than the line degrades to a plain rectangle instead of inverting into a bow-tie
  - the gradient moved from two stops to three — `activeFade` at the line, `brandBlue` at 8% mid-way, transparent at the base — so the falloff reads as light spreading rather than a linear ramp
  - `activeFade` strengthened from 16% to 22%, since the beam now covers less area and would otherwise read weaker than before
  - exposed as `activeBeam` so the lab bar and the tests share one definition
- `lib/module/labtest/lab_section.dart` — `_LabBarItem` uses the same clipper and gradient
- Tests in `test/bottom_nav_test.dart`:
  - four geometry cases run the clipper directly and probe its path with `Path.contains`: the top edge is only as wide as the line, the bottom edge reaches both tab edges, a fixed off-centre point is outside high up but inside lower down (proving it widens), and a too-narrow tab still yields a valid shape
  - a widget case asserts each tab's wash is a `ClipPath` carrying a `NavBeamClipper`, so a future edit cannot silently revert it to a rectangle

### Files Modified/Created
**Modified**: `lib/widgets/bottom_nav.dart`, `lib/module/labtest/lab_section.dart`, `test/bottom_nav_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 103/103 passed

---

## 38. Cart Moved Back Beside the Wallet, With the Header Pinned (2026-08-19 09:50:00 IST)

**High-level description**: The cart returned to the header row next to the wallet. To keep it — and the search field — visible while scrolling, the header and search are now pinned together as one block.

- Why the restructure was needed:
  - the cart beside the wallet sits in the brand header, which previously scrolled away
  - the standing requirement is that the search and cart stay visible while the feed scrolls
  - satisfying both means pinning the header itself, not just the search row
- `lib/module/home/home_header.dart` — `CartBadge` restored beside the wallet as the trailing action; doc comment records that the header is pinned, which is what keeps the cart reachable
- `lib/screens/home_screen.dart`:
  - the pinned `SliverAppBar` carrying search + cart is replaced by a `SliverPersistentHeader` whose delegate `_PinnedTopChrome` pins a two-row block: the header (menu, wordmark, wallet, cart, location) above the search field
  - a `SliverAppBar` centres a single toolbar row, so it could not carry a two-row block at a known height; the custom delegate can, and raises a shadow only once content scrolls beneath it
  - the hero copy moved into the scrolling list. It previously sat between the location line and the search, which is the one position that cannot survive pinning both — the pinned block has to be contiguous.
  - the search field's vertical content padding trimmed 18 → 14 to keep the pinned block from growing further
- Defect found by the suite:
  - the block was first given a 148px extent, which the content overflowed by 17px. Fixed at 166px, verified by the suite rather than by eye. The extent is a fixed value against a two-row block, so it is worth re-checking if that block gains content.
- Tests in `test/home_screen_test.dart`:
  - the cart case now asserts there is still exactly one cart, that it is inside `HomeHeader`, that it sits immediately right of the wallet **on the same row** (vertical centres within 1px), and that it is the trailing action
  - a new case asserts the cart is above the search field, so it cannot drift back beside it
  - a new case drags the feed 600px and asserts the header, cart and search are all still present **at an unchanged offset**, which is what proves the block is pinned

### Files Modified/Created
**Modified**: `lib/module/home/home_header.dart`, `lib/screens/home_screen.dart`, `test/home_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 104/104 passed

---

## 39. Address Form Behind "Manage addresses" (2026-08-19 10:20:00 IST)

**High-level description**: "Manage addresses" now opens an address-entry form matching the supplied reference, reachable from both the location sheet and the account menu. The account row was renamed from "Saved Addresses".

- Data — `lib/module/location/address_book.dart` (new):
  - `AddressLabel` enhanced enum (Home / Work / Other) carrying its display text
  - `Address` with pincode, house, area, optional landmark, receiver name, phone, and label; `receiver` collapses to the first name alone when there is no last name, and `summary` joins only the parts that are filled so a missing landmark leaves no stray comma
  - `AddressBook` is a `ChangeNotifier` store; in memory only, written to be replaced by a backend
- Form — `lib/module/location/address_form_screen.dart` (new):
  - search box, an "OR" divider, then a pincode field paired with a "Current Location" button
  - House / Area / Landmark lines, the Home-Work-Other label chips, and a "Receiver details" block
  - two field styles matching the reference: hint-only for the address lines, and always-floating labels for the receiver block, where the label reads as a caption above the value
  - pincode and phone accept digits only and are length-limited at source, so the validators cannot be reached with letters
  - validation on save: 6-digit pincode, house, area, first name, 10-digit phone; landmark and last name stay optional
  - "Save" is a pinned bottom bar, and a successful save stores the address, closes the screen, and confirms with the chosen label
- Wiring:
  - `lib/module/location/location_sheet.dart` — "Manage addresses" closes the sheet **before** pushing, so the form does not sit stacked on top of it
  - `lib/module/account/account_screen.dart` — row renamed "Saved Addresses" → "Manage addresses" and given the same destination; it previously had an empty `onTap`
- Known limitation:
  - the search box and "Current Location" are presentational. There is no geocoding or device-location provider in the project, so "Current Location" says so rather than pretending.
- Tests — `test/address_form_test.dart` (new): store behaviour including the summary join and the no-last-name case; every labelled field from the reference rendering; empty-form validation reporting all five failures at once; a short pincode rejected; a complete form storing the right values with Home as the default; the Work chip changing what is stored; a 320px viewport; and both entry points, including that the location sheet closes rather than stacking

### Files Modified/Created
**Created**: `lib/module/location/address_book.dart`, `lib/module/location/address_form_screen.dart`, `test/address_form_test.dart`

**Modified**: `lib/module/location/location_sheet.dart`, `lib/module/account/account_screen.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 115/115 passed

---

## 40. Collapsing Top Chrome: Search + Cart Survive the Scroll (2026-08-19 11:05:00 IST)

**High-level description**: Scrolling the home feed now collapses the pinned top block down to just the search field and the cart. The cart is drawn at a fixed offset that is identical in both states, so it does not move a pixel as everything around it folds away.

- `lib/screens/home_screen.dart`:
  - `_PinnedTopChrome` (a fixed-height pinned block) replaced by `_CollapsingTopChrome`, `maxExtent` 152 → `minExtent` 62
  - progress `t = (shrinkOffset / (maxExtent - minExtent)).clamp(0, 1)` drives three things at once:
    - `HomeHeader` (menu, wordmark, wallet, location) fades `1 - t` and stops taking taps past the halfway point
    - the search field's top lerps 88 → 1, rising into the space the header vacates
    - the search field's right inset lerps 16 → 60, so once collapsed it stops short of the stationary cart instead of running under it
  - the cart sits in a `Positioned(top: _cartTop, right: 8)` outside everything that animates — this is what holds it still
  - `_cartTop` is derived from `HomeHeader.rowHeight` rather than hardcoded, so the cart centres on the wallet without depending on font metrics
  - the delegate uses `SizedBox.expand()`: the sliver already hands it exactly the extent it should occupy, and computing `maxExtent - shrinkOffset` by hand collapsed to a zero-height box once fully scrolled
- `lib/module/home/home_header.dart`:
  - the half-finished `compact` flag became `showCart` (default `true`); the home screen passes `false` because it draws the cart itself
  - the action row is now wrapped in a fixed `SizedBox(height: HomeHeader.rowHeight)` so an externally-drawn cart can be aligned against it deterministically — without this the wallet sat 3px off the cart under the test font
- Tests — `test/home_screen_test.dart`: the "cart lives inside `HomeHeader`" assertion became a geometric one (same row as the wallet within 1px, to its right, at the right edge), since the cart deliberately no longer descends from the header; the old "pinned block survives scrolling" test became "scrolling collapses the chrome to the search and the cart", asserting the search and cart both remain, the cart's centre is bit-identical before and after a 600px drag, the header's `Opacity` has reached 0, and the search has risen

### Files Modified/Created
**Modified**: `lib/screens/home_screen.dart`, `lib/module/home/home_header.dart`, `test/home_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 115/115 passed

---

## 41. Breathing Room Above the Collapsed Bar (2026-08-19 11:35:00 IST)

**High-level description**: The collapsed top bar sat flush against the top edge. It now keeps a gap above the search field and the cart.

- `lib/screens/home_screen.dart`:
  - `_chromeTopPad` 6 → 12, and `_searchCollapsedTop` is now defined as `_chromeTopPad` rather than a bare `1`, so the search and the cart share one gap value instead of drifting apart when it is tuned
  - the pad applies in **both** states — it feeds the header's padding as well as `_cartTop` — so the cart still does not move as the bar collapses, it simply starts 6px lower than before
  - extents grew to match: `_chromeMinExtent` 62 → 74 (pad, search, pad) and `_chromeMaxExtent` 152 → 158, with `_searchExpandedTop` 88 → 94 following the header down
- Tests — `test/home_screen_test.dart`: the collapse test now also asserts both the search field and the cart sit at least 8px below the viewport's top once collapsed. Measured against `CustomScrollView`, not the `SliverPersistentHeader` — `getTopLeft` needs a `RenderBox` and a sliver is not one.

### Files Modified/Created
**Modified**: `lib/screens/home_screen.dart`, `test/home_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 115/115 passed

---

## 42. Android Host Project and Release APK (2026-08-19 15:05:00 IST)

**High-level description**: `flutter build apk` failed with "unsupported Gradle project" because the project was hand-authored as web-only and had no `android/` directory at all. Scaffolded the Android host project in place and produced a release APK.

- Scaffold — `flutter create --platforms=android --org com.zabnix --project-name shield .`:
  - `--platforms=android` restricts generation to the Android host project, so `lib/`, `test/`, `assets/` and `pubspec.yaml` are untouched. Verified with an md5 manifest of all 60 Dart/config files taken before the command: every one matched afterwards.
  - the applicationId and namespace are `com.zabnix.shield`. `com.example.*` is the default and is rejected by the Play Store, so it was set at creation time rather than patched later.
  - `flutter create` also drops a stub `test/widget_test.dart` (the default counter test, which fails against this app), a `README.md`, and `shield.iml`. All three removed.
- `android/app/src/main/AndroidManifest.xml`:
  - `android:label` "shield" → "SHIELD"
  - `<uses-feature android:name="android.hardware.camera" android:required="false" />` — the prescription upload offers a camera source, and without `required="false"` Android would hide the app from camera-less devices. No `CAMERA` permission is declared: `image_picker` goes through `ACTION_IMAGE_CAPTURE`, and declaring the permission would make it a runtime grant the app does not otherwise need.
- Launcher icon:
  - `flutter_launcher_icons ^0.14.4` added as a dev dependency, configured in `pubspec.yaml` against `assets/logos/shield_mark.png` (4500x4500)
  - adaptive icon: white background, foreground inset 22% so the mark survives the circular mask instead of being cropped at the edges
  - `dart run flutter_launcher_icons` writes the five `mipmap-*` densities, the five `drawable-*` foregrounds, `mipmap-anydpi-v26/ic_launcher.xml`, and a new `values/colors.xml`
- `.gitignore`: added `android/local.properties`, `android/.gradle/`, the per-buildtype output dirs, `android/key.properties`, `*.jks` and `*.keystore`, so no signing material can be committed to the public repo by accident
- Known limitations:
  - **the release build is signed with the debug key.** `flutter create` leaves `signingConfig = signingConfigs.getByName("debug")` under a TODO in `android/app/build.gradle.kts`. The APK installs and runs, but it cannot be published and must not be treated as a release artifact until a real keystore is wired in.
  - the APK is 60.1MB because it is a fat APK carrying all three ABIs on top of ~14MB of image assets. `flutter build apk --split-per-abi` cuts it to roughly a third per device.
  - the Kotlin incremental compiler prints a wall of `IllegalArgumentException: this and base files have different roots` traces during the build. That is the pub cache sitting on `C:` while the project is on `D:`; the build succeeds regardless.

### Files Modified/Created
**Created**: `android/` (host project, 32 files), launcher icon resources under `android/app/src/main/res/`

**Modified**: `pubspec.yaml`, `pubspec.lock`, `.gitignore`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 115/115 passed
- `flutter build apk --release` — built `build/app/outputs/flutter-apk/app-release.apk` (60.1MB)

---

## 43. Grey Backdrop Removed From Product and Category Images (2026-08-19 15:20:00 IST)

**High-level description**: The product cards were already pure white, but the photographs themselves carried a light grey studio sweep baked into the JPEG, so every thumbnail read as a grey rectangle sitting inside a white card. The backdrop is now white in the image files.

- Tool — `tool/strip_product_backgrounds.dart` (new, dev-only; `image ^4.5.4` added to `dev_dependencies`):
  - **The obvious approach does not work here.** A flood fill from the border to transparency was tried first and produced bottles with holes in them: these are white products on a `#EFEFEF` sweep, about 28 units apart in RGB, which is *closer* than the shading within a single bottle. Any tolerance wide enough to clear the sweep also eats the product. Verified by compositing the result over magenta — the immunity bottle's cap was largely gone.
  - What replaced it is the two steps a photographer would take, and neither one cuts anything out:
    1. a levels white point taken at the 2nd percentile of border brightness (not the median — the sweep is vignetted, and a median leaves the corners short of 255), so the whole backdrop clips to pure white while the product keeps its form, since what defines its silhouette is the darker shading at its edges
    2. a flood fill from the border that snaps the remaining near-white fringe — vignette and the outer edge of the drop shadow — to exactly 255. This paints white rather than punching a hole, so a fill that leaks into a white bottle does no damage: it is painting white onto white. That is what makes the tolerance safe to set generously.
  - the product's own drop shadow survives, softened. Deliberate — it grounds the product on the card instead of leaving it floating.
  - output is PNG: JPEG ringing around the product edges would put faint grey speckles back into the flat white this exists to create
  - images are also downscaled to a 512px longest edge. The cards draw them at 114 logical pixels, so the 1024px originals were far larger than anything needed.
- Assets: all 38 `.jpg` files under `assets/products/` and `assets/categories/` replaced by `.png`; **6.0MB → 3.3MB** despite PNG being lossless, because the flat white compresses away and the originals were oversized
- References updated in `lib/module/home/product_showcase.dart` and `lib/module/home/category_section.dart`. Checked both directions afterwards: no `.jpg` reference survives, every referenced PNG exists on disk, and no PNG is left unreferenced.

### Files Modified/Created
**Created**: `tool/strip_product_backgrounds.dart`, 38 PNGs under `assets/products/` and `assets/categories/`

**Deleted**: the 38 source JPEGs

**Modified**: `pubspec.yaml`, `lib/module/home/product_showcase.dart`, `lib/module/home/category_section.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 115/115 passed

---

## 44. Three Closing Blocks for the Home Feed (2026-08-19 15:50:00 IST)

**High-level description**: The home feed ended abruptly on the reviews strip. It now closes with a trust block, a three-step explainer, and a full footer.

- `lib/module/home/why_shield.dart` (new) — "Why shop with SHIELD": four promises (genuine medicines, save up to 51%, free delivery over ₹500, checked by pharmacists), each an icon tile plus a sentence. Laid out as full-width rows rather than a 2×2 grid: a grid fits at 400px but not at 320, and the copy here is a sentence rather than a label.
- `lib/module/home/how_it_works.dart` (new) — "How SHIELD works": a vertical stepper, search/upload → pharmacist checks → delivered. The rail joining one badge to the next is an `Expanded` inside an `IntrinsicHeight` row, so it stretches to whatever the step's copy needs instead of being a guessed fixed height. The last step has no rail.
- `lib/module/home/home_footer.dart` (new) — navy footer: wordmark and tagline, three contact rows, six quick links in a `Wrap` (six never fit one line, and the list will grow), and the legal line.
- `lib/screens/home_screen.dart` — the three blocks replace the bare 20px white spacer that used to end the feed. `AppShell` puts the coupon bar and the nav in `bottomNavigationBar`, outside the body, so the footer needs no extra bottom inset to clear them.
- Honesty about what is not built:
  - the footer links and contact rows have no destinations — there is no content site and no support backend in this project. Each one raises "<name> is coming soon" rather than being a dead tap that looks broken.
  - no phone number, email address or licence number appears anywhere in the footer. Inventing any of those would be inventing a credential or a contact that belongs to someone else. The legal line states the dispensing policy, which is a policy statement rather than a fabricated registration.
  - no second app-download block was added: `AppOfferCard` already carries one mid-feed, and a duplicate would read as filler.
- Tests — `test/home_bottom_test.dart` (new, 10 tests): all four promises present; the steps numbered and in top-to-bottom order; exactly two rails for three steps; every footer link and contact row rendered along with the legal line; tapping a link and tapping a contact row each producing the "coming soon" message; all three blocks at 320px; and, in the assembled feed, the three sitting after the reviews in order with the footer running the full viewport width

### Files Modified/Created
**Created**: `lib/module/home/why_shield.dart`, `lib/module/home/how_it_works.dart`, `lib/module/home/home_footer.dart`, `test/home_bottom_test.dart`

**Modified**: `lib/screens/home_screen.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 125/125 passed

---

## 45. Categories Tab Rebuilt on the Home Strip's Cards (2026-08-19 16:20:00 IST)

**High-level description**: The Categories tab was a list of small circular icons, unrelated to the image cards the home strip already used. It now renders the same cards, from the same data, as tinted panels per group — one heading, a grid of image cards, and a "View all … products ›" link, matching the supplied reference.

- `lib/module/categories/category_catalogue.dart` (new) — the single source of truth behind both surfaces:
  - `SubCategory` (label, icon, optional image, per-item offer line) and `CategoryGroup` (heading, pre-wrapped chip caption, chip artwork, chip tint, panel tint, items)
  - five groups × the sub-categories that actually have artwork: Personal Care, Health Conditions, Vitamins & Supplements, Diabetes Care, then Lab Tests
  - `shoppable` filters Lab Tests out, which is what the home strip offers as chips
  - the offer line moved from a hardcoded 'Up to 50% off' into the data, so a group can vary it the way the reference does
- `lib/module/categories/category_card.dart` (new) — `CategoryCard` lifted verbatim out of the home section, plus `CategoryPanel`, the rounded tinted panel with its closing link. Both now own the layout constants the two callers used to duplicate: `CategoryCard.aspectRatio` and `CategoryPanel.threeColumnWidth`.
- `lib/module/categories/categories_screen.dart` — rewritten: heading, panel, spacer, per group. Roughly 150 lines of duplicated tile widget and hand-kept category list deleted.
- `lib/module/home/category_section.dart` — now draws from the catalogue and renders `CategoryCard`. The chip strip and the panel's square top stay, since that is what lets the active chip merge into the panel below it.
- `lib/theme/app_colors.dart` — the four category pastels and four chip tints, previously inline `Color(0x…)` literals in the home section, promoted to named tokens now that two files need them. Each group's panel colour is unique, which is what separates one panel from the next without a rule between them.
- Honesty about what is not built:
  - there is no catalogue listing behind a category. A card tap and a view-all tap each raise "<name> listing is coming soon" rather than being a dead tap.
  - **Lab Tests has no artwork** and its cards fall back to icons. The project has no photographs for diagnostics, and inventing them was not an option; the group sits last for that reason, and because a test is a booking rather than something you add to a cart.
  - the reference also shows a "Homeopathic Medicine" group. It is not here: there is no artwork for it, and a group of blank cards would be worse than its absence.
- Tests — `test/categories_screen_test.dart` (rewritten, 13 tests):
  - catalogue: every shoppable group has six sub-categories and every one carries an image; Lab Tests is last, excluded from `shoppable`, and is the only group without artwork; every group's panel colour is unique; the view-all label names the group
  - screen: opens on image cards rather than bare icons; every group gets a panel and a link; the Lab Tests tiles; both tap paths producing "coming soon"; a 320px viewport
  - shared: the home strip renders six `CategoryCard`s and offers every shoppable group as a chip, and does not offer Lab Tests
  - the old ordering test compared y positions of all five headings at once, which only passed because the list's cache extent happened to reach the last one. The panels are taller now, so ordering is asserted against the catalogue and the rest of the tests scroll to what they assert.

### Files Modified/Created
**Created**: `lib/module/categories/category_catalogue.dart`, `lib/module/categories/category_card.dart`

**Modified**: `lib/module/categories/categories_screen.dart`, `lib/module/home/category_section.dart`, `lib/theme/app_colors.dart`, `test/categories_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 134/134 passed

---

## 46. Saved Address Drives the Home Location (2026-08-19 16:50:00 IST)

**High-level description**: Saving an address in "Manage addresses" had no visible effect — the home header kept showing the old pincode. The header now shows the saved address's pincode and locality the moment it is saved.

- **Root cause**: the location lived in `_HomeHeaderState._pincode`, set only by the location sheet's return value. `AddressFormScreen` writes to `AddressBook` on another route, which the header never saw. Two owners of one fact.
- `lib/module/location/address_book.dart` — made the single owner of the delivery location:
  - `deliverTo` (the selected address), `pincode`, and `locationLabel`
  - `locationLabel` prefers the saved address's own locality over the city lookup: "682001, Marine Drive" beats "682001, Kochi", because the address is the more specific of the two
  - `add()` also selects — saving an address is a statement about where you want things sent, so it takes effect at once rather than needing a second confirmation
  - `setPincode()` clears the selected address: a bare pincode is a different place, and silently keeping the address under a new pincode would show a locality that no longer applies
  - `removeAt()` clears it too when the deleted entry was the one being delivered to
  - `defaultPincode`, `knownCities` and `describePincode` moved here from `LocationSheet`, since the class that owns the location should own the lookup that describes it. `LocationSheet.knownCities` and `LocationSheet.describe` now delegate, so `clinics_screen.dart` and `lab_test_screen.dart` are untouched.
- `lib/module/home/home_header.dart` — `_pincode` deleted. The location line is a `ListenableBuilder` on `AddressBook.instance`, so it repaints from a notification no matter which route caused it; `_chooseLocation` now writes the sheet's result into the book instead of into local state.
- Tests — `test/address_form_test.dart` (+5): the default label; a saved address naming its own locality rather than the city; a bare pincode replacing the saved address; deleting the delivered-to address falling back to the default; and the full round trip through `AppShell` — location sheet → Manage addresses → fill in → Save → back on home showing "682001, Marine Drive" and no longer "400079, Mumbai".
- `test/location_sheet_test.dart` — needed `setUp`/`tearDown` resets it did not need before. The location is now a singleton rather than per-widget state, so a test that changed it was carrying that change into the next one; two tests failed on exactly that before the resets were added.

### Files Modified/Created
**Modified**: `lib/module/location/address_book.dart`, `lib/module/location/location_sheet.dart`, `lib/module/home/home_header.dart`, `test/address_form_test.dart`, `test/location_sheet_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 139/139 passed

---

## 47. Lab Section Gets Its Own Basket, Package Detail and Patient Count (2026-08-19 17:20:00 IST)

**High-level description**: The lab section's cart icon opened the medicine cart. It now has its own basket, "Book" opens a package detail screen matching the supplied reference, and adding a package asks how many patients it is for and prices the booking per head.

- **The bug**: `lab_test_screen.dart` pushed `CartScreen` from its collection header, so lab and medicine shared one basket and one bill.
- `lib/module/labtest/lab_cart_service.dart` (new) — the lab basket, deliberately separate from `CartService`. A diagnostic booking is a scheduled home visit priced per patient, not a boxed product with a quantity; sharing one basket would mean one delivery fee and one checkout over two things settled in completely different ways.
  - `bookingCount` counts **packages** — two people on one panel is still one thing in the basket and one line on screen — while `patientCount` counts heads, which is what the collection visit has to plan for
  - `book()` replaces rather than appends when the package is already there: booking the same panel twice is a correction to the patient count, not a second visit
  - the count is clamped to 1..5, matching what the sheet offers, so no caller can slip an out-of-range value past it
- `lib/module/labtest/lab_package.dart`:
  - `formatRupees` with Indian digit grouping (1,732 / 1,29,900). The catalogue writes its prices pre-grouped, but a multi-patient booking multiplies them, so any total has to be grouped at runtime.
  - `priceValue` / `mrpValue` parse the grouped strings back to numbers; `discountLabel` derives "60.01% off" from the two rather than being another hand-maintained string that can disagree with them
  - detail fields: `forWhom`, `ageRange`, `preparation`, `sample`, `organs`, `about`, filled in for all three packages
- `lib/module/labtest/lab_package_screen.dart` (new) — the reference's "Product Details": header, the four-fact strip (CONTAINS / PREPARATION / SAMPLE / REPORT IN), the organ chips with View more, price with the discount pill and Add, the coupon card, and About. The fact strip scrolls sideways rather than wrapping — four tiles do not fit at 320px, and a 2×2 grid would break the single row the reference reads as.
- `lib/module/labtest/patient_count_sheet.dart` (new) — "Select number of patients", 1 to 5. **Each row carries the price for that count**, so the cost of another head is visible before the choice rather than after. The confirm button is disabled until a count is picked and reads "Add · ₹3,897", and it reopens on the current count when editing an existing booking.
- `lib/module/labtest/lab_cart_screen.dart` (new) — bookings with their patient count and amount, a bill (tests total, package discount, free home collection, payable, and the head count), and "Select slot" behind `AuthFlow.guard` — the same rule as the medicine cart, where browsing stays open and committing needs an account.
- `lib/module/labtest/lab_cart_badge.dart` (new) — a separate widget from `CartBadge` because it reads a separate basket; the two counts must never appear against each other's icon. Added to the lab landing header and the Top Packages bar.
- `package_card.dart` — "Book" now opens the detail screen instead of doing nothing. It deliberately does not book: the patient count has to be answered first.
- Known limitation: the reference shows a lifestyle photograph in the package header. There is no artwork for the packages in this project, so the tile carries the section's own mark rather than a stand-in photo.
- Tests — `test/lab_cart_test.dart` (new, 20 tests): Indian grouping including the 1,29,900 case; price parsing and the derived discount label; **that booking a test leaves the medicine cart empty and vice versa**; per-patient pricing; re-booking correcting rather than duplicating; packages-vs-heads counting; the 1..5 clamp; savings and payable; the sheet's five rows each showing their own amount; the confirm button disabled until a choice is made; every labelled block on the detail screen; the full Add → 3 patients → basket path including the button changing to "Booked for 3 patients · Change"; the badge counting; the empty state; editing and removing from the basket; and Book opening the detail screen without booking anything.

### Files Modified/Created
**Created**: `lib/module/labtest/lab_cart_service.dart`, `lab_cart_screen.dart`, `lab_cart_badge.dart`, `lab_package_screen.dart`, `patient_count_sheet.dart`, `test/lab_cart_test.dart`

**Modified**: `lib/module/labtest/lab_package.dart`, `lab_test_screen.dart`, `package_card.dart`, `top_packages_screen.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 159/159 passed

---

## 48. Sign-in Offered at Launch, Still Required at Checkout (2026-08-19 17:45:00 IST)

**High-level description**: After the splash, the app now offers the login/register dialog with its close button. The checkout gate is unchanged — both prompts are live, which is what was asked for.

- `lib/screens/root_screen.dart`:
  - when the splash timer fires, the shell is built and then `AuthFlow.show` is raised from a post-frame callback. Post-frame rather than inline so the shell exists first: the dialog goes onto the navigator above a built app, and the app is visible behind it rather than the dialog opening over nothing.
  - a `_prompted` flag makes it once per launch. Signing out later rebuilds `AppShell` through the `ValueListenableBuilder`, but not this state, so dismissing the prompt is not undone by anything done afterwards.
  - an already signed-in member is not asked at all.
- The dialog is unchanged, so the launch prompt is the same small centred card with the same close button as the checkout one — **an offer, not a gate**. Dismissing leaves the whole app browsable as a guest, and `AuthFlow.guard` still stops the checkout.
- This reverses part of entry 34, which moved the prompt to checkout only. Both are wanted now.
- Tests — `test/auth_test.dart`: the launch test that asserted "does not ask for an account" now asserts the dialog appears, plus three new ones — closing it leaves the shell up and the session signed out; a signed-in member is never asked; and a log-in/log-out cycle afterwards does not re-raise it. The existing checkout-gate group is untouched and still passes, which is the evidence the two prompts coexist.

### Files Modified/Created
**Modified**: `lib/screens/root_screen.dart`, `test/auth_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 162/162 passed

---

## 49. Manage Patients, and Choosing One on Upload (2026-08-19 18:05:00 IST)

**High-level description**: The account now has a "Manage patients" section, and the prescription upload asks who the prescription is for.

- `lib/module/patients/patient_book.dart` (new) — `Patient` (name, age, gender, relation) and `PatientBook`, a `ChangeNotifier` singleton. A household orders for more than one person, and both a prescription and a diagnostic booking have to say who they are for; keeping the list in one place means the account screen and the prescription flow can never show different people. `update()` is a no-op on an unknown id rather than silently appending a duplicate.
- `lib/module/patients/patient_form_sheet.dart` (new) — one sheet for both add and edit; the only difference is whether the fields open filled in, which keeps the validation rules from being written twice. Age is digits-only at source and capped at 120, so the validator cannot be reached with letters and an obvious typo is refused.
- `lib/module/patients/manage_patients_screen.dart` (new) — the list with edit and remove, an empty state, and a confirm dialog before removing.
- `lib/module/patients/patient_picker.dart` (new) — the "Prescription is for" row plus its select sheet. An empty book is **not** a dead end mid-flow: "Add a new patient" opens the form and the patient added there is returned as the choice, so it is one pass rather than two.
- `lib/module/account/account_screen.dart` — "Manage patients" added above "My Prescriptions".
- `lib/module/prescription/upload_prescription_screen.dart` — the picker sits above the guidance, and the patient is now required to proceed: a prescription that does not say who it is for cannot be dispensed against.
- Tests — `test/patients_test.dart` (new, 18 tests): store behaviour including unique ids, trimming, in-place update, the unknown-id no-op and targeted removal; the manage screen's empty state, add, validation of both the empty form and an implausible age, edit-in-place without duplicating, and cancel-then-confirm on removal; reachability from the account menu; and on upload — the picker present and unanswered, picking naming the patient, the add-and-choose-in-one-pass path, and that neither a patient nor a file alone unlocks Proceed.

### Files Modified/Created
**Created**: `lib/module/patients/patient_book.dart`, `patient_form_sheet.dart`, `manage_patients_screen.dart`, `patient_picker.dart`, `test/patients_test.dart`

**Modified**: `lib/module/account/account_screen.dart`, `lib/module/prescription/upload_prescription_screen.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — all passed

---

## 50. No More Selling the App to Itself, and a Supply-Length Chooser (2026-08-19 18:30:00 IST)

**High-level description**: The home feed carried an app-download panel and a promo slide selling the app — dead weight when the reader is already inside it. Both replaced with offers they can act on. Separately, the prescription upload now asks how long a supply is needed.

- `lib/module/home/savings_card.dart` (new) — replaces `AppOfferCard`, which is **deleted**. Same slot in the feed, but now the coupon code, what it saves, and the three promises behind it, instead of a phone mockup with an Install button and a download count. The assurances are a `Wrap`: three items of two-line copy overflow a `Row` at 320px, and wrapping beats shrinking the text.
- `lib/module/home/promo_carousel.dart` — the first slide was "Extra Bachat Sirf **App** Par!" with code `TM28APP` and a "Download Now" button. Now "Extra Bachat On Every **Refill**!" with `SHIELD28` and "Order Now". The other two slides were already app-neutral.
- `lib/module/prescription/medicine_duration.dart` (new) — `MedicineDuration`: 1 week, 15 days, 1 month, 2 months, 3 months, each carrying its run in days. A fixed set rather than a free number: a pharmacist dispenses in whole strips and packs, and these are the runs that map onto them.
- `lib/module/prescription/upload_prescription_screen.dart` — a "How much do you need?" chip row below the patient picker, and the duration joins the file and the patient as required to proceed. Chips on the page rather than another sheet: the whole set is five short options, and a sheet would cost a tap to learn nothing new. The confirmation now reads "Prescription for Asha, 1 month · 30 days' supply, submitted for review".
- Note on the copy: the panel does not claim ratings, review counts or download numbers. Those were app-store figures on the old card, and there is no store listing behind them.
- Tests:
  - `test/home_bottom_test.dart` (+2): the savings panel present with its coupon, and a sweep asserting **none** of 'Download App', 'Download Now', 'Install', 'APP EXCLUSIVE OFFER', 'TM28APP', 'App Par' or 'Downloads' survives anywhere in the feed
  - `test/upload_prescription_test.dart` (+4): every option's day count; the supply label; all five chips offered with none pre-picked; exactly one chip in the selected style after tapping; and that a duration alone does not unlock Proceed
  - the narrow-viewport case needed a taller surface — the chips wrap to three rows at 320px, and the lazy list would otherwise never reach the card below them
- Scoping fix: `SHIELD28` now appears twice on home (savings panel and carousel slide), so the panel's assertion is scoped to `SavingsCard` rather than matching by text alone.

### Files Modified/Created
**Created**: `lib/module/home/savings_card.dart`, `lib/module/prescription/medicine_duration.dart`

**Deleted**: `lib/module/home/app_offer_card.dart`

**Modified**: `lib/screens/home_screen.dart`, `lib/module/home/promo_carousel.dart`, `lib/module/prescription/upload_prescription_screen.dart`, `test/home_bottom_test.dart`, `test/upload_prescription_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 187/187 passed

---

## 51. Promo Banner Removed, Prescription Card Moved Under Refer & Earn (2026-08-20 09:30:00 IST)

**High-level description**: The "Shop medicines the right way" banner is gone, and the prescription upload card now sits directly under Refer & Earn with copy that says what to do.

- `lib/module/home/promo_banner.dart` — **deleted**.
- `lib/screens/home_screen.dart` — the `Stack` that layered the banner behind the prescription card is gone with it. The card was only in a `Stack` so it could straddle the banner's lower edge; with no banner it is a plain white block with its own padding, keeping the drop shadow it had. It now follows `ReferEarnCard` immediately.
- `lib/module/home/prescription_card.dart` — the subtitle changed from "to place your order" to **"Upload your prescription here"**. The `MainAxisSize.min` comment referenced the home `Stack`'s `Align`, which no longer exists; it now just says what the constraint is for, since the setting is still needed under any loose constraints.
- Tests — `test/home_screen_test.dart`: "refer & earn card sits in the top section" measured against `PromoBanner` as the block below it, so it now measures against `PrescriptionCard`. A new test asserts the banner copy is gone, that only the block's own padding separates the two cards, and that the new sentence renders.

### Files Modified/Created
**Deleted**: `lib/module/home/promo_banner.dart`

**Modified**: `lib/screens/home_screen.dart`, `lib/module/home/prescription_card.dart`, `test/home_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 188/188 passed

---

## 52. Privilege Programme, and a Wallet That Can Actually Receive It (2026-08-20 10:20:00 IST)

**High-level description**: A card under the home banner opens the Privilege Programme: named cards from ₹10,000 upward in ₹10,000 steps, each crediting the amount plus a 10% bonus into the SHIELD wallet.

- **The wallet had to become real first.** The balance was the string `'₹3,472.00'` hardcoded in three places, and the ledger was a `const` list. A bonus credited into a number that is never shown anywhere would not be a programme at all.
  - `lib/module/wallet/wallet_service.dart` (new) — `ChangeNotifier` holding the balance and a `WalletEntry` ledger, seeded to the previous figures. `topUp` posts the amount and the bonus as **two lines**: the bonus is the whole point of the programme, and rolling it into the top-up would hide the thing the member signed up for.
  - `wallet_screen.dart` — balance, quick top-ups and history all read the service; the top-up chips now credit rather than doing nothing. `account_screen.dart` and `menu_drawer.dart` read the live balance instead of a literal.
- `lib/module/privilege/privilege_tier.dart` (new) — five named cards: **Silver / Gold / Platinum / Titanium / Diamond Shield** at ₹10,000 to ₹50,000. `bonusOn` is 10% **floored** — a bonus is a promise, and the safe direction to round a promise is the one that cannot overstate it. `tierFor` issues arbitrary multiples as a card; above ₹50,000 it keeps the top name rather than inventing one, because the rate is identical and a new name would suggest a benefit that is not there.
- `lib/module/privilege/privilege_screen.dart` (new) — the explainer, the five cards, a custom amount (any multiple of ₹10,000 up to ₹5,00,000, digits-only at source), the terms, and a bar showing what is credited against what is paid. **Activation is behind `AuthFlow.guard`** — it moves money, so it is the same gate the cart uses at checkout.
- `lib/module/privilege/privilege_card.dart` (new) — the home entry point, directly under the hero banner. `wallet_screen.dart` also carries a banner to it, since that is the only place a bonus-bearing top-up can be made.
- `lib/money.dart` (new) — `formatRupees` moved out of `lab_package.dart` now that the wallet needs it. The lab file re-exports it, so `test/lab_cart_test.dart` and every existing caller are untouched.
- Copy is deliberately plain: **every card carries the same 10%** and the screen says so. The tiers differ only in how much is loaded, and implying a rate that scales when it does not would be a lie in the pricing.
- **A bug caught by the tests**: `const _BalanceCard()` inside a `ListenableBuilder` is never rebuilt — Flutter reuses the element when the widget instance is identical, so the balance stayed at the opening figure after a top-up. It now takes `balance` as a parameter, which makes the dependency explicit and the widget genuinely different each build.
- Tests — `test/privilege_test.dart` (new, 21 tests): the amounts and the five names; the 10% rule stated three ways including the brief's own "₹10,000 → ₹1,000"; rounding down on a non-multiple; validity of the step, the floor and the ceiling; custom amounts issued as cards and the top name kept above ₹50,000; Indian grouping on all three labels; the wallet posting two lines with a bonus and one without, and refusing a non-positive top-up; the home card present and opening the screen; every card listed with its bonus; Activate disabled until a card is picked; a custom multiple priced and an off-step amount refused; activation crediting amount **and** bonus; **a guest being stopped at the auth dialog with nothing credited**; and the wallet screen showing the live balance, the bonus line, and updating in place after a quick top-up.

### Files Modified/Created
**Created**: `lib/money.dart`, `lib/module/wallet/wallet_service.dart`, `lib/module/privilege/privilege_tier.dart`, `privilege_screen.dart`, `privilege_card.dart`, `test/privilege_test.dart`

**Modified**: `lib/screens/home_screen.dart`, `lib/module/wallet/wallet_screen.dart`, `lib/module/account/account_screen.dart`, `lib/module/menu/menu_drawer.dart`, `lib/module/labtest/lab_package.dart`

**Verification Commands**:
- `flutter analyze` — no issues found
- `flutter test` — 212/212 passed

---

## 27. Surgicals Group Added and the Category Strip Restyled (2026-08-19 05:05:00 IST)

**High-level description**: Added a fifth shoppable group, fixed the strip's order to the requested list, and replaced the chip-merging-into-panel treatment with a scrolling rail above an inset panel.

- Catalogue — `lib/module/categories/category_catalogue.dart`:
  - new `Surgicals` group: Gloves & Masks, Bandages & Dressings, Syringes & Needles, Supports & Braces, First Aid Kits, Mobility Aids
  - `shoppable` now resolves through an explicit `_stripOrder` list — Vitamins & Supplements, Personal Care, Health Conditions, Diabetes Care, Surgicals — so the rail's order is stated once rather than being an accident of declaration order
  - `withoutArtwork` added, naming the groups whose cards fall back to icons. Lab Tests is permanent; Surgicals is temporary and the constant says so, so the exemption is declared in the data rather than buried in a test.
- Theme — `lib/theme/app_colors.dart`:
  - `panelSlate` and `chipSlateTint` added. Surgicals initially reused `pageTint`, which collided with Lab Tests and broke the existing "every group has its own panel colour" invariant.
- Restyle — `lib/module/home/category_section.dart`:
  - the fixed `Row` of equal-width chips became a horizontally scrolling rail of `_CategoryPill` cards. Five groups cannot share a phone's width as equal columns; at 400px they would have been roughly 72px each, narrower than the artwork.
  - a pill is artwork over a caption in a rounded card: selected gets a white fill with a brand-blue outline and blue caption, unselected a tinted fill. The artwork sits in a fixed 54px box and the caption in a fixed 32px box, so one- and two-line captions keep a common baseline across the rail.
  - the panel is now inset with a 16px margin and rounded on all corners, reading as a block belonging to the selected pill rather than a full-bleed band the chip merges into
  - the opening group is resolved by name (`_initialGroup = 'Personal Care'`) instead of a bare index. The previous `_selected = 1` silently pointed at a different group the moment the strip order changed.
- Defect found during the pass:
  - the pill overflowed by 1.2px: its 1.6px border adds 3.2px of height that the rail's 116px box did not account for. Rail height raised to 122.
- Test corrections — `test/categories_screen_test.dart`:
  - the artwork invariant now skips groups listed in `withoutArtwork`, and a new test asserts that list stays honest: a group may only appear there while every one of its items genuinely has no image
  - "lab tests is … the one group without artwork" renamed and narrowed to "lab tests is last and is not shoppable", since that claim is no longer true
  - the opening-chip assertion moved from Pain Relief to Skin Care to match the new default
  - the every-chip-present test runs at 640px wide; at phone width the trailing chips scroll out of view and are never built

### Files Modified/Created
**Modified**: `lib/module/categories/category_catalogue.dart`, `lib/theme/app_colors.dart`, `lib/module/home/category_section.dart`, `test/categories_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — clean apart from a pre-existing unused import in `test/home_bottom_test.dart`
- `flutter test` — 215/215 passed

---

## 28. Home Feed Extended with Six Showcases, Health Articles, and a Ratings Block (2026-08-19 05:40:00 IST)

**High-level description**: Added the requested bottom-of-feed sections. The three existing showcases were retitled to the requested names rather than duplicated alongside them, three new catalogues were added, and two new blocks close the feed.

- Sections now closing the feed, in order: Vitamins & Supplements, Popular Items, Diabetes Care, Health Conditions, Deals You'll Love, New Product Arrivals, Health Articles, Ratings & Reviews
- `lib/module/home/product_showcase.dart`:
  - three new catalogues — `vitamins`, `diabetesCare`, `healthConditions` — reusing the product photography already on disk where it exists and falling back to icons where it does not
  - the existing `newArrivals`, `bestSellers` and `dealsOfTheDay` catalogues now sit behind the requested titles: New Product Arrivals, Popular Items, and Deals You'll Love. Adding new sections with those names would have shown the same products twice under different headings.
- `lib/module/home/health_articles.dart` (new): five editorial cards carrying topic, headline, and read time, each on its own panel tint
- `lib/module/home/customer_testimonials.dart` (new): aggregate score with a five-level star breakdown, followed by written reviews with avatar, location, posted date, star rating, and verified marker
- Naming collision found and resolved:
  - the block was first titled "What our customers have to say", which the existing video-review reel already uses. Two identical headings appeared in one feed. The new block is titled "Ratings & Reviews" instead — it is the written-and-rated view of the same subject, and the reel keeps the original heading.
- Deliberate restraint on the rating block:
  - the request described it as "like a Google review". It reproduces that familiar pattern — large score, stars, per-level distribution bars, total count — but carries no Google branding or attribution. These are fixtures, and presenting them as verified third-party reviews would misrepresent them.
- Test corrections, all caused by this change rather than pre-existing faults:
  - `home_screen_test.dart` — retitled sections, showcase count 3 → 6, viewports 4200 → 7000 to reach the lengthened feed
  - `home_bottom_test.dart` — viewport 6000 → 8000 for the same reason
  - `cart_badge_test.dart` and `auth_test.dart` — both scroll to the first showcase to reach an ADD button; retargeted from "New on SHIELD" to "Vitamins & Supplements", which is now the first
  - two new cases: every requested section is present, and the ratings block exposes a score with a five-level breakdown whose shares are all within 0..1

### Files Modified/Created
**Created**: `lib/module/home/health_articles.dart`, `lib/module/home/customer_testimonials.dart`

**Modified**: `lib/module/home/product_showcase.dart`, `lib/screens/home_screen.dart`, `test/home_screen_test.dart`, `test/home_bottom_test.dart`, `test/cart_badge_test.dart`, `test/auth_test.dart`

**Verification Commands**:
- `flutter analyze` — clean apart from a pre-existing unused import in `test/home_bottom_test.dart`
- `flutter test` — 217/217 passed

---

## 29. Sub-Category Product Listing with Top Deals and a Sticky Cart Bar (2026-08-19 06:20:00 IST)

**High-level description**: Tapping a sub-category card now opens a product listing built to the supplied references: banner, circular sub-category rail, product grid with cart controls, a Top deals panel, a floating filter pill, and a sticky cart bar.

- `lib/module/categories/listing_catalogue.dart` (new):
  - curated product sets for Skin Care, Hair Care and Oral Care, matching the stock shown in the references
  - every other sub-category falls back to generated entries that carry the section's own name, so a listing never shows stock unrelated to the card that opened it
  - `forGroup` backs the "All" chip; `topDeals` ranks by discount and caps at five
- `lib/module/categories/category_listing_screen.dart` (new):
  - app bar with back, group title, search, and a cart circle carrying the live item count
  - gradient banner, then a rail of circular chips — "All" plus every sub-category — with the brand underline marking the active one
  - two-column grid; each tile carries a corner discount flag, artwork, name, struck MRP, price, and a cart control that is an ADD button until the product is in the cart and a quantity stepper afterwards
  - Top deals panel with a featured card and a thumbnail rail for switching between the discounted stock
  - floating Filter pill and a sticky cart bar showing subtotal, item count, and View cart. The bar renders nothing while the cart is empty rather than sitting there dead.
  - all cart state goes through the existing `CartService`, so the badge, this listing, and the cart screen stay in step
- Wiring:
  - `categories_screen.dart` — the placeholder `_announce` snackbar, which said the listing was "coming soon", is replaced by real navigation; the view-all link opens the group on its All chip
  - `category_section.dart` — home-strip cards now open the listing too
- Defect found during the pass:
  - the grid tile overflowed 6.5px at 320px width. Cell ratio moved 0.58 → 0.52 and the product name became `Flexible`, so it drops to one line under pressure instead of pushing the price and cart control out of the tile.
- Test corrections:
  - two `categories_screen_test.dart` cases asserted the "coming soon" snackbar and now assert navigation instead
  - the view-all case asserts the All chip rather than Top deals: the All listing carries 24 products, so the deals panel sits far past the fold and is never built at that viewport
- Tests — `test/category_listing_test.dart` (new): curated versus generated stock, the All view spanning the group, deal ranking and cap, the screen opening on the tapped chip, chip switching swapping products, ADD reaching the shared cart, the stepper replacing ADD, navigation from the Categories tab, and a 320px viewport

### Files Modified/Created
**Created**: `lib/module/categories/listing_catalogue.dart`, `lib/module/categories/category_listing_screen.dart`, `test/category_listing_test.dart`

**Modified**: `lib/module/categories/categories_screen.dart`, `lib/module/home/category_section.dart`, `test/categories_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — clean apart from a pre-existing unused import in `test/home_bottom_test.dart`
- `flutter test` — 227/227 passed

---

## 30. Header Reduced to the Mark Alone (2026-08-19 06:45:00 IST)

**High-level description**: Removed the "SHIELD" wordmark from the home header and sized the logo to match the menu glyph beside it.

- `lib/module/home/home_header.dart`:
  - the `Expanded` `Text('SHIELD')` is gone; the header row is now menu, mark, then the wallet and cart actions
  - the mark drops 34 → 26, matching `Icons.menu_rounded`'s glyph size rather than the icon button's 40px tap target, so the two read as the same size
  - the gap between menu and mark tightened 6 → 4 now that no wordmark follows
  - a `Spacer` replaces the removed `Expanded`. That text was doubling as the row's flexible child; without a replacement the wallet and cart would have collapsed leftwards against the mark, which is the same right-pinning defect recorded in entry 7.
- Test added to `test/home_screen_test.dart`:
  - asserts no "SHIELD" text remains inside `HomeHeader`, and that the mark's rendered height equals the menu glyph's, so a future size change to either cannot silently unbalance the pair
  - the existing cart-position test already covers the right-edge pinning the `Spacer` restores, and passed unchanged

### Files Modified/Created
**Modified**: `lib/module/home/home_header.dart`, `test/home_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — clean apart from a pre-existing unused import in `test/home_bottom_test.dart`
- `flutter test` — 228/228 passed

---

## 53. Login Rebuilt as Name → Number → OTP, and the App Put Behind It (2026-08-20 15:10:00 IST)

**High-level description**: Replaced the username/password dialog with a progressive OTP sign-in — the name is asked first, filling it reveals the mobile number, and a valid number sends a six-digit code — and turned the launch prompt from an offer into a gate, so nothing in the app is reachable without a session.

- `lib/module/auth/auth_service.dart` (rewritten):
  - `AuthUser` is now `{name, phone}`; `username` and the password map are gone. Identity is the number, because that is what a code is sent to and what a backend would key the account on. `initials` and `displayPhone` moved here so the account card and the menu strip stop deriving them separately.
  - the API is the two calls a real gateway has: `requestOtp({name, phone})` holds a half-finished sign-in, `verifyOtp(code)` completes it. `cancelOtp` drops it when the member goes back to edit their details.
  - `demoOtp` is `123456` and is the only code accepted. It is a stand-in, and the class carries the security note saying so — it is compiled into the bundle and must be swapped for the provider's verify call.
  - `validateName` / `validatePhone` are static and shared: the screen uses them for the field validators *and* to decide whether the number field is revealed, so the reveal and the validation can never disagree.
  - `signInAs()` is a `@visibleForTesting` hook, replacing the seeded-account login that five other test files were using to get a session.
- `lib/module/auth/login_screen.dart` (new, replaces `auth_dialog.dart`):
  - one screen, two steps. The number field is inside an `AnimatedSize` keyed off the name being valid, so it grows into place rather than sitting greyed out — one question at a time, and the growth is what signals progress.
  - the code step replaces the details in place through an `AnimatedSwitcher`; `PopScope` turns the system back gesture there into "return to the details" instead of leaving the app.
  - a filled sixth box submits itself, so the usual case needs no button tap. A wrong code paints the boxes red and leaves the request live — retyping is enough, the number does not have to be entered again.
  - resend is withheld for 30s behind a countdown, then offered. The code is announced in a snackbar and repeated in a hint card, because there is no SMS behind this build.
  - the sent-code snackbar is dismissed on success: `ScaffoldMessenger` queues, and leaving it up would hold back whatever the next screen has to say — which is exactly what swallowed the checkout confirmation the first time through.
- `lib/module/auth/otp_field.dart` (new): six boxes with one real, invisible `TextField` stretched over them. Six separate inputs is the obvious build and the wrong one — paste, backspace across a boundary, and SMS autofill all break. The boxes are decoration; the field owns the value.
- `lib/module/auth/auth_widgets.dart`: `AuthField` gained `prefixText` (the `+91` lockup) and capitalisation; `AuthButton` gained a disabled and a busy state; `AuthError` became `AuthErrorNote` beside the shared `authDanger` colour. `AuthHeader`/`AuthSwitch` went with the dialog.
- `lib/screens/root_screen.dart`: the post-frame `showDialog` is gone. Splash, then `LoginScreen` while `currentUser` is null, then `AppShell` — driven by the notifier rather than a pushed route, which is what makes signing out anywhere in the app drop straight back to the gate.
- `lib/module/auth/auth_flow.dart`: `guard` stays and now pushes the login screen full-screen. Below a gate it never fires, but the money-moving actions (checkout, privilege activation) must not run against an empty session if a route is ever reached another way.
- `lib/module/account/account_screen.dart` and `lib/module/menu/menu_drawer.dart`: the hard-coded `RN` monogram and `9400525063` now come from the session, which is only possible because the name is collected at the door.
- Defect found during the pass:
  - the resend row overflowed 81px under the test font. It was a `Row`; it is a `Wrap` now, so the prompt and the link stack instead of running off the edge at a large text scale.
- Tests — `test/auth_test.dart` rewritten around the new flow: the request/verify pair, a wrong code leaving the request alive, verifying with nothing pending, trimming, the validators, and `initials`; the gate showing the login screen rather than the app and carrying no dismiss affordance, an existing session skipping it, signing out returning to it, and signing in opening the app; the number field hidden until the name is usable and staying hidden for a name too short, `Get OTP` refusing a half-typed number, self-submission on the sixth digit, a wrong code holding the step, "Change details" keeping the name, and resend appearing only after the countdown.
  - `menu_drawer_test.dart` asserts the session's number instead of the literal that is no longer in the source; the five files that logged in with the seeded account now call `signInAs()`.

### Files Modified/Created
**Created**: `lib/module/auth/login_screen.dart`, `lib/module/auth/otp_field.dart`

**Deleted**: `lib/module/auth/auth_dialog.dart`

**Modified**: `lib/module/auth/auth_service.dart`, `lib/module/auth/auth_flow.dart`, `lib/module/auth/auth_widgets.dart`, `lib/screens/root_screen.dart`, `lib/module/account/account_screen.dart`, `lib/module/menu/menu_drawer.dart`, `test/auth_test.dart`, `test/menu_drawer_test.dart`, `test/bottom_nav_test.dart`, `test/patients_test.dart`, `test/privilege_test.dart`, `test/address_form_test.dart`

**Verification Commands**:
- `flutter analyze` — clean apart from a pre-existing unused import in `test/home_bottom_test.dart`
- `flutter test test/auth_test.dart` — 28/28 passed

## 54. Registration, Store Assignment, and the Reward That Pays For It (2026-08-20 17:40:00 IST)

**High-level description**: Added a registration form — profile, address, and the SHIELD branch that will serve the member — offered from the home feed, the account page, and payment checkout, with a close and a skip on every route into it, and 500 reward points credited on completion.

- `lib/module/registration/shield_store.dart` (new): ten outlets, and `nearest(pincode)`. There is no geocoding in this build, so proximity is read off the pincode itself — Indian codes are allocated by region, so the more leading digits two share the closer they are, and ties break on plain numeric distance. 679322 and 676121 share "67" and are both in Malappuram; 679322 and 400079 share nothing. `suggestFor` returns null below six digits: an incomplete code must not silently assign a branch.
- `lib/module/registration/registration_service.dart` (new): `Registration` holds name, phone, email, gender, DOB, address, place, pincode, state and the store id — held by id rather than by object so a change to the directory cannot leave a stale copy behind. `save` credits `rewardPoints` on the first completion only; editing is not a second reward. `dismissPrompt` records a skip.
  - `openingPoints` is 1,240, the figure the menu dashboard had hardcoded. The tile now reads the live balance, because a banner that promises points beside a dashboard that never moves is not a promise.
- `lib/module/registration/registration_screen.dart` (new): three cards — about you, where you are, your SHIELD store.
  - The name and number arrive from the session; the number is read-only with a verified tick, since it is what the OTP was sent to and editing it here would put the profile and the session out of step.
  - Gender is three pills, DOB is a picker behind a read-only field — typing a date invites every format under the sun — and state is a bottom sheet over the 36 states and union territories rather than a dropdown.
  - The store list re-ranks live as the pincode is typed and pre-selects the nearest, tagged "Nearest". Once the member picks a branch by hand, a later pincode edit re-ranks the list but leaves their choice alone. Four are shown; the rest are one tap away.
  - The controls that are not text fields (gender, DOB, state, store) carry their own error line, so a refused submit names all eight missing answers at once instead of the three the `Form` knows about.
- `lib/module/registration/registration_flow.dart` (new): `show` pushes the form; `offerThen` offers it once and runs the action either way. Checkout uses the latter — refusing to take a member's money because they would not give an email is not a trade-off worth making.
- Entry points:
  - `lib/module/home/register_reward_card.dart` (new) closes the home feed directly above the footer, reading "Register now, earn reward points". It carries its own × so the prompt can be refused without opening the form to refuse it, and removes itself once registered or dismissed.
  - `lib/module/account/account_screen.dart`: a banner under the profile card, and a "Registration details" row. The banner survives a skip, unlike the home card — the account page is where someone goes looking for their details, and hiding the way in would leave the reward unreachable for the session. The profile card gained the assigned store, and Edit now opens the form.
  - `lib/module/cart/cart_screen.dart`: checkout is auth-gated then registration-offered. An account is required; registration is not.
- Consolidation done on the way through:
  - `AuthField` was about to be duplicated field-for-field by the registration form, so it moved to `lib/widgets/labelled_field.dart` as `LabelledField`, alongside `shieldFieldDecoration` — which the state field also uses, so a dropdown and a text field in the same form cannot drift apart. It gained `readOnly`, `onTap`, `maxLines` and `suffix` for the locked number and the date picker.
  - The error red was a literal in two auth files; it is `AppColors.danger` now, with its tint and line.
- Defect found during the pass:
  - `_submit` popped unconditionally, which asserts when the form is the whole route rather than a pushed one. Guarded with `canPop`, the same way the login screen closes.
- Tests — `test/registration_test.dart` (new): the pincode ranking and its refusal to guess below six digits, store lookup by id, the reward crediting once and only once, a skip earning nothing; the form asking for all ten things, the number arriving locked and verified, an empty submit naming every miss, a malformed email refused, the nearest branch pre-selected and labelled, the full list behind the toggle, a completed form assigning the store, a hand-picked branch surviving a pincode change, close and skip both leaving without registering, and editing prefilling without the reward copy; the home card's wording, its dismissal, its absence once registered, and its position between How-it-works and the footer; the account banner surviving a skip and giving way to the store name; and checkout offering the form, proceeding after a skip, proceeding after a registration, and not asking a registered member at all.
  - `auth_test.dart`'s checkout cases stand the registration prompt down in `pumpCart`: those cases are about the auth gate, and a second prompt in the way would make them about two things.

### Files Modified/Created
**Created**: `lib/module/registration/shield_store.dart`, `lib/module/registration/registration_service.dart`, `lib/module/registration/registration_screen.dart`, `lib/module/registration/registration_flow.dart`, `lib/module/home/register_reward_card.dart`, `lib/widgets/labelled_field.dart`, `test/registration_test.dart`

**Modified**: `lib/screens/home_screen.dart`, `lib/module/account/account_screen.dart`, `lib/module/cart/cart_screen.dart`, `lib/module/menu/menu_drawer.dart`, `lib/theme/app_colors.dart`, `lib/module/auth/auth_widgets.dart`, `lib/module/auth/otp_field.dart`, `lib/module/auth/login_screen.dart`, `test/auth_test.dart`

**Verification Commands**:
- `flutter analyze` — clean apart from a pre-existing unused import in `test/home_bottom_test.dart`
- `flutter test` — 270/270 passed

## 55. The Coupon Strip Becomes the Registration Strip (2026-08-20 18:25:00 IST)

**High-level description**: Replaced the sticky coupon promo above the bottom navigation with the registration offer — "Register now & get 500 reward points" — and dropped the in-feed card that would otherwise have made the same offer twice on one screen.

- `lib/module/registration/register_bar.dart` (new), replacing `lib/widgets/coupon_bar.dart`:
  - same geometry as the strip it replaces, so the shell's chrome height and layout are unchanged: white circle glyph, one line of copy, a white action button.
  - the whole strip is tappable, not just the button, and it carries a close. Pinned chrome has to be refusable or it is simply in the way on every screen for the rest of the session.
  - it reads `RegistrationService.shouldPrompt`, so dismissing it here, on the account banner, or by skipping the form is the one decision — and once it is refused it collapses to zero height rather than holding a band of the screen.
  - Why the swap is worth making at all: `Apply` on the coupon set a bool and showed "Coupon applied" — there is no discount behind it and nothing in the app changed. The reward points are real state this strip can actually move, so the most persistent surface in the app now carries something that happens when it is tapped.
- `lib/screens/app_shell.dart`: `_couponVisible` is gone with it. The strip owns its own visibility now, which is what lets the same dismissal reach it from three different screens.
- `lib/screens/home_screen.dart`: `RegisterRewardCard` removed from the feed and deleted. It sat directly above the footer, which is exactly where the sticky strip is pinned — scrolling to the end of home would have shown the same offer stacked on itself. One offer, in the more prominent of the two slots.
- Defect found during the pass:
  - the new strip put a second `Icons.close_rounded` into the shell, which made `find.byIcon(Icons.close_rounded)` ambiguous for the drawer and the location sheet. Both tests now scope the finder to the surface they mean, which is what they were always describing.
- Tests — the `home prompt` group in `test/registration_test.dart` became `sticky prompt`: the copy and the action, the close collapsing it to zero height without opening the form, a registered member never seeing it, its position above `ShieldBottomNav` in the real shell, and the absence of the coupon copy it replaced.
  - `lab_section_test.dart` asserted the lab section drops the promo strip with the rest of the main chrome; it asserts the same of `RegisterBar`.

### Files Modified/Created
**Created**: `lib/module/registration/register_bar.dart`

**Deleted**: `lib/widgets/coupon_bar.dart`, `lib/module/home/register_reward_card.dart`

**Modified**: `lib/screens/app_shell.dart`, `lib/screens/home_screen.dart`, `test/registration_test.dart`, `test/lab_section_test.dart`, `test/menu_drawer_test.dart`, `test/location_sheet_test.dart`

**Verification Commands**:
- `flutter analyze` — clean apart from a pre-existing unused import in `test/home_bottom_test.dart`
- `flutter test -j 2` — 271/271 passed

## 56. Product Artwork Given a Square Box (2026-08-20 18:55:00 IST)

**High-level description**: Enlarged the product images on the category listing tiles and the home showcase cards by giving the artwork a square box, which is what the assets actually are.

- Root cause: every file in `assets/products/` is 512x512, and every product card contained it in a box wider than it was tall. `BoxFit.contain` is limited by the short side, so a 166x143 box rendered a 143x143 image with a 23px gutter down either edge. The image was not small because it was scaled down — it was small because the box was the wrong shape, and the tile was paying for a band of empty space on both sides of it.
- `lib/module/categories/category_listing_screen.dart`:
  - the grid tile's artwork is an `AspectRatio(1)` spanning the tile width, and the details below it sit in `ProductTile.detailsExtent` — a fixed 138.
  - the grid moved from `childAspectRatio: 0.52` to `mainAxisExtent: columnWidth + detailsExtent`. One ratio for the whole tile cannot express "a square plus a constant": the name, pack, pricing and cart control need the same height at every width, so a ratio starves them on a narrow phone and leaves dead space on a wide one. That dead space was the other half of why the image looked small.
  - measured: at 400px the artwork box goes 143 -> 180 (+26%, +58% area) and the tile is *shorter*, 350 -> 320. At 320px, 124 -> 140. At 430px, 195.
  - `_FeaturedDeal`'s artwork went 108 wide with 12 of padding to 124 with 10, so the square is limited by the row height rather than by its own box: 84 -> 104.
- `lib/module/home/product_showcase.dart`: the same fix on the horizontal strip. The image box was 114 tall inside a 162-wide card, so a square asset rendered at 102x102 with 24px gutters. `AspectRatio(1)` takes it to 148x148 — **+45% linear, +110% area** — and the strip grew 276 -> 302 to hold it. Both figures are now named constants on `_ProductCard` rather than magic numbers that have to be kept in step by hand.
- Fallback icons went 46/48 -> 56 to stay proportionate to the bigger box.
- Defect found during the pass:
  - the first regression assertion said the artwork is "the larger half of the tile", which fails at 320px where the column (140) is exactly the details extent (140). The invariant is that the artwork is never the *smaller* half — larger wherever a column is wider than the details extent, exactly half on the narrowest phones — and the test says that now.
- Tests — `category_listing_test.dart` asserts the artwork box is square and spans the tile width, at 400px and again at 320px; `home_screen_test.dart` asserts the same of the showcase card. Both would have caught the original letterboxing, since a non-square box is exactly what they refuse.

### Files Modified/Created
**Modified**: `lib/module/categories/category_listing_screen.dart`, `lib/module/home/product_showcase.dart`, `test/category_listing_test.dart`, `test/home_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — clean of anything from this pass
- `flutter test -j 2` — 275/275 passed

## 57. Bottom Bar Selection Marked in Ink, Not in Light (2026-08-20 19:30:00 IST)

**High-level description**: Removed the glow behind the active bottom-navigation tab and put the whole selected state into the label and icon instead — brand blue and heavy against muted and regular.

- `lib/widgets/bottom_nav.dart`:
  - `activeFade`, `activeBeam`, `_fadeHeight`, the per-tab `AnimatedOpacity`/`ClipPath` wash and the `NavBeamClipper` class are all gone. With the wash removed the tab no longer needs a `Stack` at all, so it is a plain `Column`.
  - the selected label went `w600` -> `w800` and the unselected slate went `textBody` -> `textMuted`. Two weight steps rather than one: at 11px a single step is not enough to pick the selected tab out without comparing it against its neighbours, which is the whole job.
  - the short indicator line stays. It is a crisp 32px marker, not light — and with the wash gone it is the only thing above the icon row.
- `lib/module/labtest/lab_section.dart`: the lab section's bar drew the same beam, so it got the same treatment — one bar replaces the other on screen, and a glow surviving on only one of them would read as a rendering fault.
- Tests — `bottom_nav_test.dart` lost the four `NavBeamClipper` geometry cases and the two that asserted the fade and the clip. In their place:
  - nothing in the bar paints a gradient and no `ClipPath` survives, so the wash cannot come back unnoticed. Scanning for `DecoratedBox` is enough to catch every painted decoration, since `Container` and `AnimatedContainer` both build one.
  - the selected label is blue and `w800` while every other tab is muted and `w500`, and it out-weighs each of them.
  - the treatment follows the tab that is tapped, rather than being pinned to Home.

### Files Modified/Created
**Modified**: `lib/widgets/bottom_nav.dart`, `lib/module/labtest/lab_section.dart`, `test/bottom_nav_test.dart`

**Verification Commands**:
- `flutter analyze` — clean of anything from this pass
- `flutter test -j 2` — 272/272 passed

## 58. The Brand Claim Moved to a Sign-Off, with Real Social Marks (2026-08-20 20:15:00 IST)

**High-level description**: Moved "World's first smart clinic integrated pharmacy" from mid-feed to the close of the home feed and reset it as a centred sign-off — watermark, claim, three brand-blue social discs — matching the reference layout.

- `lib/module/home/brand_quote.dart`: the navy gradient panel with its glows and oversized quote glyph is gone. In its place: the mark held back to a watermark at 32% opacity, the claim centred and large in a soft brand blue on the page tint, the support line under it, and the social discs. No panel, no border, no shadow — at the end of a long scroll the job is to leave the claim behind, not to compete with the shelves above it. The size steps 30 / 27 / 24 with the width so a 45-character claim does not break into a stack of short lines on a small handset.
- `lib/screens/home_screen.dart`: it moved out from between the reviews and the category strip, and now sits between How-it-works and the footer.
- `lib/widgets/social_glyphs.dart` (new): Facebook, YouTube and Instagram drawn as paths on a 24x24 grid, white on a brand-blue disc.
  - Why paths and not icons: the Material set carries no YouTube or Instagram glyph. The footer had been standing in a camera for Instagram and a play button for YouTube, and a camera does not read as Instagram. One grid and one stroke weight also keeps the three optically consistent, which three borrowed glyphs would not be.
  - YouTube is the screen with the triangle cut out of it via `PathOperation.difference`, so the disc shows through the play shape as it does in the real mark, rather than being painted over in a guessed blue.
- `lib/module/home/home_footer.dart`: the "Follow SHIELD" row and its `_SocialButton` are gone. The same three destinations sitting as labelled pills in the footer and as discs immediately above it is the same duplication the register card had.
- Defect found during the pass:
  - two of the new cases could not find `HomeFooter` at all. The feed has grown past a 7000px test viewport — the square product artwork added height to six showcase strips and the sign-off added its own — and a sliver list does not build what is far below the fold. Both now pump at 8000, the height `home_bottom_test.dart` already uses for the same reason.
- Tests — `home_screen_test.dart`: the claim now closes the feed (below the category strip and How-it-works, above the footer) rather than interrupting it; the sign-off carries exactly three discs in Facebook, YouTube, Instagram order; and the footer no longer names any of the three while keeping everything else it had.

### Files Modified/Created
**Created**: `lib/widgets/social_glyphs.dart`

**Modified**: `lib/module/home/brand_quote.dart`, `lib/module/home/home_footer.dart`, `lib/screens/home_screen.dart`, `test/home_screen_test.dart`

**Verification Commands**:
- `flutter analyze` — clean of anything from this pass
- `flutter test -j 2` — 273/273 passed

## 59. Patient Form Reformatted: Number, Date of Birth and ABHA (2026-08-20 21:20:00 IST)

**High-level description**: Reset the add-patient sheet to name, mobile number, date of birth, gender, ABHA ID, relation — replacing the typed age with a picked date and adding the two fields the form had been missing.

- `lib/module/patients/patient_book.dart`:
  - `age` is no longer stored. A `dob` is, and the age is derived from it — an age recorded once is wrong from the next birthday onwards, and a lab reference range is read against the age on the day of the test, not the day of the entry. `summary` reads the same as before because it now asks for the derived value.
  - `phone` is required: reports and delivery updates for a patient go there, which is why it is asked for even when the account holder is the patient.
  - `abhaId` holds the 14 digits, or nothing. Optional by design — an account without an ABHA number must still be usable — and stored as digits so a number typed with or without its grouping dashes is the same number. `abhaLabel` prints it back as `12-3456-7890-1234`.
- `lib/dates.dart` (new): `formatDate` and `ageInYears`, shared by the patient book and registration, which had its own copy of the same month table. `ageInYears` counts the birthday rather than the year difference — someone born in December is still the younger age until December comes round. `Registration.formatDate` stays as an entry point and delegates.
- `lib/module/patients/patient_form_sheet.dart`:
  - the fields are in the order asked for, and a test pins that order by comparing their vertical positions rather than trusting the source to stay in step.
  - the date is a read-only field opening a picker. A typed date invites every format under the sun, and the age is derived from it rather than asked for, so it has to be exact. It has no validator of its own, so a `_submitted` flag lets it report alongside the fields that do.
  - the mobile number reuses `AuthService.validatePhone`. A number the app accepts at sign-in cannot be refused here.
  - `AbhaNumberFormatter` groups the number 2-4-4-4 as it is typed. The caret parks at the end after each edit: mapping it across inserted dashes is more machinery than a 14-digit identifier typed straight through is worth, and the comment says so.
  - a blank ABHA passes; a half-typed one does not.
- `lib/module/patients/manage_patients_screen.dart`: the row gained a second muted line with the number, and the ABHA when there is one. Fields that can be entered and never seen again are fields nobody trusts.
- Defects found during the pass:
  - the ABHA hint is a sample number in the same grouped form, so asserting on the rendered text matched the hint as well as the value. The case reads the controller instead.
  - the edit case accepted the date picker and expected 25, but in edit mode the picker opens on the patient's own date, so accepting it changes nothing. It edits the name instead and asserts the date rode through untouched, which is what "updates in place" was there to prove.
- Tests — `patients_test.dart`: the age derived from the date and the birthday counted correctly, an ABHA stored as digits and shown in groups, a patient without one; the six fields in the specified order, the grouping formatter, a refused half-ABHA followed by an accepted blank one, a bad mobile number refused, the empty form naming all three missing answers, and the row showing the number and ABHA.

### Files Modified/Created
**Created**: `lib/dates.dart`

**Modified**: `lib/module/patients/patient_book.dart`, `lib/module/patients/patient_form_sheet.dart`, `lib/module/patients/manage_patients_screen.dart`, `lib/module/registration/registration_service.dart`, `test/patients_test.dart`

**Verification Commands**:
- `flutter analyze` — clean of anything from this pass
- `flutter test -j 2` — 278/278 passed

## 60. The Call-to-Order Number Actually Dials (2026-08-20 22:10:00 IST)

**High-level description**: Rewrote the prescription card's second row to name both other ways to order — the nearest store, or the phone — and wired the number to the platform dialer.

- `lib/module/home/prescription_card.dart`:
  - the copy is now "You may place your order through our nearest store, or call us to order on 9400525063". Not everyone has a photo of a prescription to hand, and both other routes end at the same counter.
  - `orderPhone` moved from `09240250346` to `9400525063`, which is also the Perinthalmanna branch's number in `StoreDirectory` — the same desk a walk-in reaches.
  - the row is its own `InkWell` nested inside the card's. The copy names a phone number, so tapping the copy has to dial it; the nested target takes the hit there and the card still opens upload everywhere else. The chip stays under `IgnorePointer` because the row around it is already the button — a second target would only make the chip's edges behave differently from its middle.
  - the chip went from outlined to filled brand blue. It is now the one thing on the card that does something other than open upload, so it should not look like the Upload chip beside it.
- `lib/phone.dart` (new): `Dialer.call`, and `Dialer.uriFor` which strips everything but digits and a leading plus so a number written for people still dials.
  - It opens the dialer rather than placing the call: dialling outright needs `CALL_PHONE`, and an order line is not worth asking a member for that permission.
  - A refused launch shows a snackbar naming the number. On a device with no dialer a silent no-op reads as a broken button.
  - `Dialer.opener` is a `@visibleForTesting` seam. Swapping the function is enough to watch the exact `tel:` URI, and it avoids standing up a fake `UrlLauncherPlatform` for a one-call surface.
- `pubspec.yaml`: `url_launcher: ^6.3.2`, resolved from the existing pub cache.
- `android/app/src/main/AndroidManifest.xml`: a `<queries>` entry for `ACTION_DIAL` on the `tel` scheme. Without it, package visibility on API 30+ hides every dialer from the app and the launch fails silently — the exact failure the snackbar would otherwise be reporting on every device.
- Defect found during the pass:
  - the card's "hugs its two rows" ceiling was 190 and the card is now 248 in tests. The extra height is the test font, which is far wider than Roboto and wraps the order copy to about twice the lines it takes on a device. The ceiling moved to 320, and the comment now says what it is guarding against — stretching to the 5200 of the Stack — rather than pinning a height.
- Tests — `upload_prescription_test.dart`: the copy naming the store, the call and the number; the chip dialling `tel:9400525063`; the copy dialling too; a refused launch reporting; the rest of the card still opening upload; and `uriFor` stripping spaces and dashes while keeping a leading plus.

### Files Modified/Created
**Created**: `lib/phone.dart`

**Modified**: `lib/module/home/prescription_card.dart`, `pubspec.yaml`, `pubspec.lock`, `android/app/src/main/AndroidManifest.xml`, `test/upload_prescription_test.dart`

**Verification Commands**:
- `flutter analyze` — clean of anything from this pass
- `flutter test -j 2` — 284/284 passed

## 61. Malayalam on the Upload Screen, and the Ordering Procedure (2026-08-20 23:05:00 IST)

**High-level description**: Added a language switch to the prescription upload screen and a five-step ordering procedure, both written in English and Malayalam.

- `lib/module/prescription/prescription_copy.dart` (new): every string the screen writes, twice.
  - A table of named fields rather than a keyed lookup. A missing key would compile and then render a blank line; a missing field does not compile at all.
  - Scoped to this screen rather than the app. SHIELD's counters are in Kerala and this is the one screen a member reads *instructions* on — the rest of the app is names, prices and buttons, which are usable without translation. Widening it later means adding tables, not rewriting the mechanism.
- The switch shows both options in their own script — `English` and `മലയാളം`. A reader who cannot read the language currently on screen can still find their way out of it, which is the one thing a globe icon or a flag cannot do.
  - It is screen-local and not remembered between visits. Someone who switches once to read the steps should not find the whole flow in a language they did not choose the next time they upload.
- Everything the screen renders turns over, not just the new block: heading, intro, both source tiles, the patient row, the duration picker and its custom-days field, the guidance rules, the procedure, the pharmacist card, the Free badge and the Proceed button. A half-translated screen is worse than an untranslated one.
  - `PatientPicker` gained optional `label` and `hint` parameters, defaulted to the English it had hardcoded, so its only other behaviour is unchanged.
- The procedure is five numbered steps joined by a vertical rule, so the column reads as a sequence rather than as five separate notes. It sits *below* the form: someone who already knows the flow should not scroll past an explanation to reach the buttons, and someone who does not will read down to it.
- Defect found during the pass:
  - two cases stopped finding the pharmacist card. The screen is now much taller and its `ListView` does not build what is far below the fold — the same lazy-list trap the home feed hit two entries ago. The default pump went 1400 to 2400, and the 320px case 2200 to 3600, since every step of the procedure wraps to several rows at that width.
- Tests — `upload_prescription_test.dart`: the five steps numbered and in order and sitting below the source tiles; the switch opening in English with both names offered; switching turning over all twelve translated surfaces and leaving no English behind; the rules and steps translated one for one; switching back; a chosen duration surviving the switch, because this is a relabel and not a reset; and both tables being complete.

### Files Modified/Created
**Created**: `lib/module/prescription/prescription_copy.dart`

**Modified**: `lib/module/prescription/upload_prescription_screen.dart`, `lib/module/patients/patient_picker.dart`, `test/upload_prescription_test.dart`

**Verification Commands**:
- `flutter analyze` — clean of anything from this pass
- `flutter test -j 2` — 292/292 passed

## 62. Bottom Bar Rebuilt: Home, Lab, Dietitian, Approvals, Account (2026-08-21 09:40:00 IST)

**High-level description**: Replaced the bottom navigation's destinations, dropped the shield mark from the bar, and built the two new screens behind it.

- `lib/screens/app_tabs.dart`: the bar is now Home, Lab, Dietitian, Approvals, Account. Home leads it instead of sitting in the middle, and `brandMark` is gone — the mark is on the header, and a logo in a navigation bar is a destination nobody can name. With no tab drawn larger than its neighbours the per-tab `iconSize` became one `AppTab.iconSize`.
- Categories and Clinics lost their tabs, so both needed a way back in before they could be removed:
  - the home category strip's "View all" was a no-op; it pushes `CategoriesScreen` now, which is the obvious place to look for it.
  - the drawer's twelve browse links pushed the same route rather than switching to a tab that no longer exists, and a "Clinics & hospitals" row joined the shaded group.
- `lib/module/dietitian/` (new): a panel of four dietitians with qualification, focus areas, languages, fee and next slot, searchable by name, qualification or condition. Above them, what every consultation includes — said once rather than repeated on four cards. Every entry speaks Malayalam, since that is where the counters are.
- `lib/module/approvals/` (new): prescriptions the pharmacist has priced and is waiting on.
  - The member approves or declines; nothing is dispensed or charged until they do, which the screen says in as many words.
  - A line that differs from the prescription carries its own note on the line — a substitution, a short-supply split — because those are the ones worth reading rather than waving through.
  - `_settle` only moves a request that is still awaiting. Re-answering a settled one would let a stale screen overwrite a decision the member already made.
  - Answered requests stay below the live ones as a record rather than disappearing.
- Defects found during the pass:
  - the approval card overflowed 27px at 320px. The status chip carried the full sentence — "Awaiting your approval" — and squeezed the order reference off the card. `ApprovalStatus` gained a one-word `shortLabel` for the chip; the sentence stays on the enum and is what a screen reader is given.
  - a dietitian case matched "Today, 4:00 PM" twice, since the card shows the slot as well as the booking notice. It asserts the whole notice as one string now.
- Tests — `dietitian_test.dart` and `approvals_test.dart` (both new): the panel priced and bookable and covering Malayalam, search by name, qualification and condition, an empty search returning the panel rather than nothing, the no-match state, booking naming the dietitian and the slot; the total summing its lines, changed lines flagged, the waiting/settled split, approving and declining, a settled request refusing a second answer, the all-clear state, and both screens at 320px.
  - `bottom_nav_test.dart`: the new labels and order, Home leading, none of Orders/Categories/Appointment/Clinics being tabs, no `Image` anywhere in the bar, and both new destinations opening from it.
  - `clinics_test.dart` opens the directory through the drawer, and `lab_section_test.dart` taps "Lab".

### Files Modified/Created
**Created**: `lib/module/dietitian/dietitian.dart`, `lib/module/dietitian/dietitian_screen.dart`, `lib/module/approvals/approval.dart`, `lib/module/approvals/approvals_screen.dart`, `test/dietitian_test.dart`, `test/approvals_test.dart`

**Modified**: `lib/screens/app_tabs.dart`, `lib/screens/app_shell.dart`, `lib/widgets/bottom_nav.dart`, `lib/module/menu/menu_drawer.dart`, `lib/module/home/category_section.dart`, `test/bottom_nav_test.dart`, `test/clinics_test.dart`, `test/lab_section_test.dart`

**Verification Commands**:
- `flutter analyze` — clean of anything from this pass
- `flutter test -j 2` — 319/319 passed

## 63. Language Switch Reduced to Codes (2026-08-21 10:15:00 IST)

**High-level description**: The upload screen's language switch shows `ENG` and `MA` rather than the full names.

- `lib/module/prescription/prescription_copy.dart`: `AppLanguage` gained `code` beside `label`. Two buttons carrying full names crowd the top of the screen and push the heading down; the codes say the same thing in a third of the width.
- Both codes stay on screen, never just the one on offer. A switch reading only "MA" leaves a reader guessing whether it names where they are or where they would end up.
- `label` is still the full name and is what the screen reader is given — "ENG" read out as three letters would be worse than useless.
- Defect found during the pass:
  - the accessible name came out as the language *and* the code read together, because an explicit `Semantics` label merges with the text beneath it rather than replacing it. The code is now wrapped in `ExcludeSemantics`: it is decoration, and the name belongs to the button.
- Tests — `upload_prescription_test.dart`: the switch showing both codes and neither full name, and the full names still reaching the semantics tree.

### Files Modified/Created
**Modified**: `lib/module/prescription/prescription_copy.dart`, `lib/module/prescription/upload_prescription_screen.dart`, `test/upload_prescription_test.dart`

**Verification Commands**:
- `flutter analyze` — clean of anything from this pass
- `flutter test -j 2` — 320/320 passed
