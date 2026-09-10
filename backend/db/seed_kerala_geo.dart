// Seeds app.assembly / app.lsgd / app.ward for Kerala from the official
// "Suvida LSG Detailed" workbook (District -> Assembly -> LSG -> Ward, one
// row per ward). Run AFTER 0014_geo_hierarchy.sql and
// 0016_seed_kerala_districts.sql (the district row for each of the 14
// districts must already exist).
//
//   dart run backend/db/seed_kerala_geo.dart "Suvida LSG Detailed (1) (1).xlsx"          # dry run
//   dart run backend/db/seed_kerala_geo.dart "Suvida LSG Detailed (1) (1).xlsx" --yes    # insert
//
// Reads the xlsx directly (unzips it and parses xl/worksheets/sheet1.xml +
// xl/sharedStrings.xml) — no Excel/Sheets round trip needed.
//
// The sheet has 21,927 data rows, one per ward, with columns:
//   A DISTRICT NAME  B District No  C Assembly Constituency  D Assembly Code
//   E LSG Name  F LSG Type  G LSG Code  H Ward Number  I Ward Code  J Ward Name
//   (K Males / L Females / M Others / N Total Count — population counts, not
//   part of app.ward's shape, so not loaded here)
//
// District linking is by `District No` (1..14) against app.district.sort —
// NOT by name: the sheet spells them in caps ("KASARGOD") and differently
// from the already-seeded district rows ("Kasaragod"), but the numbering
// matches migration 0016's order exactly.
//
// Three LSGs — Kochi, Thrissur and Kozhikkode corporations — carry no
// Assembly Constituency in the source at all (they genuinely span more than
// one), so their `assembly_id` is inserted NULL. Migration 0014 already
// makes that column nullable for exactly this reason.
//
// Idempotent: every insert is `ON CONFLICT DO NOTHING` against the tables'
// own unique constraints, so a re-run (or a retry after a dropped
// connection) never duplicates a row.

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:postgres/postgres.dart';
import 'package:xml/xml.dart';

const _lsgTypeMap = {
  'Corporation': 'corporation',
  'Municipality': 'municipality',
  'Grama Panchayat': 'grama_panchayat',
};

class _WardRow {
  final int districtNo;
  final int? assemblyCode;
  final String? assemblyName;
  final String lsgCode;
  final String lsgName;
  final String lsgType;
  final int wardNumber;
  final String wardCode;
  final String wardName;

  _WardRow({
    required this.districtNo,
    required this.assemblyCode,
    required this.assemblyName,
    required this.lsgCode,
    required this.lsgName,
    required this.lsgType,
    required this.wardNumber,
    required this.wardCode,
    required this.wardName,
  });
}

