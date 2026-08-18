import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bottom navigation with a top active-indicator bar, icon-above-label stack,
/// and blue/slate active-inactive treatment.
class ShieldBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ShieldBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const double _barHeight = 64;
  static const double _indicatorWidth = 34;
  static const double _indicatorHeight = 3;

  static const List<_NavItem> items = [
    _NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _NavItem(
      label: 'Categories',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
    _NavItem(
      label: 'Orders',
      icon: Icons.collections_bookmark_outlined,
      activeIcon: Icons.collections_bookmark_rounded,
    ),
    _NavItem(
      label: 'Account',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: _barHeight,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: _buildItem(
                      context,
                      item: items[index],
                      index: index,
                      isSelected: index == currentIndex,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required _NavItem item,
    required int index,
    required bool isSelected,
  }) {
    final color = isSelected ? AppColors.brandBlue : AppColors.textBody;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: AppColors.brandBlue.withValues(alpha: 0.06),
        highlightColor: AppColors.brandBlue.withValues(alpha: 0.04),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: _indicatorHeight,
              width: _indicatorWidth,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandBlue : AppColors.transparent,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(_indicatorHeight),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Icon(
              isSelected ? item.activeIcon : item.icon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Clamped so large system text scaling cannot overflow the bar.
              textScaler: TextScaler.linear(
                MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3),
              ),
              style: TextStyle(
                fontSize: 12,
                height: 1.1,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
