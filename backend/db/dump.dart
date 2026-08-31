// Exports every row of every `public` table to JSON, as a safety net before a
// wipe. Read-only.
//
//   dart run backend/db/dump.dart
//
// Writes backend/db/backup/<UTC-timestamp>/<table>.json (one file per table,
// a JSON array of row objects) plus _manifest.json with the row counts.
//
// Reads DATABASE_URL from the environment or `.env` at the repo root.

import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';

Future<void> main() async {
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
      applicationName: 'shield-db-dump',
    ),
  );

  final tables = (await conn.execute(
    "select table_name from information_schema.tables "
    "where table_schema = 'public' and table_type = 'BASE TABLE' "
    "order by table_name",
  )).map((r) => r[0] as String).toList();

  final stamp = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('.', '-');
  final dir = Directory('backend/db/backup/$stamp')..createSync(recursive: true);

  final manifest = <String, int>{};
  var grandTotal = 0;

  for (final t in tables) {
    final rows = await conn.execute('select * from "$t"');
    final list = rows.map((r) => r.toColumnMap()).toList();
    File('${dir.path}/$t.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(_jsonSafe(list)),
    );
    manifest[t] = list.length;
    grandTotal += list.length;
    stdout.writeln('  ${t.padRight(38)} ${list.length}');
  }

  File('${dir.path}/_manifest.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
      'host': uri.host,
      'tables': manifest,
      'totalRows': grandTotal,
    }),
  );

  stdout.writeln();
  stdout.writeln('Wrote ${dir.path}  ($grandTotal rows across ${tables.length} tables)');
  await conn.close();
}

/// Recursively convert values `jsonEncode` cannot handle on its own.
Object? _jsonSafe(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is DateTime) return value.toIso8601String();
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _jsonSafe(v)));
  }
  if (value is Iterable) return value.map(_jsonSafe).toList();
  return value.toString();
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
