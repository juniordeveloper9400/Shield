# Member App Tech Stack

| Concern | Choice |
| --- | --- |
| Client | Flutter, Dart SDK `^3.10.0` |
| UI | Material 3, shared widgets, `lib/theme/` |
| Auth | Firebase Core and Firebase Phone Auth |
| Database | Neon PostgreSQL through `postgres`, `http`, and repository wrappers |
| Local state/persistence | Dart services, `ChangeNotifier` patterns, `shared_preferences` |
| Location/map | `geolocator`, `flutter_map`, `latlong2`, OpenStreetMap |
| Media | `image_picker`, `image`, `video_player` |
| Device actions | `share_plus`, `url_launcher` |
| Platforms | Android primary; Flutter web path; iOS setup pending |
| Tests | `flutter_test` under root `test/` |

Critical package changes require clean Android/web checks and updates to the combined tech-stack document.
