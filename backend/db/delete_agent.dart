// Deletes one `app.agent` row by its `code` (e.g. `SHD-AGT-001`) — cleanup
// for a dummy/test agent that should not exist (a garbage `area` value from
// the old free-text "area" box, a duplicate, etc).
//
// Schema-supported, the same cascade the console's own "Switch to member"
// action relies on: `parent_id` is `ON DELETE SET NULL` (any sub-agents move
// to the top of the tree), `agent_customer` / `agent_withdrawal` /
// `agent_wallet_transfer` are `ON DELETE CASCADE` (that agent's own
// customers — and their plans — withdrawal requests, and commission-transfer
// history go with it), and `agent_request.agent_id` /
// `agent_request.parent_agent_id` are `ON DELETE SET NULL`. The linked
// `app.users` row, if any, is never touched — only the agent designation is
// removed.
//
//   dart run backend/db/delete_agent.dart --code=SHD-AGT-001         # dry run
//   dart run backend/db/delete_agent.dart --code=SHD-AGT-001 --yes   # execute
//
// Reads DATABASE_URL from the environment or `.env` at the repo root.

import 'dart:io';

import 'package:postgres/postgres.dart';

Future<void> main(List<String> args) async {
  final confirmed = args.contains('--yes');
  final codeArg = args.firstWhere(
    (a) => a.startsWith('--code='),
    orElse: () => '',
  );
  final code = codeArg.isEmpty ? null : codeArg.substring('--code='.length);
  if (code == null || code.isEmpty) {
    stderr.writeln(
      'Usage: dart run backend/db/delete_agent.dart --code=SHD-AGT-001 [--yes]',
    );
    exit(2);
  }

  final url = _databaseUrl();
  if (url == null || url.isEmpty) {
    stderr.writeln('DATABASE_URL not found (env or .env at repo root).');
    exit(1);
  }

  final uri = Uri.parse(url);
  final userInfo = uri.userInfo.split(':');
  final conn = await Connection.open(
    Endpoint(
      host: uri.host,
      port: uri.hasPort ? uri.port : 5432,
      database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'neondb',
      username: Uri.decodeComponent(userInfo.first),
      password: userInfo.length > 1 ? Uri.decodeComponent(userInfo[1]) : null,
    ),
    settings: const ConnectionSettings(
      sslMode: SslMode.require,
      applicationName: 'shield-delete-agent',
    ),
  );

  final agentRows = await conn.execute(
    Sql.named(
      'select id, code, name, phone, level::text, area, area_id, member_id, '
      'parent_id, approval_status::text '
      'from app.agent where code = @code',
    ),
    parameters: {'code': code},
  );

  if (agentRows.isEmpty) {
    stdout.writeln('No agent found with code $code.');
    await conn.close();
    return;
  }

  final row = agentRows.first;
  final id = row[0] as int;
  stdout.writeln('Agent found:');
  stdout.writeln('  id          : $id');
  stdout.writeln('  code        : ${row[1]}');
  stdout.writeln('  name        : ${row[2]}');
  stdout.writeln('  phone       : ${row[3]}');
  stdout.writeln('  level       : ${row[4]}');
  stdout.writeln('  area        : ${row[5]}');
  stdout.writeln('  area_id     : ${row[6]}');
  stdout.writeln('  member_id   : ${row[7]}');
  stdout.writeln('  parent_id   : ${row[8]}');
  stdout.writeln('  approval    : ${row[9]}');
  stdout.writeln();

  final children = await conn.execute(
    Sql.named('select code, name from app.agent where parent_id = @id'),
    parameters: {'id': id},
  );
  final customers = await conn.execute(
    Sql.named(
      'select count(*) from app.agent_customer where agent_id = @id',
    ),
    parameters: {'id': id},
  );
  final withdrawals = await conn.execute(
    Sql.named(
      'select count(*) from app.agent_withdrawal where agent_id = @id',
    ),
    parameters: {'id': id},
  );
  final transfers = await conn.execute(
    Sql.named(
      'select count(*) from app.agent_wallet_transfer where agent_id = @id',
    ),
    parameters: {'id': id},
  );
  final requests = await conn.execute(
    Sql.named(
      'select count(*) from app.agent_request '
      'where agent_id = @id or parent_agent_id = @id',
    ),
    parameters: {'id': id},
  );

  stdout.writeln('Deleting this agent will:');
  stdout.writeln(
    '  - move ${children.length} direct sub-agent(s) to the top of the tree'
    '${children.isEmpty ? '' : ': ${children.map((r) => r[0]).join(', ')}'}',
  );
  stdout.writeln(
    '  - delete ${customers.first.first} agent_customer row(s) (and their plans)',
  );
  stdout.writeln(
    '  - delete ${withdrawals.first.first} agent_withdrawal row(s)',
  );
  stdout.writeln(
    '  - delete ${transfers.first.first} agent_wallet_transfer row(s)',
  );
  stdout.writeln(
    '  - clear the agent reference on ${requests.first.first} agent_request row(s)',
  );
  stdout.writeln(
    '  - leave the linked app.users row (if any) completely untouched',
  );
  stdout.writeln();

  if (!confirmed) {
    stdout.writeln('Dry run only — nothing changed. Re-run with --yes to delete.');
    await conn.close();
    return;
  }

  final result = await conn.execute(
    Sql.named('delete from app.agent where id = @id'),
    parameters: {'id': id},
  );
  stdout.writeln('Deleted (${result.affectedRows} row affected).');
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
