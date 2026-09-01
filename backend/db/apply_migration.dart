// Applies a single SQL migration file to the Neon database.
//
//   dart run backend/db/apply_migration.dart backend/db/migrations/0001_admin_user.sql          # dry run
//   dart run backend/db/apply_migration.dart backend/db/migrations/0001_admin_user.sql --yes    # apply
//
// Migrations under backend/db/migrations/ are written to be idempotent, so a
// re-run is harmless. Reads DATABASE_URL from the environment or `.env` at the
// repo root. Only the file you pass is executed — nothing else is touched.

import 'dart:io';

import 'package:postgres/postgres.dart';

Future<void> main(List<String> args) async {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final confirmed = args.contains('--yes');

  if (positional.isEmpty) {
    stderr.writeln('Usage: dart run backend/db/apply_migration.dart <file.sql> [--yes]');
    exit(1);
  }

  final file = File(positional.first);
  if (!file.existsSync()) {
    stderr.writeln('Migration file not found: ${file.path}');
    exit(1);
  }
  final sql = file.readAsStringSync();

  final url = _databaseUrl();
  if (url == null || url.isEmpty) {
    stderr.writeln('DATABASE_URL not found (env or .env at repo root).');
    exit(1);
  }

  final uri = Uri.parse(url);
  final ui = uri.userInfo.split(':');
  final conn = await Connection.open(
    Endpoint(
      host: uri.host,
      port: uri.hasPort ? uri.port : 5432,
      database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'neondb',
      username: Uri.decodeComponent(ui.first),
      password: ui.length > 1 ? Uri.decodeComponent(ui[1]) : null,
    ),
    settings: const ConnectionSettings(
      sslMode: SslMode.require,
      applicationName: 'shield-migration',
    ),
  );

  final dbName =
      uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'neondb';
  stdout
    ..writeln('Database : ${uri.host}/$dbName')
    ..writeln('Migration: ${file.path}  (${sql.length} bytes)');

  if (!confirmed) {
    stdout
      ..writeln()
      ..writeln('Dry run. Re-run with --yes to apply.');
    await conn.close();
    return;
  }

  stdout.writeln('\nApplying…');
  await conn.execute(sql, queryMode: QueryMode.simple);
  stdout.writeln('Done.');

  await conn.close();
}

String? _databaseUrl() {
  final env = Platform.environment['DATABASE_URL'];
  if (env != null && env.isNotEmpty) return env;
  final file = File('.env');
  if (!file.existsSync()) return null;
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0 || line.substring(0, eq).trim() != 'DATABASE_URL') continue;
    var v = line.substring(eq + 1).trim();
    if (v.length >= 2 &&
        ((v.startsWith('"') && v.endsWith('"')) ||
            (v.startsWith("'") && v.endsWith("'")))) {
      v = v.substring(1, v.length - 1);
    }
    return v;
  }
  return null;
}
