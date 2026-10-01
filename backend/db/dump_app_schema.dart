// Regenerates backend/db/app_schema.sql from the live `app` schema — exact
// CREATE TYPE/TABLE/FUNCTION/TRIGGER/INDEX DDL, read straight off
// pg_catalog/information_schema (there is no pg_dump binary in this
// environment to shell out to).
//
//   dart run backend/db/dump_app_schema.dart            # prints to stdout
//   dart run backend/db/dump_app_schema.dart --write    # overwrites app_schema.sql
//
// Exists because app_schema.sql is otherwise hand-maintained prose-with-DDL,
// and silently drifted for a long time — by the time this was written, it
// was missing 9 whole tables (the entire region..ward geo hierarchy,
// lab_bill/lab_bill_line, lab_category, lab_package_test_item) and real
// columns on 9 more (shield_store.offers_lab_collection, agent.area_id,
// wallet_entry.lab_booking_id among them) that live, shipped code already
// depends on. `apply_app_schema.dart --yes` against that file would have
// rebuilt a database missing all of it. Re-run this after any migration
// that touches `app` and commit the result, the same way `introspect.dart`'s
// SCHEMA.md is already regenerated rather than hand-edited.
//
// Read-only: every query here is a SELECT against the catalog; nothing in
// `app` (or anywhere else) is changed.
//
// Reads DATABASE_URL from the environment or `.env` at the repo root.

import 'dart:io';

import 'package:postgres/postgres.dart';

Future<void> main(List<String> args) async {
  final write = args.contains('--write');

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
      applicationName: 'shield-dump-app-schema',
    ),
  );

  final out = StringBuffer();
  void p(String s) => out.writeln(s);

  p('-- ============================================================================');
  p('--  app schema — regenerated from the live database by');
  p('--  `dart run backend/db/dump_app_schema.dart --write` on '
      '${DateTime.now().toUtc().toIso8601String().substring(0, 10)}.');
  p('--');
  p('--  Machine-generated — do not hand-edit. The prose explaining *why* each');
  p('--  table/column exists lives in backend/db/APP_SCHEMA.md instead, which');
  p("--  doesn't drift from reality the way inline DDL comments silently did");
  p('--  here for a long time (see this file\'s own doc comment in git log for');
  p('--  exactly how far). Edit a migration under backend/db/migrations/, apply');
  p('--  it, then re-run this to pick the change up — never this file directly.');
  p('-- ============================================================================');
  p('');
  p('CREATE SCHEMA IF NOT EXISTS app;');
  p('SET search_path TO app, public;');
  p('');

  // ---- Extensions (whichever live in app's own namespace rather than the
  // usual side schema — pg_trgm does, for the product name search index) ----
  final extensions = await conn.execute(
    "select e.extname from pg_extension e join pg_namespace n on n.oid = e.extnamespace "
    "where n.nspname = 'app' order by e.extname",
  );
  if (extensions.isNotEmpty) {
    p('-- ---- Extensions --------------------------------------------------------------');
    for (final row in extensions) {
      p('CREATE EXTENSION IF NOT EXISTS ${row[0]} WITH SCHEMA app;');
    }
    p('');
  }

  // ---- Enums -----------------------------------------------------------------
  final enums = await conn.execute(
    // string_agg, not array_agg: a plain `text` result decodes reliably as a
    // Dart String, where an array (`_text`) came back as an opaque
    // UndecodedBytes this driver version has no decoder for. '\x01' is safe
    // to split on — none of these enum labels contain it.
    r"select t.typname, string_agg(e.enumlabel, E'\x01' order by e.enumsortorder) as vals "
    "from pg_type t join pg_enum e on e.enumtypid = t.oid "
    "join pg_namespace n on n.oid = t.typnamespace "
    "where n.nspname = 'app' group by t.typname order by t.typname",
  );
  p('-- ---- Enums -----------------------------------------------------------------');
  for (final row in enums) {
    final vals = (row[1] as String)
        .split('\x01')
        .map((v) => "'${v.replaceAll("'", "''")}'")
        .join(', ');
    p('CREATE TYPE app.${row[0]} AS ENUM ($vals);');
  }
  p('');

  // ---- Tables, in dependency order so a child never precedes a parent it FKs to ----
  final tableRows = await conn.execute(
    "select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace "
    "where n.nspname = 'app' and c.relkind = 'r' order by c.relname",
  );
  final tableNames = tableRows.map((r) => r[0].toString()).toList();

  final fkEdges = await conn.execute(
    "select conrelid::regclass::text as child, confrelid::regclass::text as parent "
    "from pg_constraint where contype = 'f' and connamespace = 'app'::regnamespace",
  );
  final deps = {for (final n in tableNames) n: <String>{}};
  for (final row in fkEdges) {
    final child = row[0].toString().replaceFirst('app.', '').replaceAll('"', '');
    final parent = row[1].toString().replaceFirst('app.', '').replaceAll('"', '');
    if (child != parent && deps.containsKey(child) && deps.containsKey(parent)) {
      deps[child]!.add(parent);
    }
  }
  final ordered = <String>[];
  final visited = <String>{};
  void visit(String n, Set<String> stack) {
    if (visited.contains(n) || stack.contains(n)) return;
    stack.add(n);
    for (final d in deps[n] ?? const <String>{}) {
      visit(d, stack);
    }
    stack.remove(n);
    visited.add(n);
    ordered.add(n);
  }
  for (final n in tableNames) {
    visit(n, <String>{});
  }

  p('-- ---- Tables ------------------------------------------------------------------');
  for (final table in ordered) {
    p(await _tableDdl(conn, table));
  }

  // ---- Functions (pg_get_functiondef is exact; skip extension-owned ones) ----
  // The def is fetched in this same query, not a second parameterised call —
  // an oid/regclass value read back out of one query can't safely be
  // re-encoded as a parameter into another with this driver.
  final funcs = await conn.execute(
    "select pg_get_functiondef(p.oid) as def from pg_proc p "
    "join pg_namespace n on n.oid = p.pronamespace "
    "where n.nspname = 'app' "
    "and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e') "
    "order by p.proname",
  );
  if (funcs.isNotEmpty) {
    p('-- ---- Functions ---------------------------------------------------------------');
    for (final row in funcs) {
      p('${row[0]};');
      p('');
    }
  }

  // ---- Triggers (pg_get_triggerdef is exact) --------------------------------
  final triggers = await conn.execute(
    "select pg_get_triggerdef(t.oid) as def from pg_trigger t "
    "join pg_class c on c.oid = t.tgrelid join pg_namespace n on n.oid = c.relnamespace "
    "where n.nspname = 'app' and not t.tgisinternal order by c.relname, t.tgname",
  );
  if (triggers.isNotEmpty) {
    p('-- ---- Triggers ----------------------------------------------------------------');
    for (final row in triggers) {
      p('${row[0]};');
    }
    p('');
  }

  // ---- Indexes not already implied by a PK/UNIQUE constraint -----------------
  final indexes = await conn.execute(
    "select pg_get_indexdef(i.indexrelid) as def from pg_index i "
    "join pg_class c on c.oid = i.indexrelid join pg_namespace n on n.oid = c.relnamespace "
    "where n.nspname = 'app' and i.indisprimary = false and i.indisunique = false "
    "order by c.relname",
  );
  if (indexes.isNotEmpty) {
    p('-- ---- Indexes -----------------------------------------------------------------');
    for (final row in indexes) {
      p('${row[0]};');
    }
    p('');
  }

  await conn.close();

  if (write) {
    File('backend/db/app_schema.sql').writeAsStringSync(out.toString());
    stderr.writeln('Wrote backend/db/app_schema.sql '
        '(${ordered.length} tables, ${enums.length} enums, '
        '${funcs.length} functions, ${triggers.length} triggers).');
  } else {
    stdout.write(out.toString());
  }
}

