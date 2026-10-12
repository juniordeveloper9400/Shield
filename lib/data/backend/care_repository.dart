import 'package:flutter/foundation.dart';

import '../../module/dietitian/dietitian.dart';
import '../../module/labtest/lab_package.dart';
import 'backend_http.dart';

/// Reads the lab-test catalogue and the dietitian panel through
/// `backend/api`'s public `care` module (`GET /v1/public/care/lab-packages`
/// / `.../lab-categories` / `.../dietitians` — `care.controller.ts`/
/// `care.service.ts`), never a direct Neon connection.
///
/// Every method is best-effort, the same contract as every other repository
/// here: an unconfigured backend or the network down makes the call no-op
/// and return null, so a member never sees an error screen for reference
/// data that simply hasn't loaded yet.
class CareRepository {
  const CareRepository._();

  static const CareRepository instance = CareRepository._();

  /// Test-only seams: a widget test can't reach a real backend, so this
  /// swaps in fixture data instead of exercising the network path — the
  /// same shape of hook `legal_links.dart`'s openers use. Reset to null in
  /// `tearDown`.
  @visibleForTesting
  static Future<List<LabPackage>?> Function()? labPackagesOverride;
  @visibleForTesting
  static Future<List<LabCategory>?> Function()? labCategoriesOverride;
  @visibleForTesting
  static Future<List<Dietitian>?> Function()? dietitiansOverride;

  bool get isAvailable => BackendHttp.isConfigured;

  /// Every active package, each with its own profiles (and extras) attached
  /// — the package card shows the full breakdown with nothing else to tap,
  /// so the list itself has to carry it.
  Future<List<LabPackage>?> fetchLabPackages() async {
    final override = labPackagesOverride;
    if (override != null) {
      return override();
    }
    if (!BackendHttp.isConfigured) {
      return null;
    }
    try {
      final rows = await BackendHttp.instance.request(
            'GET',
            '/v1/public/care/lab-packages',
            auth: false,
          )
          as List<dynamic>;
      return [
        for (final row in rows.cast<Map<String, dynamic>>())
          LabPackage(
            id: row['id'].toString(),
            slug: _str(row['slug']),
            name: _str(row['name']),
            categoryId: row['categoryId'] == null
                ? ''
                : row['categoryId'].toString(),
            extraCategoryIds: _stringList(row['extraCategoryIds']),
            isProfile: row['sourceTestId'] != null,
            isMostCommon: row['isMostCommon'] == true,
            testCount: _int(row['testCount']),
            profileCount: _int(row['profileCount']),
            rating: _str(row['rating']),
            booked: _str(row['booked']),
            reportIn: _str(row['reportIn']),
            price: formatRupees(_amount(row['price'])),
            mrp: formatRupees(_amount(row['mrp'])),
            saved: _amount(row['saved']) > 0
                ? formatRupees(_amount(row['saved']))
                : '',
            profiles: _profiles(row['profiles'], isExtra: false),
            inheritsFrom: _orNull(row['inheritsFrom']),
            inheritsSummary: _orNull(row['inheritsSummary']),
            extrasLabel: _orNull(row['extrasLabel']),
            extras: _profiles(row['profiles'], isExtra: true),
            forWhom: _str(row['forWhom']),
            ageRange: _str(row['ageRange']),
            preparation: _str(row['preparation']),
            sample: _str(row['sample']),
            organs: _stringList(row['organs']),
            about: _str(row['about']),
          ),
      ];
    } catch (error) {
      BackendHttp.log('CareRepository.fetchLabPackages failed', error: error);
      return null;
    }
  }

  /// "Explore by health concern" — every active category, each carrying how
  /// many active packages currently sit under it (`GET
  /// /v1/public/care/lab-categories` — `CareService.listLabCategories`).
  Future<List<LabCategory>?> fetchLabCategories() async {
    final override = labCategoriesOverride;
    if (override != null) {
      return override();
    }
    if (!BackendHttp.isConfigured) {
      return null;
    }
    try {
      final rows = await BackendHttp.instance.request(
            'GET',
            '/v1/public/care/lab-categories',
            auth: false,
          )
          as List<dynamic>;
      return [
        for (final row in rows.cast<Map<String, dynamic>>())
          LabCategory(
            id: row['id'].toString(),
            name: _str(row['name']),
            image: _str(row['image']),
            testCount: _int(row['testCount']),
          ),
      ];
    } catch (error) {
      BackendHttp.log('CareRepository.fetchLabCategories failed', error: error);
      return null;
    }
  }

  /// Every active dietitian. [Dietitian.initials] has no column of its own —
  /// derived from [Dietitian.name] here, the same way the avatar circle
  /// would otherwise have nothing to show for a name the admin hasn't
  /// broken into initials themselves.
  Future<List<Dietitian>?> fetchDietitians() async {
    final override = dietitiansOverride;
    if (override != null) {
      return override();
    }
    if (!BackendHttp.isConfigured) {
      return null;
    }
    try {
      final rows = await BackendHttp.instance.request(
            'GET',
            '/v1/public/care/dietitians',
            auth: false,
          )
          as List<dynamic>;
      return [
        for (final row in rows.cast<Map<String, dynamic>>())
          Dietitian(
            id: row['id'].toString(),
            name: _str(row['name']),
            qualification: _str(row['qualification']),
            focus: _stringList(row['focus']),
            experienceYears: _int(row['experienceYears']),
            languages: _stringList(row['languages']),
            fee: _amount(row['fee']),
            nextSlot: _str(row['nextSlot']),
            initials: _initialsFor(_str(row['name'])),
          ),
      ];
    } catch (error) {
      BackendHttp.log('CareRepository.fetchDietitians failed', error: error);
      return null;
    }
  }

  static List<LabProfile> _profiles(Object? raw, {required bool isExtra}) {
    if (raw is! List) {
      return const [];
    }
    return [
      for (final row in raw.cast<Map<String, dynamic>>())
        if (_bool(row['isExtra']) == isExtra)
          LabProfile(
            _str(row['emoji']),
            _str(row['name']),
            _int(row['parameters']),
          ),
    ];
  }

  /// "Dr. Anjali Menon" → "AM" — the first letter of the first two words,
  /// skipping a bare "Dr."/"Mr."/"Mrs." title so the initials are not just
  /// "D" twice over.
  static String _initialsFor(String name) {
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w.replaceAll('.', '').isNotEmpty)
        .where(
          (w) => !{
            'dr',
            'mr',
            'mrs',
            'ms',
          }.contains(w.replaceAll('.', '').toLowerCase()),
        )
        .toList();
    if (words.isEmpty) {
      return '';
    }
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  static String _str(Object? v) => (v ?? '').toString();

  static List<String> _stringList(Object? v) =>
      v is List ? [for (final item in v) item.toString()] : const [];

  static int _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// A `numeric` column, serialized as a string by the backend — rounded to
  /// whole rupees, same as every price in this catalogue is written and
  /// shown.
  static int _amount(Object? v) {
    final parsed = double.tryParse(v?.toString() ?? '');
    return parsed == null ? 0 : parsed.round();
  }

  static bool _bool(Object? v) => v == true;

  static String? _orNull(Object? v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }
}
