import 'package:flutter/material.dart';

import '../module/account/account_screen.dart';
import '../module/categories/categories_screen.dart';
import '../module/menu/menu_drawer.dart';
import '../module/orders/orders_screen.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/coupon_bar.dart';
import 'home_screen.dart';

/// Holds the four primary destinations and the persistent chrome that sits
/// below them (promo strip + bottom navigation).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _couponVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: MenuDrawer(
        onSelectTab: (index) => setState(() => _index = index),
      ),
      // IndexedStack keeps each tab's scroll position alive across switches.
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          CategoriesScreen(),
          OrdersScreen(),
          AccountScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_couponVisible)
            CouponBar(
              onApply: () {
                setState(() => _couponVisible = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coupon applied')),
                );
              },
            ),
          ShieldBottomNav(
            currentIndex: _index,
            onTap: (index) => setState(() => _index = index),
          ),
        ],
      ),
    );
  }
}
