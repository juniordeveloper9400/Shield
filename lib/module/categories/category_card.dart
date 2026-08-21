import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import 'category_catalogue.dart';

/// The white sub-category card: caption, offer line, and the product artwork
/// filling whatever is left.
///
/// Shared by the home "Shop by categories" strip and the Categories tab, so a
/// change to one is a change to both.
class CategoryCard extends StatelessWidget {
  final SubCategory item;
  final VoidCallback? onTap;

  const CategoryCard({super.key, required this.item, this.onTap});

  /// Taller than wide: the two text lines take a fixed slice off the top, so
  /// every extra pixel of height goes to the artwork.
  static const double aspectRatio = 0.70;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap ?? () {},
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
              Text(
                item.offer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandGreenDeep,
                ),
              ),
              const SizedBox(height: 6),
              // The artwork takes every pixel left under the labels, unboxed
              // and bottom-left, so the product bundle reads at full size.
              // Expanded means it absorbs the slack rather than overflowing
              // the fixed-ratio grid cell on a narrow viewport.
              Expanded(
                child: SizedBox(
                  // Full remaining box, not just the remaining height: the
                  // artwork then scales to whichever dimension binds first and
                  // renders as large as the cell allows, still uncropped.
                  width: double.infinity,
                  child: AppImage(
                    image: item.image,
                    fallbackIcon: item.icon,
                    iconSize: 44,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomLeft,
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

/// A group rendered the way the Categories tab shows it: a tinted panel of
/// cards closed by a "View all …" link.
class CategoryPanel extends StatelessWidget {
  final CategoryGroup group;
  final ValueChanged<SubCategory>? onSelect;
  final VoidCallback? onViewAll;

  const CategoryPanel({
    super.key,
    required this.group,
    this.onSelect,
    this.onViewAll,
  });

  /// Below this width three columns leave the captions too narrow to read, so
  /// the grid drops to two.
  static const double threeColumnWidth = 340;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: group.panelTint,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => GridView.count(
              crossAxisCount: constraints.maxWidth >= threeColumnWidth ? 3 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: CategoryCard.aspectRatio,
              children: [
                for (final item in group.items)
                  CategoryCard(
                    item: item,
                    onTap: onSelect == null ? null : () => onSelect!(item),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onViewAll ?? () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    group.viewAllLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.brandBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
