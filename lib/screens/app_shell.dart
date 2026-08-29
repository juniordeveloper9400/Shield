import 'package:flutter/material.dart';

import '../module/account/account_screen.dart';
import '../module/appointment/clinics_screen.dart';
import '../module/health/health_section.dart';
import '../module/menu/menu_drawer.dart';
import '../module/orders/orders_screen.dart';
import '../module/registration/register_bar.dart';
import '../widgets/bottom_nav.dart';
import 'app_tabs.dart';
import 'home_screen.dart';

/// Holds the five primary destinations and the persistent chrome that sits
/// below them (the registration strip + bottom navigation).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Opens on Home, which now leads the bar.
  int _index = AppTab.home.index;
  HealthSubTab _healthSubTab = HealthSubTab.labsTests;

  bool get _inHealthSection => _index == AppTab.lab.index;

  /// Switches destination, and — when the caller names a sub-tab — lands on a
  /// specific page inside the health section rather than its default one.
  void _selectTab(int index, {HealthSubTab? subTab}) {
    setState(() {
      _index = index;
      if (subTab != null) {
        _healthSubTab = subTab;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: MenuDrawer(
        onSelectTab: _selectTab,
      ),
      // IndexedStack keeps each tab's scroll position alive across switches.
      // Order must match AppTab.values.
      body: IndexedStack(
        index: _index,
        children: [
          const HomeScreen(),
          HealthSection(
            active: _healthSubTab,
            onSelectSubTab: (tab) => setState(() => _healthSubTab = tab),
          ),
          const ClinicsScreen(),
          const OrdersScreen(),
          const AccountScreen(),
        ],
      ),
      // The health section takes over the bottom bar with its own
      // sub-navigation.
      bottomNavigationBar: _inHealthSection
          ? HealthBottomBar(
              active: _healthSubTab,
              onSelectSubTab: (tab) => setState(() => _healthSubTab = tab),
              onExitToHome: () => setState(() {
                _index = AppTab.home.index;
                // Reset so re-entering the section starts at its landing page.
                _healthSubTab = HealthSubTab.labsTests;
              }),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Owns its own visibility through RegistrationService, so
                // dismissing it here and anywhere else is the one decision.
                const RegisterBar(),
                ShieldBottomNav(
                  currentIndex: _index,
                  onTap: (index) => setState(() => _index = index),
                ),
              ],
            ),
    );
  }
}
