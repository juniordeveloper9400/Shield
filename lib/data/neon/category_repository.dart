import 'package:flutter/material.dart';

import '../../module/categories/category_catalogue.dart';
import '../../theme/app_colors.dart';
import 'neon_http.dart';

/// Reads the storefront category catalogue — `app.product_category` and
/// `app.product_subcategory` — from Neon over the HTTP SQL endpoint.
///
/// Read-only. Categories and their banners are maintained from the admin
/// console (`shieldweb`'s "Category banners" page), never from the app; this
/// repository only lists what is published so `CategoryCatalog` can swap it in
/// for the bundled seed.
///
/// Best-effort, like the other Neon repositories: with no `DATABASE_URL`
/// compiled in, the network down, or a SQL error, [fetchAll] returns `null` —
/// never an empty list — so the caller keeps the seed rather than blanking the
/// Categories tab.
class CategoryRepository {
  const CategoryRepository._();

  static const CategoryRepository instance = CategoryRepository._();

  bool get isAvailable => NeonHttp.isConfigured;

  /// Every active category, with its sub-categories attached, in the admin's
  /// sort order. `null` when the database is off, unreachable, or the query
  /// failed; an empty result also maps to `null` so the caller keeps the seed.
  Future<List<CategoryGroup>?> fetchAll() async {
    if (!NeonHttp.isConfigured) {
      return null;
    }
    try {
      final categoryRows = await NeonHttp.instance.query(r'''
        SELECT id::text, title, tab_label, icon_name, image, banner_image,
               panel_tint, offer, sort
        FROM app.product_category
        WHERE is_active
        ORDER BY sort, id
      ''');
      if (categoryRows.isEmpty) {
        return null;
      }

      final subcategoryRows = await NeonHttp.instance.query(r'''
        SELECT category_id::text, label, icon_name, image, offer, sort
        FROM app.product_subcategory
        ORDER BY sort, id
      ''');

      final itemsByCategoryId = <String, List<SubCategory>>{};
      for (final row in subcategoryRows) {
        final categoryId = _str(row['category_id']);
        (itemsByCategoryId[categoryId] ??= []).add(_toSubCategory(row));
      }

      final groups = [
        for (final row in categoryRows)
          _toCategoryGroup(
            row,
            items: itemsByCategoryId[_str(row['id'])] ?? const [],
          ),
      ];
      return groups.isEmpty ? null : groups;
    } catch (error) {
      NeonHttp.log('CategoryRepository.fetchAll failed', error: error);
      return null;
    }
  }

  static String _str(Object? v) => (v ?? '').toString().trim();

  static CategoryGroup _toCategoryGroup(
    Map<String, dynamic> row, {
    required List<SubCategory> items,
  }) {
    final title = _str(row['title']);
    return CategoryGroup(
      title: title,
      tabLabel: _str(row['tab_label']).isEmpty ? title : _str(row['tab_label']),
      icon: iconForName(_str(row['icon_name'])),
      image: _str(row['image']).isEmpty ? null : _str(row['image']),
      bannerImage:
          _str(row['banner_image']).isEmpty ? null : _str(row['banner_image']),
      panelTint: colorForTintName(_str(row['panel_tint'])),
      items: items,
    );
  }

  static SubCategory _toSubCategory(Map<String, dynamic> row) {
    return SubCategory(
      _str(row['label']),
      iconForName(_str(row['icon_name'])),
      image: _str(row['image']).isEmpty ? null : _str(row['image']),
      offer: _str(row['offer']).isEmpty ? 'Up to 50% off' : _str(row['offer']),
    );
  }

  /// The closed vocabulary of icon names an admin can pick in `shieldweb` —
  /// every one already used by the bundled seed, keyed by the same string the
  /// console's picker sends. [iconForName] falls back to a generic icon for
  /// anything blank or not in this map, so a category never fails to render
  /// for want of an icon.
  static const Map<String, IconData> iconsByName = {
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

  static IconData iconForName(String name) =>
      iconsByName[name] ?? Icons.category_outlined;

  /// The closed vocabulary of panel tints — the same pastels the bundled
  /// groups use — keyed by name for the console's picker.
  static const Map<String, Color> tintsByName = {
    'panelGreen': AppColors.panelGreen,
    'panelCream': AppColors.panelCream,
    'panelBlue': AppColors.panelBlue,
    'panelPink': AppColors.panelPink,
    'panelSlate': AppColors.panelSlate,
    'pageTint': AppColors.pageTint,
  };

  static Color colorForTintName(String name) =>
      tintsByName[name] ?? AppColors.pageTint;
}