void main(List<String> args) async {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final confirmed = args.contains('--yes');
  if (positional.isEmpty) {
    stderr.writeln('Usage: dart run backend/db/seed_kerala_geo.dart <file.xlsx> [--yes]');
    exit(1);
  }

  final parsed = _readWorkbook(positional.first);
  stdout.writeln('Parsed ${parsed.length} ward rows from the workbook.');

  // The sheet carries a small number of exact duplicate rows — same LSG code
  // and ward number, same ward name/code (likely a population sub-row that
  // got flattened alongside the ward descriptor). Keep the first occurrence
  // of each (lsgCode, wardNumber) pair; app.ward's own UNIQUE constraint on
  // (lsgd_id, ward_number) would otherwise refuse the second row on insert.
  final seenWardKeys = <String>{};
  final rows = <_WardRow>[];
  var dropped = 0;
  for (final r in parsed) {
    if (seenWardKeys.add('${r.lsgCode}|${r.wardNumber}')) {
      rows.add(r);
    } else {
      dropped++;
    }
  }
  if (dropped > 0) {
    stdout.writeln('Dropped $dropped exact-duplicate ward rows -> ${rows.length} unique wards.');
  }

  // ---- dedupe into assemblies / lsgds -------------------------------------
  final assemblies = <String, ({int districtNo, int code, String name})>{};
  final lsgds = <String, ({int districtNo, int? assemblyCode, String name, String type})>{};
  for (final r in rows) {
    if (r.assemblyCode != null) {
      assemblies['${r.districtNo}|${r.assemblyCode}'] ??=
          (districtNo: r.districtNo, code: r.assemblyCode!, name: r.assemblyName!);
    }
    lsgds[r.lsgCode] ??= (
      districtNo: r.districtNo,
      assemblyCode: r.assemblyCode,
      name: r.lsgName,
      type: r.lsgType,
    );
  }
  stdout.writeln('  -> ${assemblies.length} distinct assemblies');
  stdout.writeln('  -> ${lsgds.length} distinct LSGDs '
      '(${lsgds.values.where((l) => l.assemblyCode == null).length} with no assembly)');

  if (!confirmed) {
    stdout
      ..writeln()
      ..writeln('Dry run — would insert:')
      ..writeln('  assembly  ${assemblies.length}')
      ..writeln('  lsgd      ${lsgds.length}')
      ..writeln('  ward      ${rows.length}')
      ..writeln('\nRe-run with --yes to insert.');
    return;
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
    settings: const ConnectionSettings(sslMode: SslMode.require, applicationName: 'shield-geo-seed'),
  );
  await conn.execute('SET search_path TO app, public', queryMode: QueryMode.simple);

  // ---- district_id by District No -----------------------------------------
  final districtRows = await conn.execute('SELECT id, sort FROM app.district');
  final districtIdByNo = <int, String>{
    for (final row in districtRows) (row[1] as int): row[0] as String,
  };
  if (districtIdByNo.length != 14) {
    stderr.writeln(
      'Expected 14 districts in app.district, found ${districtIdByNo.length}. '
      'Run 0016_seed_kerala_districts.sql --yes first.',
    );
    await conn.close();
    exit(1);
  }

  await conn.runTx((tx) async {
    // ---- assemblies --------------------------------------------------
    final assemblyIdByKey = <String, String>{};
    for (final entry in assemblies.entries) {
      final v = entry.value;
      final districtId = districtIdByNo[v.districtNo]!;
      final result = await tx.execute(
        Sql.named(
          'INSERT INTO app.assembly (district_id, name, code, sort) '
          "VALUES (@d::uuid, @n, @c, @s) "
          'ON CONFLICT (district_id, code) DO UPDATE SET name = EXCLUDED.name '
          'RETURNING id',
        ),
        parameters: {
          'd': districtId,
          'n': v.name,
          'c': 'AC${v.code}',
          's': v.code,
        },
      );
      assemblyIdByKey[entry.key] = result.first[0] as String;
    }
    stdout.writeln('Assemblies written: ${assemblyIdByKey.length}');

    // ---- lsgds ---------------------------------------------------------
    final lsgdIdByCode = <String, String>{};
    for (final entry in lsgds.entries) {
      final v = entry.value;
      final assemblyId = v.assemblyCode == null ? null : assemblyIdByKey['${v.districtNo}|${v.assemblyCode}'];
      final type = _lsgTypeMap[v.type];
      if (type == null) {
        throw StateError('Unknown LSG Type "${v.type}" for LSG code ${entry.key}');
      }
      final result = await tx.execute(
        Sql.named(
          'INSERT INTO app.lsgd (assembly_id, type, name, code) '
          'VALUES (@a::uuid, @t::app.lsgd_type, @n, @c) '
          'ON CONFLICT (assembly_id, name) DO UPDATE SET name = EXCLUDED.name '
          'RETURNING id',
        ),
        parameters: {'a': assemblyId, 't': type, 'n': v.name, 'c': entry.key},
      );
      lsgdIdByCode[entry.key] = result.first[0] as String;
    }
    stdout.writeln('LSGDs written: ${lsgdIdByCode.length}');

    // ---- wards, batched via UNNEST --------------------------------------
    const batchSize = 1000;
    var written = 0;
    for (var i = 0; i < rows.length; i += batchSize) {
      final batch = rows.skip(i).take(batchSize).toList();
      await tx.execute(
        Sql.named(
          '''
          INSERT INTO app.ward (lsgd_id, ward_number, name, code, sort)
          SELECT w.lsgd_id::uuid, w.ward_number, w.name, w.code, w.ward_number
          FROM unnest(
            @lsgdIds::text[], @wardNumbers::int[], @names::text[], @codes::text[]
          ) AS w(lsgd_id, ward_number, name, code)
          ON CONFLICT (lsgd_id, ward_number) DO NOTHING
          ''',
        ),
        parameters: {
          'lsgdIds': [for (final r in batch) lsgdIdByCode[r.lsgCode]!],
          'wardNumbers': [for (final r in batch) r.wardNumber],
          'names': [for (final r in batch) r.wardName],
          'codes': [for (final r in batch) r.wardCode],
        },
      );
      written += batch.length;
      stdout.writeln('  wards: $written / ${rows.length}');
    }
  });

  final counts = <String, int>{};
  for (final t in ['assembly', 'lsgd', 'ward']) {
    final r = await conn.execute('select count(*) from app.$t');
    counts[t] = r.first.first as int;
  }
  stdout.writeln('\nDone. Live counts: $counts');
  await conn.close();
}

