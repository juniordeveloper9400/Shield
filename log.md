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
