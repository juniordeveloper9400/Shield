import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Full category browser reached from the Categories tab.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const List<_CategoryGroup> _groups = [
    _CategoryGroup('Personal Care', [
      _Tile('Skin Care', Icons.face_retouching_natural_outlined),
      _Tile('Hair Care', Icons.content_cut_rounded),
      _Tile('Oral Care', Icons.clean_hands_outlined),
      _Tile('Bath & Body', Icons.shower_outlined),
    ]),
    _CategoryGroup('Health Conditions', [
      _Tile('Bone & Joint', Icons.accessibility_new_rounded),
      _Tile('Digestive Care', Icons.local_dining_outlined),
      _Tile('Eye Care', Icons.remove_red_eye_outlined),
      _Tile('Pain Relief', Icons.healing_outlined),
    ]),
    _CategoryGroup('Vitamins & Supplements', [
      _Tile('Multivitamins', Icons.medication_liquid_outlined),
      _Tile('Protein Powder', Icons.fitness_center_rounded),
      _Tile('Immunity', Icons.shield_outlined),
      _Tile('Calcium', Icons.emoji_food_beverage_outlined),
    ]),
    _CategoryGroup('Diabetes Care', [
      _Tile('Glucometers', Icons.speed_rounded),
      _Tile('Test Strips', Icons.receipt_long_outlined),
      _Tile('Diabetic Food', Icons.rice_bowl_outlined),
      _Tile('Insulin Support', Icons.vaccines_outlined),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Categories',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          for (final group in _groups) ...[
            Text(
              group.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
              children: [
                for (final tile in group.tiles) _CategoryTile(tile: tile),
              ],
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final _Tile tile;

  const _CategoryTile({required this.tile});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.pageTint,
              shape: BoxShape.circle,
            ),
            child: Icon(tile.icon, size: 27, color: AppColors.brandBlue),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Text(
              tile.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGroup {
  final String title;
  final List<_Tile> tiles;

  const _CategoryGroup(this.title, this.tiles);
}

class _Tile {
  final String label;
  final IconData icon;

  const _Tile(this.label, this.icon);
}
