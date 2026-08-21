import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/bottom_nav.dart';
import 'lab_test_screen.dart';
import 'top_packages_screen.dart';

/// Sub-destinations inside the lab section.
enum LabSubTab {
  labsTests(label: 'Labs Tests', icon: Icons.colorize_rounded),
  topPackages(label: 'Top Packages', icon: Icons.grid_view_rounded);

  final String label;
  final IconData icon;

  const LabSubTab({required this.label, required this.icon});
}

/// The lab experience, which carries its own bottom bar in place of the app's
/// main one. The leftmost item returns to the app's Home destination.
class LabSection extends StatelessWidget {
  final LabSubTab active;
  final ValueChanged<LabSubTab> onSelectSubTab;

  const LabSection({
    super.key,
    required this.active,
    required this.onSelectSubTab,
  });

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: active.index,
      children: [
        LabTestScreen(
          onSeeAllPackages: () => onSelectSubTab(LabSubTab.topPackages),
        ),
        TopPackagesScreen(onBack: () => onSelectSubTab(LabSubTab.labsTests)),
      ],
    );
  }
}

/// Bottom bar shown while the lab section is open.
class LabBottomBar extends StatelessWidget {
  final LabSubTab active;
  final ValueChanged<LabSubTab> onSelectSubTab;
  final VoidCallback onExitToHome;

  const LabBottomBar({
    super.key,
    required this.active,
    required this.onSelectSubTab,
    required this.onExitToHome,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      // Matches the app's main bar so the section swap is not also a colour
      // change.
      color: AppColors.white,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Expanded(
                  child: _LabBarItem(
                    label: 'Home',
                    icon: Icons.arrow_back_rounded,
                    isSelected: false,
                    // Circled glyph marks this as the way out of the section
                    // rather than another destination within it.
                    circled: true,
                    onTap: onExitToHome,
                  ),
                ),
                for (final tab in LabSubTab.values)
                  Expanded(
                    child: _LabBarItem(
                      label: tab.label,
                      icon: tab.icon,
                      isSelected: tab == active,
                      onTap: () => onSelectSubTab(tab),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabBarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool circled;
  final VoidCallback onTap;

  const _LabBarItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.circled = false,
  });

  @override
  Widget build(BuildContext context) {
    // The same muted slate the main bar uses, so the two bars mark their
    // selection identically as one replaces the other.
    final colour = isSelected ? AppColors.brandBlue : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: onTap,
        // Same short line and ink-only selected state as the app's main bar.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 3,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: 3,
                  width: ShieldBottomNav.indicatorWidth,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ShieldBottomNav.activeLine
                        : AppColors.transparent,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 30,
              child: Center(
                child: circled
                    ? Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colour, width: 1.4),
                        ),
                        child: Icon(icon, size: 17, color: colour),
                      )
                    : Icon(icon, size: 23, color: colour),
              ),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: colour,
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
