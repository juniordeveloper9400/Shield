import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/orders/orders_screen.dart';
import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/home/home_hero_banner.dart';
import 'package:shield/screens/app_shell.dart';
import 'package:shield/screens/app_tabs.dart';
import 'package:shield/theme/app_colors.dart';
import 'package:shield/widgets/bottom_nav.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Account reads the session, so sign in before mounting the shell.
    AuthService.instance.signInAs();
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();
  }

  group('tab contract', () {
    test('home leads the bar, and the routes are not tabs', () {
      expect(AppTab.values.map((t) => t.label).toList(), [
        'Home',
        'Lab',
        'Dietitian',
        'Approvals',
        'Account',
      ]);

      expect(AppTab.home.index, 0, reason: 'Home leads rather than centres');

      for (final absent in const [
        'Orders',
        'Categories',
        'Appointment',
        'Clinics',
      ]) {
        expect(
          AppTab.values.any((t) => t.label == absent),
          isFalse,
          reason: '$absent is reached as a route, not a tab',
        );
      }
    });

    test('every tab is a glyph, all the same size', () {
      // The brand mark is on the header. A logo in a navigation bar is a
      // destination nobody can name, so no tab carries one.
      expect(AppTab.iconSize, 22);
      for (final tab in AppTab.values) {
        expect(tab.icon, isNot(tab.activeIcon), reason: tab.label);
      }
    });
  });

  testWidgets('no image is drawn in the bar', (tester) async {
    await pumpShell(tester);

    expect(
      find.descendant(
        of: find.byType(ShieldBottomNav),
        matching: find.byType(Image),
      ),
      findsNothing,
      reason: 'the shield mark is gone from the bar',
    );
    expect(
      find.descendant(
        of: find.byType(ShieldBottomNav),
        matching: find.byType(Icon),
      ),
      findsNWidgets(AppTab.values.length),
    );
  });

  testWidgets('the two new destinations open from the bar', (tester) async {
    await pumpShell(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(ShieldBottomNav),
        matching: find.text('Dietitian'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Talk to a dietitian'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(ShieldBottomNav),
        matching: find.text('Approvals'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('need your approval'), findsOneWidget);
  });

  testWidgets('shell opens on Home', (tester) async {
    await pumpShell(tester);

    expect(find.byType(HomeHeroBanner), findsOneWidget);
  });

  testWidgets('all five destinations render in the bar', (tester) async {
    await pumpShell(tester);

    for (final tab in AppTab.values) {
      expect(find.text(tab.label), findsWidgets, reason: tab.label);
    }
    expect(find.text('Orders'), findsNothing);
  });

  testWidgets('the home tab shows the shield mark, not a glyph', (
    tester,
  ) async {
    await pumpShell(tester);

    final marks = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/logos/shield_logo.png',
    );
    expect(marks, findsWidgets);
  });

  testWidgets('the lab tab takes over the bar and hands it back', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
    expect(find.text('Collect sample from'), findsOneWidget);

    // The lab section swaps in its own bar, so the main tabs are gone until
    // its Home item returns us to the shell.
    expect(find.text('Approvals'), findsNothing);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Approvals'), findsOneWidget);
    expect(find.byType(HomeHeroBanner), findsOneWidget);
  });

  testWidgets('account still resolves after orders was removed', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Rahul Nair'), findsOneWidget);
  });

  testWidgets('orders is reachable from the drawer as a pushed route', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    final row = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('My orders'),
    );
    await tester.scrollUntilVisible(
      row,
      140,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.text('SHD-100482'), findsOneWidget);
    // Pushed, so it must offer a way back.
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('five tabs fit a narrow phone', (tester) async {
    await pumpShell(tester, size: const Size(320, 900));

    for (final tab in AppTab.values) {
      expect(find.text(tab.label), findsWidgets);
    }
  });

  testWidgets('the bar is white and the active tab is marked in blue', (
    tester,
  ) async {
    await pumpShell(tester);

    // The bar itself.
    final bar = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(ShieldBottomNav),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(bar.color, AppColors.white);

    // Exactly one tab shows the indicator line, and it is blue.
    final lines = tester
        .widgetList<AnimatedContainer>(
          find.descendant(
            of: find.byType(ShieldBottomNav),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.color == ShieldBottomNav.activeLine)
        .toList();
    expect(lines, hasLength(1));
    expect(ShieldBottomNav.activeLine, AppColors.brandBlue);
  });

  testWidgets('the line is a standard width, far narrower than its tab', (
    tester,
  ) async {
    await pumpShell(tester);

    final marked = find.descendant(
      of: find.byType(ShieldBottomNav),
      matching: find.byWidgetPredicate((widget) {
        if (widget is! AnimatedContainer) {
          return false;
        }
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.color == ShieldBottomNav.activeLine;
      }),
    );
    expect(marked, findsOneWidget);

    final lineWidth = tester.getSize(marked).width;
    final tabWidth = 400 / AppTab.values.length;

    expect(lineWidth, ShieldBottomNav.indicatorWidth);
    expect(
      lineWidth,
      lessThan(tabWidth),
      reason: 'the line must read as a marker, not a full-width edge',
    );
  });

  testWidgets('nothing washes or glows behind the active tab', (tester) async {
    await pumpShell(tester);

    // Container and AnimatedContainer both build a DecoratedBox, so scanning
    // for one catches every painted decoration in the bar.
    final washes = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(ShieldBottomNav),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.gradient != null)
        .toList();

    expect(
      washes,
      isEmpty,
      reason: 'the selected tab is marked in ink, not in light behind it',
    );
    expect(
      find.descendant(
        of: find.byType(ShieldBottomNav),
        matching: find.byType(ClipPath),
      ),
      findsNothing,
      reason: 'no clipped beam survives',
    );
  });

  testWidgets('the selected link alone is blue and bold', (tester) async {
    // The shell opens on Home.
    await pumpShell(tester);

    TextStyle labelStyle(String label) => tester
        .widget<Text>(
          find.descendant(
            of: find.byType(ShieldBottomNav),
            matching: find.text(label),
          ),
        )
        .style!;

    final home = labelStyle('Home');
    expect(home.color, AppColors.brandBlue);
    expect(home.fontWeight, FontWeight.w800);

    for (final tab in AppTab.values.where((tab) => tab != AppTab.home)) {
      final other = labelStyle(tab.label);
      expect(other.color, AppColors.textMuted, reason: tab.label);
      expect(other.fontWeight, FontWeight.w500, reason: tab.label);
      expect(
        home.fontWeight!.index,
        greaterThan(other.fontWeight!.index),
        reason: 'Home must out-weigh ${tab.label}',
      );
    }
  });

  testWidgets('the treatment follows the tab that is tapped', (tester) async {
    await pumpShell(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(ShieldBottomNav),
        matching: find.text('Account'),
      ),
    );
    await tester.pumpAndSettle();

    TextStyle labelStyle(String label) => tester
        .widget<Text>(
          find.descendant(
            of: find.byType(ShieldBottomNav),
            matching: find.text(label),
          ),
        )
        .style!;

    expect(labelStyle('Account').fontWeight, FontWeight.w800);
    expect(labelStyle('Account').color, AppColors.brandBlue);
    expect(labelStyle('Home').fontWeight, FontWeight.w500);
    expect(labelStyle('Home').color, AppColors.textMuted);
  });
}
