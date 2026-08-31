// DESTRUCTIVE. Empties every table in the Neon `public` schema.
//
//   dart run backend/db/wipe.dart --yes
//
// Runs a single `TRUNCATE ... RESTART IDENTITY CASCADE` over all base tables,
// so every row is deleted and identity sequences reset. The schema, indexes,
// constraints and Prisma migration history are kept.
//
//   --yes                  required; without it the script only reports counts
//   --include-migrations   also truncate `_prisma_migrations` (default: keep it)
//
// Reads DATABASE_URL from the environment or `.env` at the repo root.

import 'dart:io';

import 'package:postgres/postgres.dart';

Future<void> main(List<String> args) async {
  final confirmed = args.contains('--yes');
  final includeMigrations = args.contains('--include-migrations');

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
      applicationName: 'shield-db-wipe',
    ),
  );

  final all = (await conn.execute(
    "select table_name from information_schema.tables "
    "where table_schema = 'public' and table_type = 'BASE TABLE' "
    "order by table_name",
  )).map((r) => r[0] as String).toList();

  final targets = [
    for (final t in all)
      if (includeMigrations || t != '_prisma_migrations') t,
  ];

  var totalRows = 0;
  for (final t in targets) {
    final c = await conn.execute('select count(*) from "$t"');
    totalRows += c.first.first as int;
  }

  final dbName =
      uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'neondb';
  stdout.writeln('Database: ${uri.host}/$dbName');
  stdout.writeln('Tables to empty: ${targets.length}'
      '${includeMigrations ? '' : '  (keeping _prisma_migrations)'}');
  stdout.writeln('Rows that will be deleted: $totalRows');

  if (!confirmed) {
    stdout.writeln();
    stdout.writeln('Dry run. Re-run with --yes to actually TRUNCATE.');
    await conn.close();
    return;
  }

  final list = targets.map((t) => '"$t"').join(', ');
  stdout.writeln();
  stdout.writeln('Truncating…');
  await conn.execute('TRUNCATE TABLE $list RESTART IDENTITY CASCADE');

  var after = 0;
  for (final t in targets) {
    final c = await conn.execute('select count(*) from "$t"');
    after += c.first.first as int;
  }
  stdout.writeln('Done. Rows remaining across those tables: $after');

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
