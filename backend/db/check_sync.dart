import 'dart:io';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  final file = File('.env');
  String? url;
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      if (line.startsWith('DATABASE_URL=')) {
        url = line.substring('DATABASE_URL='.length).trim();
        break;
      }
    }
  }
  final uri = Uri.parse(url!);
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
    ),
  );

  final test = await conn.execute(
    "SELECT * FROM app.lab_test WHERE id = 535"
  );
  print('Test 535:');
  for (final row in test) {
    print(row.toColumnMap());
  }

  final pkg = await conn.execute(
    "SELECT * FROM app.lab_package WHERE source_test_id = 535"
  );
  print('\nPackage with source_test_id 535:');
  for (final row in pkg) {
    print(row.toColumnMap());
  }

  final profiles = await conn.execute(
    "SELECT p.* FROM app.lab_profile p JOIN app.lab_package pkg ON p.lab_package_id = pkg.id WHERE pkg.source_test_id = 535"
  );
  print('\nProfiles for package:');
  for (final row in profiles) {
    print(row.toColumnMap());
  }

  await conn.close();
}
