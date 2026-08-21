import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/account/account_screen.dart';
import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/location/address_book.dart';
import 'package:shield/module/location/address_form_screen.dart';
import 'package:shield/module/location/location_sheet.dart';
import 'package:shield/screens/app_shell.dart';

void main() {
  setUp(AddressBook.instance.reset);
  tearDown(AddressBook.instance.reset);

  Future<void> pumpForm(
    WidgetTester tester, {
    Size size = const Size(400, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AddressFormScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> fillHint(WidgetTester tester, String hint, String value) async {
    await tester.enterText(find.widgetWithText(TextFormField, hint), value);
  }

  group('address book', () {
    test('starts empty and stores what is added', () {
      final book = AddressBook.instance;
      expect(book.isEmpty, isTrue);

      book.add(
        const Address(
          pincode: '400079',
          house: '12B, Second Floor',
          area: 'Ghatkopar East',
          firstName: 'Althaf',
          lastName: 'M',
          phone: '9895357101',
          label: AddressLabel.home,
        ),
      );

      expect(book.addresses, hasLength(1));
      expect(book.addresses.single.receiver, 'Althaf M');
    });

    test('the summary joins the filled parts only', () {
      const withoutLandmark = Address(
        pincode: '400079',
        house: '12B',
        area: 'Ghatkopar',
        firstName: 'Althaf',
        phone: '9895357101',
        label: AddressLabel.home,
      );
      expect(withoutLandmark.summary, '12B, Ghatkopar, 400079');

      const withLandmark = Address(
        pincode: '400079',
        house: '12B',
        area: 'Ghatkopar',
        landmark: 'Near the station',
        firstName: 'Althaf',
        phone: '9895357101',
        label: AddressLabel.home,
      );
      expect(withLandmark.summary, '12B, Ghatkopar, Near the station, 400079');
    });

    test('a receiver with no last name reads as the first name alone', () {
      const address = Address(
        pincode: '400079',
        house: '12B',
        area: 'Ghatkopar',
        firstName: 'Althaf',
        phone: '9895357101',
        label: AddressLabel.home,
      );
      expect(address.receiver, 'Althaf');
    });
  });

  group('the form', () {
    testWidgets('renders every field from the reference', (tester) async {
      await pumpForm(tester);

      expect(find.text('Add address details'), findsOneWidget);
      expect(find.text('Search by building, area or pincode'), findsOneWidget);
      expect(find.text('OR'), findsOneWidget);
      expect(find.text('Pincode'), findsOneWidget);
      expect(find.text('Current Location'), findsOneWidget);
      expect(find.text('House no / Floor / Building'), findsOneWidget);
      expect(find.text('Area / Locality'), findsOneWidget);
      expect(find.text('Landmark (Optional)'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Receiver details'), findsOneWidget);
      expect(find.text('First name'), findsOneWidget);
      expect(find.text('Last name'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(
        find.text("We'll share delivery related updates on this number"),
        findsOneWidget,
      );
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('saving an empty form reports what is required', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a 6-digit pincode'), findsOneWidget);
      expect(find.text('Enter a valid 10-digit number'), findsOneWidget);
      // House, area and first name are each required.
      expect(find.text('Required'), findsNWidgets(3));
      expect(AddressBook.instance.isEmpty, isTrue);
    });

    testWidgets('a short pincode is rejected', (tester) async {
      await pumpForm(tester);

      await fillHint(tester, 'Pincode', '4000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a 6-digit pincode'), findsOneWidget);
      expect(AddressBook.instance.isEmpty, isTrue);
    });

    testWidgets('a complete form saves and closes', (tester) async {
      await pumpForm(tester);

      await fillHint(tester, 'Pincode', '400079');
      await fillHint(tester, 'House no / Floor / Building', '12B, 2nd Floor');
      await fillHint(tester, 'Area / Locality', 'Ghatkopar East');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'),
        'Althaf',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Last name'),
        'M',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile Number'),
        '9895357101',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = AddressBook.instance.addresses.single;
      expect(saved.pincode, '400079');
      expect(saved.area, 'Ghatkopar East');
      expect(saved.receiver, 'Althaf M');
      // Home is the default label.
      expect(saved.label, AddressLabel.home);
    });

    testWidgets('the label chip changes what is stored', (tester) async {
      await pumpForm(tester);

      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      await fillHint(tester, 'Pincode', '400079');
      await fillHint(tester, 'House no / Floor / Building', '12B');
      await fillHint(tester, 'Area / Locality', 'Ghatkopar');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'),
        'Althaf',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile Number'),
        '9895357101',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(AddressBook.instance.addresses.single.label, AddressLabel.work);
    });

    testWidgets('lays out on a narrow phone', (tester) async {
      await pumpForm(tester, size: const Size(320, 1600));

      expect(find.text('Current Location'), findsOneWidget);
      expect(find.text('Receiver details'), findsOneWidget);
    });
  });

  group('entry points', () {
    testWidgets('the location sheet opens the form', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(LocationSheet.describe('400079')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage addresses'));
      await tester.pumpAndSettle();

      expect(find.byType(AddressFormScreen), findsOneWidget);
      // The sheet closed rather than sitting under the form.
      expect(find.text('Choose your location'), findsNothing);
    });

    testWidgets('the account row is named Manage addresses and opens it', (
      tester,
    ) async {
      AuthService.instance.signInAs();
      addTearDown(AuthService.instance.reset);

      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Manage addresses'), findsOneWidget);
      expect(find.text('Saved Addresses'), findsNothing);

      await tester.tap(find.text('Manage addresses'));
      await tester.pumpAndSettle();

      expect(find.byType(AddressFormScreen), findsOneWidget);
    });
  });

  group('the home header follows the address book', () {
    test('the location starts as the default pincode and its city', () {
      expect(AddressBook.instance.locationLabel, '400079, Mumbai');
      expect(AddressBook.instance.deliverTo, isNull);
    });

    test('a saved address names its own locality, not the city', () {
      AddressBook.instance.add(
        const Address(
          pincode: '682001',
          house: '12B',
          area: 'Marine Drive',
          firstName: 'Althaf',
          phone: '9895357101',
          label: AddressLabel.home,
        ),
      );

      // Not '682001, Kochi': the address is more specific than the lookup.
      expect(AddressBook.instance.locationLabel, '682001, Marine Drive');
      expect(AddressBook.instance.pincode, '682001');
    });

    test('a bare pincode from the sheet replaces the saved address', () {
      AddressBook.instance.add(
        const Address(
          pincode: '682001',
          house: '12B',
          area: 'Marine Drive',
          firstName: 'Althaf',
          phone: '9895357101',
          label: AddressLabel.home,
        ),
      );

      AddressBook.instance.setPincode('110001');

      expect(AddressBook.instance.deliverTo, isNull);
      expect(AddressBook.instance.locationLabel, '110001, Delhi');
    });

    test('deleting the address being delivered to clears it', () {
      AddressBook.instance.add(
        const Address(
          pincode: '682001',
          house: '12B',
          area: 'Marine Drive',
          firstName: 'Althaf',
          phone: '9895357101',
          label: AddressLabel.home,
        ),
      );

      AddressBook.instance.removeAt(0);

      expect(AddressBook.instance.deliverTo, isNull);
      expect(AddressBook.instance.locationLabel, '400079, Mumbai');
    });

    testWidgets('saving an address updates the home header', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();

      expect(find.text('400079, Mumbai'), findsOneWidget);

      // Location sheet → Manage addresses → fill in → Save.
      await tester.tap(find.text('400079, Mumbai'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage addresses'));
      await tester.pumpAndSettle();

      await fillHint(tester, 'Pincode', '682001');
      await fillHint(tester, 'House no / Floor / Building', '12B');
      await fillHint(tester, 'Area / Locality', 'Marine Drive');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'),
        'Althaf',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile Number'),
        '9895357101',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Back on home, showing the pincode and place that were just saved.
      expect(find.byType(AddressFormScreen), findsNothing);
      expect(find.text('682001, Marine Drive'), findsOneWidget);
      expect(find.text('400079, Mumbai'), findsNothing);
    });
  });
}
