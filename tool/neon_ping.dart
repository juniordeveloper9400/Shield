// Verifies the Neon Postgres connection outside the app.
//
//   dart run tool/neon_ping.dart
//
// Reads DATABASE_URL from the environment, or from a `.env` file in the project
// root (KEY=VALUE lines). Connects, prints the server version, the current
// database and role, and the first tables it can see, then disconnects.
//
// Exit code 0 on success, 1 on any failure.

import 'dart:io';

import 'package:postgres/postgres.dart';

Future<void> main() async {
  final url = _resolveDatabaseUrl();
  if (url == null || url.isEmpty) {
    stderr.writeln(
      'DATABASE_URL not found.\n'
      'Set it in the environment, or copy .env.example to .env and fill it in.',
    );
    exit(1);
  }

  final uri = Uri.parse(url);
  final userInfo = uri.userInfo.split(':');
  final endpoint = Endpoint(
    host: uri.host,
    port: uri.hasPort ? uri.port : 5432,
    database: uri.pathSegments.isNotEmpty && uri.pathSegments.first.isNotEmpty
        ? Uri.decodeComponent(uri.pathSegments.first)
        : 'neondb',
    username: userInfo.isNotEmpty && userInfo.first.isNotEmpty
        ? Uri.decodeComponent(userInfo.first)
        : null,
    password: userInfo.length > 1 ? Uri.decodeComponent(userInfo[1]) : null,
  );

  final sslMode = switch (uri.queryParameters['sslmode']) {
    'disable' => SslMode.disable,
    'verify-ca' || 'verify-full' => SslMode.verifyFull,
    _ => SslMode.require,
  };

  stdout.writeln('Connecting to ${endpoint.host}:${endpoint.port}'
      '/${endpoint.database} as ${endpoint.username} (sslmode=${sslMode.name})…');

  Connection? conn;
  try {
    conn = await Connection.open(
      endpoint,
      settings: ConnectionSettings(
        sslMode: sslMode,
        applicationName: 'shield-neon-ping',
        connectTimeout: const Duration(seconds: 15),
      ),
    );

    final info = await conn.execute(
      'select version(), current_database(), current_user',
    );
    final row = info.first;
    stdout.writeln('OK  connected.');
    stdout.writeln('    ${row[0]}');
    stdout.writeln('    database: ${row[1]}   role: ${row[2]}');

    final tables = await conn.execute(
      "select table_name from information_schema.tables "
      "where table_schema = 'public' order by table_name limit 20",
    );
    if (tables.isEmpty) {
      stdout.writeln('    public schema has no tables yet.');
    } else {
      final names = tables.map((r) => r[0]).join(', ');
      stdout.writeln('    public tables (${tables.length}): $names');
    }
  } catch (e) {
    stderr.writeln('FAILED  $e');
    exit(1);
  } finally {
    await conn?.close();
  }
}

/// DATABASE_URL from the process environment, or the first matching line of a
/// `.env` file in the current directory.
String? _resolveDatabaseUrl() {
  final fromEnv = Platform.environment['DATABASE_URL'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }

  final file = File('.env');
  if (!file.existsSync()) {
    return null;
  }
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final eq = line.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    if (line.substring(0, eq).trim() == 'DATABASE_URL') {
      var value = line.substring(eq + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      return value;
    }
  }
  return null;
}
