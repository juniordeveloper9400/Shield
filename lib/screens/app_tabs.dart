import 'package:flutter/material.dart';

/// The bottom-navigation destinations, in display order.
///
/// This enum is the single source of truth for tab order. The shell, the
/// bottom bar, and the menu drawer all resolve positions through it, so
/// inserting or removing a destination cannot leave a hardcoded index
/// pointing at the wrong screen.
///
/// Home leads the bar rather than sitting in the middle of it, and every tab
/// is drawn as a glyph — the brand mark is on the header, and a logo in a
/// navigation bar is a destination nobody can name.
///
/// Categories, Clinics and Orders are not tabs. They are pushed as routes
/// from the home feed and the menu drawer, which is where a member goes
/// looking for them.
enum AppTab {
  home(
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
  ),
  labTest(
    label: 'Lab',
    icon: Icons.biotech_outlined,
    activeIcon: Icons.biotech_rounded,
  ),
  dietitian(
    label: 'Dietitian',
    icon: Icons.restaurant_menu_outlined,
    activeIcon: Icons.restaurant_menu_rounded,
  ),
  approvals(
    label: 'Approvals',
    icon: Icons.fact_check_outlined,
    activeIcon: Icons.fact_check_rounded,
  ),
  account(
    label: 'Account',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
  );

  /// One size for every tab now that no destination is drawn larger than its
  /// neighbours. The bar reserves this much for the icon row.
  static const double iconSize = 22;

  final String label;
  final IconData icon;
  final IconData activeIcon;

  const AppTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
