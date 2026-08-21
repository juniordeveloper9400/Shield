import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/menu/menu_drawer.dart';
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

    // The dashboard panel pushes the tail of the link list past the fold, so
    // the later entries have to be scrolled to before they are built.
    await tester.scrollUntilVisible(
      find.text('Health Library'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Health Library'), findsOneWidget);
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
    expect(find.text('₹3,472'), findsOneWidget);
    expect(find.text('Active orders'), findsOneWidget);
    expect(find.text('Cart items'), findsOneWidget);
    expect(find.text('Reward points'), findsOneWidget);
  });

  testWidgets('dashboard wallet tile opens the wallet screen', (tester) async {
    await pumpShell(tester);
    await openMenu(tester);

    await tester.tap(find.text('Wallet balance'));
    await tester.pumpAndSettle();

    expect(find.text('Menu'), findsNothing);
    expect(find.text('Available balance'), findsOneWidget);
  });
}