// ---- xlsx parsing -----------------------------------------------------

List<_WardRow> _readWorkbook(String path) {
  final bytes = File(path).readAsBytesSync();
  final zip = ZipDecoder().decodeBytes(bytes);
  String readEntry(String name) =>
      String.fromCharCodes(zip.files.firstWhere((f) => f.name == name).content as List<int>);

  final sstDoc = XmlDocument.parse(readEntry('xl/sharedStrings.xml'));
  final shared = <String>[
    for (final si in sstDoc.rootElement.childElements)
      [for (final t in si.findAllElements('t')) t.innerText].join(),
  ];

  final sheetDoc = XmlDocument.parse(readEntry('xl/worksheets/sheet1.xml'));
  final sheetRows = sheetDoc.rootElement.findAllElements('row').toList();

  String? cellValue(XmlElement row, String col) {
    for (final c in row.findElements('c')) {
      final ref = c.getAttribute('r') ?? '';
      if (ref.replaceAll(RegExp(r'\d'), '') != col) continue;
      final v = c.findElements('v').firstOrNull?.innerText;
      if (v == null) return null;
      if (c.getAttribute('t') == 's') {
        final idx = int.parse(v);
        return idx < shared.length ? shared[idx] : null;
      }
      return v;
    }
    return null;
  }

  final out = <_WardRow>[];
  for (final row in sheetRows.skip(1)) {
    final districtNoRaw = cellValue(row, 'B');
    final assemblyCodeRaw = cellValue(row, 'D');
    final assemblyName = cellValue(row, 'C');
    final lsgCode = cellValue(row, 'G');
    final lsgName = cellValue(row, 'E');
    final lsgType = cellValue(row, 'F');
    final wardNumberRaw = cellValue(row, 'H');
    final wardCode = cellValue(row, 'I');
    final wardName = cellValue(row, 'J');

    if (districtNoRaw == null || lsgCode == null || lsgName == null || lsgType == null) {
      continue; // header/spacer row, not real data
    }
    out.add(_WardRow(
      districtNo: double.parse(districtNoRaw).round(),
      assemblyCode: assemblyCodeRaw == null ? null : double.parse(assemblyCodeRaw).round(),
      assemblyName: assemblyName,
      lsgCode: lsgCode,
      lsgName: lsgName,
      lsgType: lsgType,
      wardNumber: double.parse(wardNumberRaw!).round(),
      wardCode: wardCode ?? '',
      wardName: wardName ?? '',
    ));
  }
  return out;
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
        ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'")))) {
      v = v.substring(1, v.length - 1);
    }
    return v;
  }
  return null;
}
