// DESTRUCTIVE. Empties a chosen set of tables (and whatever a TRUNCATE CASCADE
// pulls in with them). Keeps every table's structure.
//
//   dart run backend/db/wipe_subset.dart                 # dry run, default groups
//   dart run backend/db/wipe_subset.dart --yes           # execute default groups
//   dart run backend/db/wipe_subset.dart wallet --yes    # just one group
//   dart run backend/db/wipe_subset.dart wallet permissions services-full --yes
//
// Groups:
//   wallet        wallets + every table that carries a wallet_id
//   permissions   role_permissions, permissions  (roles is left alone — users.role_id points at it)
//   services      provider profile / payment-method / settings / benefit-rule tables
//   services-full services + service_providers  --  ⚠ CASCADE also empties
//                 purchases, appointments, activity_events, store_change_requests,
//                 prescription_pharmacy_requests and everything under them
//                 (purchase_items, fulfillments, order_*, consultations, prescriptions…)
//
// Default when no group is named: wallet + permissions + services
//
// Reads DATABASE_URL from the environment or `.env` at the repo root. Prints a
// full before/after row-count diff so the real blast radius is visible.

import 'dart:io';

import 'package:postgres/postgres.dart';

const _groups = <String, List<String>>{
  'wallet': [
    'wallets',
    'wallet_transactions',
    'wallet_recharge_intents',
    'cash_wallet_transactions',
    'benefit_ledger_transactions',
    'pricing_rule_audits',
    'reward_point_transactions',
  ],
  'permissions': [
    'role_permissions',
    'permissions',
  ],
  'services': [
    'service_benefit_rules',
    'service_provider_payment_methods',
    'pharmacy_provider_settings',
    'provider_profile_branch_assignments',
    'provider_profiles',
  ],
};

Future<void> main(List<String> args) async {
  final confirmed = args.contains('--yes');
  final named = args.where((a) => !a.startsWith('--')).toSet();

  final selected = named.isEmpty
      ? {'wallet', 'permissions', 'services'}
      : named;

  final targets = <String>{};
  for (final g in selected) {
    if (g == 'services-full') {
      targets
        ..addAll(_groups['services']!)
        ..add('service_providers');
    } else if (_groups.containsKey(g)) {
      targets.addAll(_groups[g]!);
    } else {
      stderr.writeln('Unknown group: $g  '
          '(wallet, permissions, services, services-full)');
      exit(2);
    }
  }

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
      applicationName: 'shield-db-wipe-subset',
    ),
  );

  Future<Map<String, int>> snapshot() async {
    final names = (await conn.execute(
      "select table_name from information_schema.tables "
      "where table_schema = 'public' and table_type = 'BASE TABLE'",
    )).map((r) => r[0] as String).toList();
    final out = <String, int>{};
    for (final n in names) {
      out[n] = (await conn.execute('select count(*) from "$n"')).first.first as int;
    }
    return out;
  }

  final before = await snapshot();

  stdout.writeln('Groups: ${selected.join(', ')}');
  stdout.writeln('Directly targeted (${targets.length}):');
  for (final t in targets) {
    stdout.writeln('  ${t.padRight(38)} ${before[t] ?? '(missing)'}');
  }

  if (!confirmed) {
    stdout.writeln('\nDry run. Re-run with --yes to TRUNCATE '
        '(CASCADE may empty more — you will see the diff).');
    await conn.close();
    return;
  }

  final list = targets.map((t) => '"$t"').join(', ');
  stdout.writeln('\nTruncating…');
  await conn.execute('TRUNCATE TABLE $list RESTART IDENTITY CASCADE');

  final after = await snapshot();

  stdout.writeln('\nEmptied (before → after):');
  final changed = before.keys
      .where((k) => (before[k] ?? 0) != (after[k] ?? 0))
      .toList()
    ..sort();
  for (final k in changed) {
    final tag = targets.contains(k) ? '' : '   (via CASCADE)';
    stdout.writeln('  ${k.padRight(38)} ${before[k]} → ${after[k]}$tag');
  }
  final freed = changed.fold<int>(0, (s, k) => s + (before[k] ?? 0));
  stdout.writeln('\n${changed.length} tables emptied, $freed rows deleted.');

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
