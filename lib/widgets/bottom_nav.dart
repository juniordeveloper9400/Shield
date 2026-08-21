import 'package:flutter/material.dart';

import '../screens/app_tabs.dart';
import '../theme/app_colors.dart';

/// Bottom navigation with a top active-indicator line and an icon-above-label
/// stack. Every destination is a glyph — no brand mark stands in for one.
///
/// The selected destination is marked by weight and colour alone — a brand
/// blue, bold label against muted, regular ones. There is no wash, glow or
/// tinted panel behind it: light spilling under five tabs muddies the white
/// bar, and the type is doing the job on its own.
///
/// Destinations come from [AppTab] so order stays consistent with the shell.
class ShieldBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ShieldBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const double _barHeight = 70;
  static const double _indicatorHeight = 3;

  /// Short solid line marking the active tab.
  static const Color activeLine = AppColors.brandBlue;

  /// Standard indicator width — deliberately much narrower than a tab, so the
  /// line reads as a marker rather than an edge.
  static const double indicatorWidth = 32;

  /// Height of the icon row, taken from [AppTab.iconSize] so a change there
  /// cannot silently clip the glyphs.
  static const double _iconSlot = AppTab.iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Plain white bar throughout: only the active tab carries colour, and
      // it carries it in the ink rather than behind it.
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
                for (final tab in AppTab.values)
                  Expanded(
                    child: _buildItem(
                      context,
                      tab: tab,
                      isSelected: tab.index == currentIndex,
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
    required AppTab tab,
    required bool isSelected,
  }) {
    // Matches the indicator: a green icon under a blue line would clash. The
    // unselected slate is the muted one, not the body one, so the gap to the
    // brand blue is wide enough to read at a glance.
    final color = isSelected ? AppColors.brandBlue : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: isSelected,
      label: tab.label,
      child: InkWell(
        onTap: () => onTap(tab.index),
        child: Column(
          children: [
            // Fixed height whether or not it is drawn, so selecting a tab
            // never shifts the row.
            SizedBox(
              height: _indicatorHeight,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: _indicatorHeight,
                  width: indicatorWidth,
                  decoration: BoxDecoration(
                    color: isSelected ? activeLine : AppColors.transparent,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(_indicatorHeight),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: _iconSlot,
              child: Center(
                child: Icon(
                  isSelected ? tab.activeIcon : tab.icon,
                  size: AppTab.iconSize,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 3),
            // With six destinations a long label such as "Appointment"
            // cannot fit at full size on a narrow phone, so it scales down
            // rather than ellipsing into something unreadable.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    textScaler: TextScaler.linear(
                      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.2),
                    ),
                    // Two steps apart, not one: at 11px a single step is
                    // not enough to tell the selected tab from its
                    // neighbours without comparing them side by side.
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
