import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// "Shop by categories" block: a row of selectable category chips above a
/// panel of sub-category cards for whichever chip is active.
class CategorySection extends StatefulWidget {
  const CategorySection({super.key});

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  int _selected = 1;

  static const List<_Category> _categories = [
    _Category(
      label: 'Personal\nCare',
      icon: Icons.spa_outlined,
      tint: Color(0xFFE9F2FB),
      items: [
        _SubItem('Skin Care', Icons.face_retouching_natural_outlined),
        _SubItem('Hair Care', Icons.content_cut_rounded),
        _SubItem('Oral Care', Icons.clean_hands_outlined),
        _SubItem('Bath & Body', Icons.shower_outlined),
        _SubItem('Men Grooming', Icons.face_outlined),
        _SubItem('Feminine Care', Icons.favorite_outline_rounded),
      ],
    ),
    _Category(
      label: 'Health\nConditions',
      icon: Icons.monitor_heart_outlined,
      tint: Color(0xFFFBECEC),
      items: [
        _SubItem('Bone and Joint Care', Icons.accessibility_new_rounded),
        _SubItem('Digestive Care', Icons.local_dining_outlined),
        _SubItem('Eye Care', Icons.remove_red_eye_outlined),
        _SubItem('Pain Relief', Icons.healing_outlined),
        _SubItem('Smoking Cessation', Icons.smoke_free_rounded),
        _SubItem('Liver Care', Icons.water_drop_outlined),
      ],
    ),
    _Category(
      label: 'Vitamins &\nSupplements',
      icon: Icons.medication_outlined,
      tint: Color(0xFFFDF6E3),
      items: [
        _SubItem('Multivitamins', Icons.medication_liquid_outlined),
        _SubItem('Vitamin D', Icons.wb_sunny_outlined),
        _SubItem('Protein Powder', Icons.fitness_center_rounded),
        _SubItem('Omega & Fish Oil', Icons.set_meal_outlined),
        _SubItem('Calcium', Icons.emoji_food_beverage_outlined),
        _SubItem('Immunity', Icons.shield_outlined),
      ],
    ),
    _Category(
      label: 'Diabetes\nCare',
      icon: Icons.bloodtype_outlined,
      tint: Color(0xFFEAF5EC),
      items: [
        _SubItem('Glucometers', Icons.speed_rounded),
        _SubItem('Test Strips', Icons.receipt_long_outlined),
        _SubItem('Sugar Substitutes', Icons.coffee_outlined),
        _SubItem('Diabetic Food', Icons.rice_bowl_outlined),
        _SubItem('Foot Care', Icons.airline_seat_legroom_normal_rounded),
        _SubItem('Insulin Support', Icons.vaccines_outlined),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final active = _categories[_selected];

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Shop by categories',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < _categories.length; index++)
                Expanded(
                  child: _CategoryTab(
                    category: _categories[index],
                    isSelected: index == _selected,
                    onTap: () => setState(() => _selected = index),
                  ),
                ),
            ],
          ),
          Container(
            width: double.infinity,
            color: AppColors.categoryPanel,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: Column(
              children: [
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.74,
                  children: [
                    for (final item in active.items)
                      _SubCategoryCard(item: item, tint: active.tint),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'View all ${active.label.replaceAll('\n', ' ').toLowerCase()} products  »',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final _Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The active chip visually merges into the panel below it.
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.categoryPanel : AppColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.white : category.tint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.icon,
                size: 30,
                color: AppColors.brandBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubCategoryCard extends StatelessWidget {
  final _SubItem item;
  final Color tint;

  const _SubCategoryCard({required this.item, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Up to 50% off',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandGreenDeep,
                ),
              ),
              const SizedBox(height: 6),
              // Expanded + FittedBox lets the thumbnail shrink on narrow
              // viewports instead of overflowing the fixed-ratio grid cell.
              Expanded(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.icon,
                        size: 24,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Category {
  final String label;
  final IconData icon;
  final Color tint;
  final List<_SubItem> items;

  const _Category({
    required this.label,
    required this.icon,
    required this.tint,
    required this.items,
  });
}

class _SubItem {
  final String label;
  final IconData icon;

  const _SubItem(this.label, this.icon);
}
