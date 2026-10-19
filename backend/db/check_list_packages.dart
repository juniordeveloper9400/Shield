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

  // Exact query from CareService.listLabPackages:
  final packages = await conn.execute(
    "SELECT p.id, p.name, p.source_test_id, p.is_active, p.sort, t.test_type AS source_test_type "
    "FROM app.lab_package p "
    "LEFT JOIN app.lab_test t ON t.id = p.source_test_id "
    "WHERE p.is_active = true "
    "ORDER BY p.sort, p.id"
  );

  print('Total active packages returned: ${packages.length}');
  
  // Find MACHU
  final machu = packages.where((r) => r[1] == 'MACHU').toList();
  print('MACHU in listLabPackages: ${machu.isNotEmpty ? machu.first : "NOT FOUND"}');

  // Let's check how many packages have source_test_type == 'PACKAGE'
  final packageTypeCount = packages.where((r) => r[5] == 'PACKAGE').length;
  print('Packages with source_test_type == PACKAGE: $packageTypeCount');

  // Let's check how many packages have source_test_id IS NULL (builder packages)
  final builderPackages = packages.where((r) => r[2] == null).length;
  print('Builder packages (source_test_id IS NULL): $builderPackages');

  // Let's check how many have source_test_type == 'TEST' or 'GROUP'
  final profilePackages = packages.where((r) => r[5] == 'TEST' || r[5] == 'GROUP').length;
  print('Profile packages (TEST or GROUP): $profilePackages');

  await conn.close();
}
