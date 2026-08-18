import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/screens/app_shell.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
    expect(find.text('9400525063'), findsOneWidget);
    expect(find.text('Add more user details >'), findsOneWidget);
    expect(find.text('Medicines'), findsOneWidget);
    expect(find.text('Health Library'), findsOneWidget);
    expect(find.text('Refer & earn'), findsOneWidget);
  });

  testWidgets('close button dismisses the drawer', (tester) async {
    await pumpShell(tester);
    await openMenu(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
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
    await tester.scrollUntilVisible(row, 120, scrollable: find.byType(Scrollable).last);
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
}
