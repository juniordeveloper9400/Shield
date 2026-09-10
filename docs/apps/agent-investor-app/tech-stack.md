# Agent / Investor App Tech Stack

| Concern | Choice |
| --- | --- |
| Client | Flutter, Dart SDK `^3.10.0` |
| Auth | Firebase Phone Auth |
| Data | Neon PostgreSQL via HTTP and native `postgres` paths |
| Persona | `PersonaService`, `PersonaRepository`, agent/investor services |
| Location | `geolocator`, `flutter_map`, `latlong2` |
| Media | `image_picker`, `image`, `video_player` |
| Platforms | Android and web paths; iOS setup pending |
| Tests | No dedicated test directory discovered |

This app should share dependency policy with the member app only until the codebases are intentionally separated.
