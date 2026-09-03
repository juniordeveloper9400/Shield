import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/labtest/lab_cart_screen.dart';
import 'package:shield/module/menu/menu_drawer.dart';
import 'package:shield/module/wallet/wallet_screen.dart';
import 'package:shield/screens/app_shell.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Account reads the session, so sign in before mounting the shell.
    AuthService.instance.signInAs();
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('hamburger opens the menu drawer', (tester) async {
    await pumpShell(tester);
    expect(find.text('Menu'), findsNothing);

    await openMenu(tester);

    expect(find.text('Menu'), findsOneWidget);
    // The strip carries the number the session was signed in with.
    expect(
      find.text(AuthService.instance.currentUser.value!.phone),
      findsOneWidget,
    );
    expect(find.text('Add more user details >'), findsOneWidget);
    expect(find.text('Medicines'), findsOneWidget);

    // The dashboard panel and the investment call-out push the tail of the
    // link list past the fold, so the later entries have to be scrolled to
    // before they are built.
    await tester.scrollUntilVisible(
      find.text('Health Library'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Health Library'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Refer & earn'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Refer & earn'), findsOneWidget);
  });

  testWidgets('close button dismisses the drawer', (tester) async {
    await pumpShell(tester);
    await openMenu(tester);

    // Scoped to the drawer: the registration strip above the bottom bar
    // carries a close of its own.
    await tester.tap(
      find.descendant(
        of: find.byType(MenuDrawer),
        matching: find.byIcon(Icons.close_rounded),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Menu'), findsNothing);
  });

  /// The shaded account group sits past the fold of the drawer list, so it
  /// has to be scrolled into view before it can be tapped.
  Future<void> tapDrawerRow(WidgetTester tester, String label) async {
    final row = find.descendant(
      of: find.byType(Drawer),
      matching: find.text(label),
    );
    await tester.scrollUntilVisible(
      row,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  testWidgets('menu rows switch the active tab', (tester) async {
    await pumpShell(tester);
    await openMenu(tester);

    await tapDrawerRow(tester, 'My orders');

    // Drawer closed and the Orders destination is now foremost.
    expect(find.text('Menu'), findsNothing);
    expect(find.text('SHD-100482'), findsOneWidget);
  });

  testWidgets('account row reaches the Account destination', (tester) async {
    await pumpShell(tester);
    await openMenu(tester);

    await tapDrawerRow(tester, 'Account');

    expect(find.text('Rahul Nair'), findsOneWidget);
  });

  testWidgets('drawer fills the full screen width', (tester) async {
    await pumpShell(tester);
    await openMenu(tester);

    final drawerWidth = tester.getSize(find.byType(Drawer)).width;
    expect(drawerWidth, 400.0);
  });

  testWidgets('dashboard panel shows account stats', (tester) async {
    await pumpShell(tester);
    await openMenu(tester);

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Wallet balance'), findsOneWidget);
    // Empty until a privilege plan opens the wallet. The dashboard reads the
    // live balance, so with no plan activated there is nothing in it.
    //
    // Scoped to the drawer: the home feed behind it carries an earnings
    // section whose plan-bonus tile also reads ₹0 before a plan is activated.
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('₹0')),
      findsOneWidget,
    );
    expect(find.text('Active orders'), findsOneWidget);
    expect(find.text('Product cart'), findsOneWidget);
    expect(find.text('Lab cart'), findsOneWidget);
    expect(find.text('Reward points'), findsOneWidget);
  });

  testWidgets('dashboard lab tile opens the lab cart', (tester) async {
    await pumpShell(tester);
    await openMenu(tester);

    await tester.tap(find.text('Lab cart'));
    await tester.pumpAndSettle();

    expect(find.text('Menu'), findsNothing);
    expect(find.byType(LabCartScreen), findsOneWidget);
  });

  testWidgets('dashboard wallet tile opens the wallet screen', (tester) async {
    await pumpShell(tester);
    await openMenu(tester);

    await tester.tap(find.text('Wallet balance'));
    await tester.pumpAndSettle();

    expect(find.text('Menu'), findsNothing);
    // Reached by type rather than by the balance heading: with no privilege
    // card activated the wallet opens closed, and says so instead.
    expect(find.byType(WalletScreen), findsOneWidget);
    expect(find.text('Wallet locked'), findsOneWidget);
  });

  testWidgets('investment plan row sits under the dashboard and opens', (
    tester,
  ) async {
    await pumpShell(tester);
    await openMenu(tester);

    // The call-out row is visible without scrolling, right below the panel.
    expect(find.text('Investment Plan'), findsOneWidget);
    expect(
      find.text('100% assured ROI on every unit share'),
      findsOneWidget,
    );

    await tester.tap(find.text('Investment Plan'));
    await tester.pumpAndSettle();

    expect(find.text('Menu'), findsNothing);
    expect(find.text('The Investment Plan'), findsOneWidget);
  });
}
