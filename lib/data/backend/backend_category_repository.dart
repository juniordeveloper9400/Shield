import 'package:flutter/material.dart';

import '../../module/categories/category_catalogue.dart';
import '../../theme/app_colors.dart';
import 'backend_http.dart';

/// Reads the storefront category catalogue — `app.product_category` and
/// `app.product_subcategory` — from `backend/api`'s public catalogue routes
/// (`GET /v1/public/catalogue/categories` and
/// `.../categories/:id/subcategories`).
///
/// Ported from `shield agent_invester/lib/data/backend/category_repository.dart`
/// (that app's own working equivalent) — see this app's own migration plan
/// for why. `lib/data/neon/category_repository.dart` (the class
/// `CategoryCatalog` actually calls) tries this first and falls back to its
/// own direct-Neon path when the backend is unavailable or this fails.
///
/// Best-effort, like every other backend repository: with no
/// `BACKEND_API_BASE_URL` compiled in, the network down, or a non-2xx
/// answer, [fetchAll] returns `null` — never an empty list — so the caller
/// keeps whatever it already has rather than blanking the Categories tab.
class BackendCategoryRepository {
  BackendCategoryRepository._({BackendHttp? http}) : _http = http ?? BackendHttp.instance;

  static final BackendCategoryRepository instance = BackendCategoryRepository._();

  /// Test-only: an instance wired to an injected [BackendHttp].
  @visibleForTesting
  factory BackendCategoryRepository.test({required BackendHttp http}) =>
      BackendCategoryRepository._(http: http);

  final BackendHttp _http;

  bool get isAvailable => _http.isEnabled;

  /// Every active category, with its sub-categories attached, in the
  /// admin's sort order. `null` when the backend is off, unreachable, or a
  /// request failed; an empty result also maps to `null`.
  Future<List<CategoryGroup>?> fetchAll() async {
    if (!isAvailable) {
      return null;
    }
    try {
      final categoryRows = await _rows('/v1/public/catalogue/categories');
      if (categoryRows.isEmpty) {
        return null;
      }

      // The API only lists sub-categories one category at a time.
      final subcategoryRows = await Future.wait([
        for (final row in categoryRows)
          _rows('/v1/public/catalogue/categories/${row['id']}/subcategories'),
      ]);

      return [
        for (var i = 0; i < categoryRows.length; i++)
          _toCategoryGroup(
            categoryRows[i],
            items: [for (final row in subcategoryRows[i]) _toSubCategory(row)],
          ),
      ];
    } catch (error) {
      BackendHttp.log('BackendCategoryRepository.fetchAll failed', error: error);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _rows(String path) async {
    final body = await _http.request('GET', path, auth: false);
    return (body as List<dynamic>).cast<Map<String, dynamic>>();
  }

  static String _str(Object? v) => (v ?? '').toString().trim();

  /// One `productCategory` row (camelCase, as the API serialises it) plus
  /// its already-converted [items].
  static CategoryGroup _toCategoryGroup(
    Map<String, dynamic> row, {
    required List<SubCategory> items,
  }) {
    final title = _str(row['title']);
    return CategoryGroup(
      title: title,
      tabLabel: _str(row['tabLabel']).isEmpty ? title : _str(row['tabLabel']),
      icon: _iconForName(_str(row['iconName'])),
      image: _str(row['image']).isEmpty ? null : _str(row['image']),
      bannerImage:
          _str(row['bannerImage']).isEmpty ? null : _str(row['bannerImage']),
      panelTint: _colorForTintName(_str(row['panelTint'])),
      items: items,
    );
  }

  /// One `productSubcategory` row, as the API serialises it.
  static SubCategory _toSubCategory(Map<String, dynamic> row) {
    return SubCategory(
      _str(row['label']),
      _iconForName(_str(row['iconName'])),
      image: _str(row['image']).isEmpty ? null : _str(row['image']),
      offer: _str(row['offer']).isEmpty ? 'Up to 50% off' : _str(row['offer']),
    );
  }

  static IconData _iconForName(String name) =>
      CategoryRepositoryIcons.byName[name] ?? Icons.category_outlined;

  static Color _colorForTintName(String name) =>
      CategoryRepositoryIcons.tintsByName[name] ?? AppColors.pageTint;
}

/// The closed vocabulary of icon names and panel tints an admin can pick in
/// `shieldweb` — shared between this class and the direct-Neon
/// `CategoryRepository`'s own identical maps, since both parse the same
/// console-authored data, just from different transports.
abstract final class CategoryRepositoryIcons {
  static const Map<String, IconData> byName = {
    'spa_outlined': Icons.spa_outlined,
    'monitor_heart_outlined': Icons.monitor_heart_outlined,
    'medication_outlined': Icons.medication_outlined,
    'bloodtype_outlined': Icons.bloodtype_outlined,
    'medical_services_outlined': Icons.medical_services_outlined,
    'biotech_outlined': Icons.biotech_outlined,
    'face_retouching_natural_outlined': Icons.face_retouching_natural_outlined,
    'content_cut_rounded': Icons.content_cut_rounded,
    'clean_hands_outlined': Icons.clean_hands_outlined,
    'shower_outlined': Icons.shower_outlined,
    'face_outlined': Icons.face_outlined,
    'favorite_outline_rounded': Icons.favorite_outline_rounded,
    'accessibility_new_rounded': Icons.accessibility_new_rounded,
    'local_dining_outlined': Icons.local_dining_outlined,
    'remove_red_eye_outlined': Icons.remove_red_eye_outlined,
    'healing_outlined': Icons.healing_outlined,
    'smoke_free_rounded': Icons.smoke_free_rounded,
    'water_drop_outlined': Icons.water_drop_outlined,
    'medication_liquid_outlined': Icons.medication_liquid_outlined,
    'wb_sunny_outlined': Icons.wb_sunny_outlined,
    'fitness_center_rounded': Icons.fitness_center_rounded,
    'set_meal_outlined': Icons.set_meal_outlined,
    'emoji_food_beverage_outlined': Icons.emoji_food_beverage_outlined,
    'shield_outlined': Icons.shield_outlined,
    'speed_rounded': Icons.speed_rounded,
    'receipt_long_outlined': Icons.receipt_long_outlined,
    'coffee_outlined': Icons.coffee_outlined,
    'rice_bowl_outlined': Icons.rice_bowl_outlined,
    'airline_seat_legroom_normal_rounded':
        Icons.airline_seat_legroom_normal_rounded,
    'vaccines_outlined': Icons.vaccines_outlined,
    'masks_outlined': Icons.masks_outlined,
    'airline_seat_recline_normal_rounded':
        Icons.airline_seat_recline_normal_rounded,
    'fact_check_outlined': Icons.fact_check_outlined,
    'science_outlined': Icons.science_outlined,
  };

  static const Map<String, Color> tintsByName = {
    'panelGreen': AppColors.panelGreen,
    'panelCream': AppColors.panelCream,
    'panelBlue': AppColors.panelBlue,
    'panelPink': AppColors.panelPink,
    'panelSlate': AppColors.panelSlate,
    'pageTint': AppColors.pageTint,
  };
}
