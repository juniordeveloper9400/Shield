import 'package:flutter/material.dart';

import '../module/account/account_screen.dart';
import '../module/approvals/approvals_screen.dart';
import '../module/dietitian/dietitian_screen.dart';
import '../module/labtest/lab_section.dart';
import '../module/menu/menu_drawer.dart';
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
  LabSubTab _labSubTab = LabSubTab.labsTests;

  bool get _inLabSection => _index == AppTab.labTest.index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: MenuDrawer(
        onSelectTab: (index) => setState(() => _index = index),
      ),
      // IndexedStack keeps each tab's scroll position alive across switches.
      // Order must match AppTab.values.
      body: IndexedStack(
        index: _index,
        children: [
          const HomeScreen(),
          LabSection(
            active: _labSubTab,
            onSelectSubTab: (tab) => setState(() => _labSubTab = tab),
          ),
          const DietitianScreen(),
          const ApprovalsScreen(),
          const AccountScreen(),
        ],
      ),
      // The lab section takes over the bottom bar with its own sub-navigation.
      bottomNavigationBar: _inLabSection
          ? LabBottomBar(
              active: _labSubTab,
              onSelectSubTab: (tab) => setState(() => _labSubTab = tab),
              onExitToHome: () => setState(() {
                _index = AppTab.home.index;
                // Reset so re-entering the section starts at its landing page.
                _labSubTab = LabSubTab.labsTests;
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
