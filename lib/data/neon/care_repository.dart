import 'package:flutter/foundation.dart';

import '../../module/dietitian/dietitian.dart';
import '../../module/labtest/lab_package.dart';
import 'neon_http.dart';

/// Reads the lab-test catalogue and the dietitian panel from Neon —
/// `app.lab_package` / `app.lab_profile` / `app.dietitian`, maintained by
/// hand (there is no admin-console screen for these yet) rather than
/// hardcoded in the app. Every method is best-effort, the same contract as
/// every other repository here: an unconfigured build or the network down
/// makes the call no-op and return null, so a member never sees an error
/// screen for reference data that simply hasn't loaded yet.
class CareRepository {
  const CareRepository._();

  static const CareRepository instance = CareRepository._();

  /// Test-only seams: a widget test can't reach a real Neon database (nor
  /// should it), so this swaps in fixture data instead of exercising the
  /// network path — the same shape of hook `legal_links.dart`'s openers use.
  /// Reset to null in `tearDown`.
  @visibleForTesting
  static Future<List<LabPackage>?> Function()? labPackagesOverride;
  @visibleForTesting
  static Future<List<Dietitian>?> Function()? dietitiansOverride;

  bool get isAvailable => NeonHttp.isConfigured;

  /// Every active package, each with its own profiles (and extras) attached
  /// — the package card shows the full breakdown with nothing else to tap,
  /// so the list itself has to carry it.
  Future<List<LabPackage>?> fetchLabPackages() {
    final override = labPackagesOverride;
    if (override != null) {
      return override();
    }
    return _run('fetchLabPackages', () async {
      final rows = await NeonHttp.instance.query('''
        SELECT id, slug, name, test_count, profile_count, rating, booked,
               report_in, price, mrp, saved, inherits_from, inherits_summary,
               extras_label, for_whom, age_range, preparation, sample, organs,
               about
          FROM app.lab_package
         WHERE is_active = true
         ORDER BY sort, name
      ''');
      if (rows.isEmpty) {
        return const [];
      }

      final ids = [for (final row in rows) row['id']];
      final profileRows = await NeonHttp.instance.query(
        '''
          SELECT lab_package_id, emoji, name, parameters, is_extra
            FROM app.lab_profile
           WHERE lab_package_id = ANY(\$1::bigint[])
           ORDER BY sort
        ''',
        [ids],
      );
      final profilesByPackage = <String, List<LabProfile>>{};
      final extrasByPackage = <String, List<LabProfile>>{};
      for (final row in profileRows) {
        final key = row['lab_package_id'].toString();
        final profile = LabProfile(
          row['emoji']?.toString() ?? '',
          row['name']?.toString() ?? '',
          _int(row['parameters']),
        );
        final bucket = _bool(row['is_extra'])
            ? extrasByPackage
            : profilesByPackage;
        bucket.putIfAbsent(key, () => []).add(profile);
      }

      return [
        for (final row in rows)
          LabPackage(
            id: row['id'].toString(),
            slug: row['slug']?.toString() ?? '',
            name: row['name']?.toString() ?? '',
            testCount: _int(row['test_count']),
            profileCount: _int(row['profile_count']),
            rating: row['rating']?.toString() ?? '',
            booked: row['booked']?.toString() ?? '',
            reportIn: row['report_in']?.toString() ?? '',
            price: formatRupees(_amount(row['price'])),
            mrp: formatRupees(_amount(row['mrp'])),
            saved: _amount(row['saved']) > 0
                ? formatRupees(_amount(row['saved']))
                : '',
            profiles: profilesByPackage[row['id'].toString()] ?? const [],
            inheritsFrom: _orNull(row['inherits_from']),
            inheritsSummary: _orNull(row['inherits_summary']),
            extrasLabel: _orNull(row['extras_label']),
            extras: extrasByPackage[row['id'].toString()] ?? const [],
            forWhom: row['for_whom']?.toString() ?? '',
            ageRange: row['age_range']?.toString() ?? '',
            preparation: row['preparation']?.toString() ?? '',
            sample: row['sample']?.toString() ?? '',
            organs: _stringArray(row['organs']),
            about: row['about']?.toString() ?? '',
          ),
      ];
    });
  }

  /// Every active dietitian. [Dietitian.initials] has no column of its own —
  /// derived from [Dietitian.name] here, the same way the avatar circle would
  /// otherwise have nothing to show for a name the admin hasn't broken into
  /// initials themselves.
  Future<List<Dietitian>?> fetchDietitians() {
    final override = dietitiansOverride;
    if (override != null) {
      return override();
    }
    return _run('fetchDietitians', () async {
      final rows = await NeonHttp.instance.query('''
        SELECT id, name, qualification, focus, experience_years, languages,
               fee, next_slot
          FROM app.dietitian
         WHERE is_active = true
         ORDER BY sort, name
      ''');
      return [
        for (final row in rows)
          Dietitian(
            id: row['id'].toString(),
            name: row['name']?.toString() ?? '',
            qualification: row['qualification']?.toString() ?? '',
            focus: _stringArray(row['focus']),
            experienceYears: _int(row['experience_years']),
            languages: _stringArray(row['languages']),
            fee: _amount(row['fee']),
            nextSlot: row['next_slot']?.toString() ?? '',
            initials: _initialsFor(row['name']?.toString() ?? ''),
          ),
      ];
    });
  }

  /// "Dr. Anjali Menon" → "AM" — the first letter of the first two words,
  /// skipping a bare "Dr."/"Mr."/"Mrs." title so the initials are not just
  /// "D" twice over.
  static String _initialsFor(String name) {
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w.replaceAll('.', '').isNotEmpty)
        .where((w) => !{'dr', 'mr', 'mrs', 'ms'}.contains(
              w.replaceAll('.', '').toLowerCase(),
            ))
        .toList();
    if (words.isEmpty) {
      return '';
    }
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  /// A Postgres array literal (`{Liver,Kidneys}`, quoted elements included)
  /// as a list of plain strings — `Neon-Raw-Text-Output` means every column
  /// comes back as text, `text[]` included, so this is the one place that
  /// text has to be unpacked.
  static List<String> _stringArray(Object? v) {
    final text = v?.toString();
    if (text == null || text.isEmpty || text == '{}') {
      return const [];
    }
    final inner = text.startsWith('{') && text.endsWith('}')
        ? text.substring(1, text.length - 1)
        : text;
    if (inner.isEmpty) {
      return const [];
    }
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < inner.length; i++) {
      final ch = inner[i];
      if (inQuotes) {
        if (ch == '\\' && i + 1 < inner.length) {
          buffer.write(inner[i + 1]);
          i++;
        } else if (ch == '"') {
          inQuotes = false;
        } else {
          buffer.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  static int _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// A `numeric` column, rounded to whole rupees — every price in this
  /// catalogue is written and shown in whole rupees, same as the rest of the
  /// app's money handling.
  static int _amount(Object? v) {
    final parsed = double.tryParse(v?.toString() ?? '');
    return parsed == null ? 0 : parsed.round();
  }

  static bool _bool(Object? v) {
    final s = v?.toString().toLowerCase();
    return s == 'true' || s == 't' || s == '1';
  }

  /// Blank comes back from Neon the same as it was written for an optional
  /// text column — treated as "not set" here, same as an actual SQL null.
  static String? _orNull(Object? v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  Future<T?> _run<T>(String label, Future<T?> Function() action) async {
    if (!NeonHttp.isConfigured) {
      return null;
    }
    try {
      return await action();
    } catch (error) {
      NeonHttp.log('CareRepository.$label failed', error: error);
      return null;
    }
  }
}