Future<String> _tableDdl(Connection conn, String table) async {
  final cols = await conn.execute(
    Sql.named('select column_name, data_type, udt_name, is_nullable, column_default, '
        'character_maximum_length, numeric_precision, numeric_scale, is_identity, '
        'identity_generation '
        'from information_schema.columns '
        "where table_schema = 'app' and table_name = @table "
        'order by ordinal_position'),
    parameters: {'table': table},
  );

  final colLines = cols.map((c) {
    final name = c[0] as String;
    final isIdentity = c[8] == 'YES';
    final isNullable = c[3] == 'NO';
    final type = _sqlType(
      dataType: c[1] as String,
      udtName: c[2] as String,
      maxLen: c[5] as int?,
      numPrecision: c[6] as int?,
      numScale: c[7] as int?,
    );
    var line = '    ${_quoteIdent(name)} $type';
    if (isIdentity) {
      line += ' GENERATED ${c[9]} AS IDENTITY';
    } else if (isNullable) {
      line += ' NOT NULL';
    }
    final default_ = c[4] as String?;
    if (default_ != null && !isIdentity && !default_.startsWith('nextval(')) {
      line += ' DEFAULT $default_';
    }
    return line;
  }).toList();

  // PK/UNIQUE/FK/CHECK — pg_get_constraintdef is exact, including ON
  // DELETE/UPDATE actions. Postgres 17+ also catalogues a plain column
  // NOT NULL as its own contype='n' constraint; that's already handled by
  // the inline NOT NULL above, so it's excluded here to avoid a duplicate.
  final cons = await conn.execute(
    Sql.named("select conname, pg_get_constraintdef(oid) as def from pg_constraint "
        "where conrelid = @table::regclass and contype <> 'n' "
        'order by contype, conname'),
    parameters: {'table': 'app.$table'},
  );
  final conLines = cons.map((c) => '    CONSTRAINT ${_quoteIdent(c[0] as String)} ${c[1]}').toList();

  return 'CREATE TABLE app.${_quoteIdent(table)} (\n'
      '${[...colLines, ...conLines].join(',\n')}\n'
      ');\n';
}

String _sqlType({
  required String dataType,
  required String udtName,
  int? maxLen,
  int? numPrecision,
  int? numScale,
}) {
  if (udtName == 'bigint' || udtName == 'int8') return 'bigint';
  if (dataType == 'ARRAY') {
    return '${udtName.startsWith('_') ? udtName.substring(1) : udtName}[]';
  }
  if (dataType == 'USER-DEFINED') return 'app.$udtName';
  if (dataType == 'character varying') {
    return maxLen != null ? 'varchar($maxLen)' : 'varchar';
  }
  if (dataType == 'numeric' && numPrecision != null) {
    return 'numeric($numPrecision,${numScale ?? 0})';
  }
  if (dataType == 'timestamp with time zone') return 'timestamptz';
  if (dataType == 'timestamp without time zone') return 'timestamp';
  return dataType;
}

const _reserved = {'order', 'user'};

String _quoteIdent(String name) {
  final plain = RegExp(r'^[a-z_][a-z0-9_]*$');
  return plain.hasMatch(name) && !_reserved.contains(name) ? name : '"$name"';
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
