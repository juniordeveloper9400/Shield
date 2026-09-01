// Template for the git-ignored `neon_secret.dart`.
//
//   cp lib/data/neon/neon_secret.example.dart lib/data/neon/neon_secret.dart
//   # then paste the Neon connection string, or run:
//   dart run tool/gen_neon_secret.dart          # fills it in from .env
//
// Leaving it as the empty string is fine — the app just runs without a database
// (sign-in / registration are not persisted), same as before.

const String kNeonDatabaseUrl = '';
