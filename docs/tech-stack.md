# SHIELD Technology Stack

**Status:** Inventory verified from package manifests and source configuration.

## Applications

| Layer | Technology | Repository evidence |
| --- | --- | --- |
| Member client | Flutter, Dart 3.10 range, Material 3 | `pubspec.yaml`, `lib/main.dart` |
| Android | Gradle Kotlin DSL, Firebase Android plugin | `android/` |
| Web client | Flutter web | `web/`, Flutter configuration |
| Operations client | React 18, TypeScript, Vite | `shieldweb/package.json` |
| Routing | React Router 6 | `shieldweb/src/App.tsx` |
| Styling | Tailwind CSS 3, PostCSS, Autoprefixer | `shieldweb/package.json`, `shieldweb/src/index.css` |
| Database | Neon PostgreSQL | `backend/README.md`, `backend/db/` |
| Member auth | Firebase Phone Auth | `firebase_options.dart`, auth module |
| Map/location | `flutter_map`, OpenStreetMap tiles, `geolocator` | root `pubspec.yaml` |
| Media | `image_picker`, `image`, `video_player` | root `pubspec.yaml` |
| Sharing/external actions | `share_plus`, `url_launcher` | root `pubspec.yaml` |
| Local persistence | `shared_preferences` | root `pubspec.yaml` |

## Data access

- Flutter member writes: `http` through `NeonHttp`.
- Flutter native repository access: `postgres` through `NeonDatabase`.
- Admin queries: `@neondatabase/serverless` in the browser.
- Schema tooling: Dart scripts under `backend/db/`.

## Build and hosting

- Flutter APK: `flutter build apk --release` or `build_apk.ps1`.
- Flutter web: `flutter build web`.
- Admin SPA: `npm run build`, output `shieldweb/dist`.
- Admin hosting configuration: `shieldweb/vercel.json` and `shieldweb/public/_redirects`.

## Dependency policy

Keep critical auth and database versions pinned or deliberately upgraded with validation. Review plugin platform support before adding Flutter web usage. Record meaningful dependency changes in an ADR and update this inventory when the runtime contract changes.

## Stack decisions still needed

- Server/API framework for the admin authorization boundary.
- Managed identity strategy for staff accounts.
- Production observability and audit-log platform.
- Image storage/retention strategy for prescriptions.
- CI provider and protected release environment.
