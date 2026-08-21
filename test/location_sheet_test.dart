import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/location/address_book.dart';
import 'package:shield/module/location/location_sheet.dart';
import 'package:shield/screens/app_shell.dart';

void main() {
  // The delivery location now lives in a singleton rather than in the header's
  // own state, so a test that changes it would otherwise carry that change
  // into the next one.
  setUp(AddressBook.instance.reset);
  tearDown(AddressBook.instance.reset);

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();
  }

  // The home screen behind the sheet has its own search TextField, so these
  // finders must be scoped to the sheet subtree or they hit the wrong widget.
  Finder sheetField() => find.descendant(
    of: find.byType(LocationSheet),
    matching: find.byType(TextField),
  );

  Finder sheetSubmit() => find.descendant(
    of: find.byType(LocationSheet),
    matching: find.byIcon(Icons.location_on_outlined),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('400079, Mumbai'));
    await tester.pumpAndSettle();
  }

  test('describe names known cities and passes others through', () {
    expect(LocationSheet.describe('400079'), '400079, Mumbai');
    expect(LocationSheet.describe('682001'), '682001, Kochi');
    expect(LocationSheet.describe('999999'), '999999');
  });

  testWidgets('tapping the location opens the sheet', (tester) async {
    await pumpShell(tester);
    expect(find.text('Choose your location'), findsNothing);

    await openSheet(tester);

    expect(find.text('Choose your location'), findsOneWidget);
    expect(find.text('Use current location'), findsOneWidget);
    expect(find.text('Manage addresses'), findsOneWidget);
    // Pre-filled with the pincode currently in use.
    expect(find.widgetWithText(TextField, '400079'), findsOneWidget);
  });

  testWidgets('close button dismisses without changing the location', (
    tester,
  ) async {
    await pumpShell(tester);
    await openSheet(tester);

    // Scoped to the sheet: the registration strip above the bottom bar
    // carries a close of its own.
    await tester.tap(
      find.descendant(
        of: find.byType(LocationSheet),
        matching: find.byIcon(Icons.close_rounded),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose your location'), findsNothing);
    expect(find.text('400079, Mumbai'), findsOneWidget);
  });

  testWidgets('a valid pincode updates the header', (tester) async {
    await pumpShell(tester);
    await openSheet(tester);

    await tester.enterText(sheetField(), '682001');
    await tester.tap(sheetSubmit());
    await tester.pumpAndSettle();

    expect(find.text('Choose your location'), findsNothing);
    expect(find.text('682001, Kochi'), findsOneWidget);
    expect(find.text('400079, Mumbai'), findsNothing);
  });

  testWidgets('an unknown pincode shows without a city', (tester) async {
    await pumpShell(tester);
    await openSheet(tester);

    await tester.enterText(sheetField(), '123456');
    await tester.tap(sheetSubmit());
    await tester.pumpAndSettle();

    expect(find.text('123456'), findsOneWidget);
  });

  testWidgets('a short pincode is rejected and the sheet stays open', (
    tester,
  ) async {
    await pumpShell(tester);
    await openSheet(tester);

    await tester.enterText(sheetField(), '4000');
    await tester.tap(sheetSubmit());
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid 6-digit pincode'), findsOneWidget);
    expect(find.text('Choose your location'), findsOneWidget);
  });
}
