import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/data/backend/care_repository.dart';
import 'package:shield/module/location/location_sheet.dart';
import 'package:shield/module/labtest/lab_test_screen.dart';

/// [LocationSheet]'s own behaviour — validation, known-city labels, closing
/// without changing anything — exercised through the Lab landing screen's
/// "Collect sample from" row, one of the surfaces that still opens it (the
/// home header's own location chip was removed; see the home_header history
/// for why).
void main() {
  tearDown(() {
    CareRepository.labPackagesOverride = null;
    CareRepository.labCategoriesOverride = null;
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    CareRepository.labPackagesOverride = () async => const [];
    CareRepository.labCategoriesOverride = () async => const [];

    await tester.pumpWidget(const MaterialApp(home: LabTestScreen()));
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
    await tester.tap(find.text('Select location'));
    await tester.pumpAndSettle();
  }

  test('describe names known cities and passes others through', () {
    expect(LocationSheet.describe('400079'), '400079, Mumbai');
    expect(LocationSheet.describe('682001'), '682001, Kochi');
    expect(LocationSheet.describe('999999'), '999999');
  });

  testWidgets('tapping the location opens the sheet', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Choose your location'), findsNothing);

    await openSheet(tester);

    expect(find.text('Choose your location'), findsOneWidget);
    expect(find.text('Use current location'), findsOneWidget);
    expect(find.text('Manage addresses'), findsOneWidget);
    // Nothing chosen yet on this screen, so the field starts blank.
    expect(tester.widget<TextField>(sheetField()).controller?.text, '');
  });

  testWidgets('close button dismisses without changing the location', (
    tester,
  ) async {
    await pumpScreen(tester);
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
    expect(find.text('Select location'), findsOneWidget);
  });

  testWidgets('a valid pincode updates the row', (tester) async {
    await pumpScreen(tester);
    await openSheet(tester);

    await tester.enterText(sheetField(), '682001');
    await tester.tap(sheetSubmit());
    await tester.pumpAndSettle();

    expect(find.text('Choose your location'), findsNothing);
    expect(find.text('682001, Kochi'), findsOneWidget);
    expect(find.text('Select location'), findsNothing);
  });

  testWidgets('an unknown pincode shows without a city', (tester) async {
    await pumpScreen(tester);
    await openSheet(tester);

    await tester.enterText(sheetField(), '123456');
    await tester.tap(sheetSubmit());
    await tester.pumpAndSettle();

    expect(find.text('123456'), findsOneWidget);
  });

  testWidgets('a short pincode is rejected and the sheet stays open', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openSheet(tester);

    await tester.enterText(sheetField(), '4000');
    await tester.tap(sheetSubmit());
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid 6-digit pincode'), findsOneWidget);
    expect(find.text('Choose your location'), findsOneWidget);
  });
}
