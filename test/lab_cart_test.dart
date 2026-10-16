import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/data/backend/care_repository.dart';
import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/auth/login_screen.dart';
import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/labtest/lab_booking_placed_screen.dart';
import 'package:shield/module/labtest/lab_cart_badge.dart';
import 'package:shield/module/labtest/lab_cart_screen.dart';
import 'package:shield/module/labtest/lab_cart_service.dart';
import 'package:shield/module/labtest/lab_checkout_screen.dart';
import 'package:shield/module/labtest/lab_package.dart';
import 'package:shield/module/labtest/lab_package_screen.dart';
import 'package:shield/module/labtest/lab_patient_picker_sheet.dart';
import 'package:shield/module/labtest/top_packages_screen.dart';
import 'package:shield/module/location/address_book.dart';
import 'package:shield/module/patients/patient_book.dart';
import 'package:shield/module/registration/store_picker_sheet.dart';
import 'package:shield/theme/app_colors.dart';

const _activeLife = LabPackage(
  id: '2',
  name: 'Active Life',
  testCount: 85,
  profileCount: 8,
  rating: '4.92',
  booked: '8k+ booked',
  reportIn: '15 hr',
  price: '1,299',
  mrp: '3,248',
  saved: '433',
  inheritsFrom: 'Everything in Preventive Plus',
  inheritsSummary: 'All 83 tests · 8 profiles',
  extrasLabel: '+ 2 MORE TESTS · DIABETES',
  forWhom: 'For Male & Female',
  ageRange: '5-99 yrs',
  preparation: '12 hrs fasting',
  sample: 'Blood, Urine',
  organs: [
    'Liver',
    'Kidneys',
    'Pancreas',
    'Heart',
    'Blood Vessels',
    'Thyroid Gland',
  ],
  about: 'Everything in Preventive Plus, plus the two markers that show '
      'how blood sugar has behaved over the past three months.',
  extras: [
    LabProfile('🩸', 'HbA1c', 0),
    LabProfile('💠', 'Average blood glucose', 0),
  ],
);

const _preventivePlus = LabPackage(
  id: '1',
  name: 'Preventive Plus',
  testCount: 83,
  profileCount: 8,
  rating: '4.83',
  booked: '12k+ booked',
  reportIn: '15 hr',
  price: '999',
  mrp: '2,498',
  saved: '333',
  forWhom: 'For Male & Female',
  ageRange: '5-99 yrs',
  preparation: '10 hrs fasting',
  sample: 'Blood, Urine',
  organs: ['Liver', 'Kidneys', 'Heart', 'Thyroid Gland'],
  about: 'A broad first look at how the body is running.',
);

const _completeCare = LabPackage(
  id: '3',
  name: 'Complete Care',
  testCount: 92,
  profileCount: 10,
  price: '1,799',
  mrp: '4,100',
  saved: '560',
  inheritsFrom: 'Everything in Active Life',
  inheritsSummary: 'All 85 tests · 8 profiles',
);

void main() {
  setUp(() {
    LabCartService.instance.reset();
    CartService.instance.reset();
    AddressBook.instance.reset();
    PatientBook.instance.reset();
    CareRepository.labPackagesOverride =
        () async => [_preventivePlus, _activeLife, _completeCare];
  });
  tearDown(() {
    LabCartService.instance.reset();
    CartService.instance.reset();
    AddressBook.instance.reset();
    PatientBook.instance.reset();
    CareRepository.labPackagesOverride = null;
  });

  /// [count] fresh patients on the account, for tests that only care how
  /// many are booked, not who they are.
  List<Patient> somePatients(int count) => [
    for (var i = 1; i <= count; i++)
      PatientBook.instance.add(
        name: 'Patient $i',
        phone: '900000000$i',
        dob: DateTime(1990, 1, i),
        gender: PatientGender.other,
        relation: i == 1 ? PatientRelation.self : PatientRelation.other,
      ),
  ];

  void giveAddress() {
    AddressBook.instance.add(
      const Address(
        pincode: '679322',
        house: '12/A',
        area: 'Palm Grove',
        firstName: 'Asha',
        phone: '9000012345',
        label: AddressLabel.home,
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(400, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  group('rupee formatting', () {
    test('groups the Indian way', () {
      expect(formatRupees(999), '999');
      expect(formatRupees(1732), '1,732');
      expect(formatRupees(12990), '12,990');
      expect(formatRupees(129900), '1,29,900');
      expect(formatRupees(0), '0');
    });
  });

  group('package pricing', () {
    test('parses the grouped strings back to numbers', () {
      expect(_activeLife.priceValue, 1299);
      expect(_activeLife.mrpValue, 3248);
      expect(_preventivePlus.priceValue, 999);
    });

    test('the discount label matches the two prices', () {
      // 1 - 1299/3248 = 60.01%
      expect(_activeLife.discountLabel, '60.01% off');
    });
  });

  group('the lab basket', () {
    test('is a different basket from the medicine cart', () {
      LabCartService.instance.book(_activeLife, patients: somePatients(2));

      expect(LabCartService.instance.bookingCount, 1);
      // Booking a test does not put anything in the medicine cart.
      expect(CartService.instance.itemCount, 0);

      CartService.instance.add(name: 'Dolo 650', pack: 'Strip', price: 32.5);

      expect(CartService.instance.itemCount, 1);
      expect(LabCartService.instance.bookingCount, 1);
    });

    test('prices a booking per patient', () {
      LabCartService.instance.book(_activeLife, patients: somePatients(3));

      final booking = LabCartService.instance.bookings.single;
      expect(booking.amount, 1299 * 3);
      expect(LabCartService.instance.subtotal, 3897);
      expect(LabCartService.instance.patientCount, 3);
    });

    test('booking the same package again corrects the patients', () {
      LabCartService.instance.book(_activeLife, patients: somePatients(2));
      LabCartService.instance.book(_activeLife, patients: somePatients(4));

      // One line, not two visits.
      expect(LabCartService.instance.bookingCount, 1);
      expect(LabCartService.instance.bookings.single.patients.length, 4);
    });

    test('counts packages, not heads', () {
      LabCartService.instance.book(_activeLife, patients: somePatients(3));
      LabCartService.instance.book(_completeCare, patients: somePatients(2));

      expect(LabCartService.instance.bookingCount, 2);
      expect(LabCartService.instance.patientCount, 5);
    });

    test('the patient list is clamped to what the sheet offers', () {
      LabCartService.instance.book(_activeLife, patients: somePatients(99));
      expect(LabCartService.instance.bookings.single.patients.length, 5);
    });

    test('savings are the gap between MRP and price, per patient', () {
      LabCartService.instance.book(_activeLife, patients: somePatients(2));

      expect(LabCartService.instance.mrpTotal, 3248 * 2);
      expect(LabCartService.instance.savings, (3248 - 1299) * 2);
      expect(LabCartService.instance.payable, 1299 * 2);
    });

    test('patientsFor reports what is booked', () {
      expect(
        LabCartService.instance.patientsFor(_activeLife),
        null,
      );

      LabCartService.instance.book(_activeLife, patients: somePatients(2));

      expect(LabCartService.instance.patientsFor(_activeLife)?.length, 2);
      expect(
        LabCartService.instance.patientsFor(_completeCare),
        null,
      );
    });

    test('a patient can be given their own collection address, separate from the shared one', () {
      final patients = somePatients(2);
      LabCartService.instance.book(_activeLife, patients: patients);
      expect(LabCartService.instance.addressFor(patients[0]), null);

      const own = Address(
        pincode: '679999',
        house: 'Door 9',
        area: 'Elsewhere',
        firstName: 'Grandma',
        phone: '9000099999',
        label: AddressLabel.home,
      );
      LabCartService.instance.setAddressFor(patients[0], own);

      expect(LabCartService.instance.addressFor(patients[0]), own);
      // The other patient is untouched.
      expect(LabCartService.instance.addressFor(patients[1]), null);

      LabCartService.instance.clear();
      expect(LabCartService.instance.addressFor(patients[0]), null);
    });

    test('a preferred date is unset by default, settable and clearable, and reset on clear()', () {
      expect(LabCartService.instance.scheduledFor, null);

      final date = DateTime(2026, 11, 3);
      LabCartService.instance.chooseScheduledFor(date);
      expect(LabCartService.instance.scheduledFor, date);

      LabCartService.instance.chooseScheduledFor(null);
      expect(LabCartService.instance.scheduledFor, null);

      LabCartService.instance.chooseScheduledFor(date);
      LabCartService.instance.book(_activeLife, patients: somePatients(2));
      LabCartService.instance.clear();
      expect(LabCartService.instance.scheduledFor, null);
    });
  });

  group('the patient sheet', () {
    testWidgets('lists every patient on the account, checkable', (tester) async {
      final patients = somePatients(2);
      await pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  LabPatientPickerSheet.show(context, _activeLife),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Who is this for?'), findsOneWidget);
      for (final p in patients) {
        expect(find.text(p.name), findsOneWidget);
      }
    });

    testWidgets('cannot confirm until at least one patient is picked, then prices the selection', (tester) async {
      somePatients(2);
      await pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  LabPatientPickerSheet.show(context, _activeLife),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.text('Select at least one patient'), findsOneWidget);

      await tester.tap(find.text('Patient 1'));
      await tester.tap(find.text('Patient 2'));
      await tester.pumpAndSettle();

      expect(find.text('Add · ₹2,598'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });
  });

  group('the package screen', () {
    testWidgets('shows the facts the reference calls for', (tester) async {
      await pump(
        tester,
        const LabPackageScreen(package: _activeLife),
        size: const Size(400, 1800),
      );

      expect(find.text('Product Details'), findsOneWidget);
      expect(find.text('For Male & Female'), findsOneWidget);
      expect(find.text('5-99 yrs'), findsOneWidget);
      expect(find.text('CONTAINS'), findsOneWidget);
      expect(find.text('85 Tests'), findsOneWidget);
      expect(find.text('PREPARATION'), findsOneWidget);
      expect(find.text('SAMPLE'), findsOneWidget);
      expect(find.text('REPORT IN'), findsOneWidget);
      expect(find.text('ORGANS & SYSTEMS COVERED'), findsOneWidget);
      expect(find.text('Pancreas'), findsOneWidget);
      expect(find.text('₹1,299'), findsOneWidget);
      expect(find.text('60.01% off'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('AVAILABLE COUPON'), findsOneWidget);
      expect(find.text('About this Package'), findsOneWidget);
    });

    testWidgets('Add opens the sheet and the choice reaches the basket', (
      tester,
    ) async {
      somePatients(3);
      await pump(
        tester,
        const LabPackageScreen(package: _activeLife),
        size: const Size(400, 1800),
      );

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Who is this for?'), findsOneWidget);

      await tester.tap(find.text('Patient 1'));
      await tester.tap(find.text('Patient 2'));
      await tester.tap(find.text('Patient 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add · ₹3,897'));
      await tester.pumpAndSettle();

      expect(LabCartService.instance.bookings.single.patients.length, 3);
      expect(LabCartService.instance.subtotal, 3897);

      // The button now reflects the booking rather than offering to add again.
      expect(find.text('Booked for 3 patients · Change'), findsOneWidget);
    });

    testWidgets('the badge counts the booking', (tester) async {
      await pump(
        tester,
        const LabPackageScreen(package: _activeLife),
        size: const Size(400, 1800),
      );

      expect(
        find.descendant(
          of: find.byType(LabCartBadge),
          matching: find.text('1'),
        ),
        findsNothing,
      );

      LabCartService.instance.book(_activeLife, patients: somePatients(2));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(LabCartBadge),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });
  });

  group('the lab cart screen', () {
    testWidgets('empty until something is booked', (tester) async {
      await pump(tester, const LabCartScreen());

      expect(find.text('No tests booked yet'), findsOneWidget);
    });

    testWidgets('lists the booking, the patients and the amount', (
      tester,
    ) async {
      LabCartService.instance.book(_activeLife, patients: somePatients(2));
      await pump(tester, const LabCartScreen());

      expect(find.text('Active Life'), findsOneWidget);
      expect(find.text('2 patients'), findsOneWidget);
      expect(find.text('₹2,598'), findsWidgets);
      expect(find.text('₹1,299 × 2'), findsOneWidget);
      expect(find.text('For 2 patients'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
    });

    testWidgets('who the booking is for can be changed from the basket', (
      tester,
    ) async {
      final patients = somePatients(4);
      LabCartService.instance.book(_activeLife, patients: patients.sublist(0, 2));
      await pump(tester, const LabCartScreen());

      await tester.tap(find.text('2 patients'));
      await tester.pumpAndSettle();

      // Reopens on what is already booked rather than blank.
      expect(find.text('Add · ₹2,598'), findsOneWidget);

      await tester.tap(find.text('Patient 3'));
      await tester.tap(find.text('Patient 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add · ₹5,196'));
      await tester.pumpAndSettle();

      expect(LabCartService.instance.bookings.single.patients.length, 4);
      expect(find.text('₹5,196'), findsWidgets);
      // The bill card itself — not just the booking's own line — reflects
      // the new count: a regression check for a canonicalized `const
      // _BillCard()` silently going stale on this exact kind of edit (the
      // booking count does not change, only its patient count).
      expect(find.text('- ₹7,796'), findsOneWidget);
      expect(find.text('For 4 patients'), findsOneWidget);
    });

    testWidgets('a booking can be removed', (tester) async {
      LabCartService.instance.book(_activeLife, patients: somePatients(2));
      await pump(tester, const LabCartScreen());

      await tester.tap(find.byTooltip('Remove booking'));
      await tester.pumpAndSettle();

      expect(LabCartService.instance.isEmpty, isTrue);
      expect(find.text('No tests booked yet'), findsOneWidget);
    });
  });

  group('the branch row', () {
    testWidgets('asks for a branch when nothing is registered or chosen', (
      tester,
    ) async {
      LabCartService.instance.book(_activeLife, patients: somePatients(2));
      await pump(tester, const LabCartScreen());

      expect(find.text('Choose a branch'), findsOneWidget);
    });

    testWidgets(
      'opens a picker excluding branches switched off for lab, and the '
      'choice reaches the basket',
      (tester) async {
        LabCartService.instance.book(_activeLife, patients: somePatients(2));
        await pump(tester, const LabCartScreen());

        await tester.tap(find.text('Choose a branch'));
        await tester.pumpAndSettle();

        expect(find.byType(StorePickerSheet), findsOneWidget);
        // A branch that has been switched off for lab collection never
        // shows up in this picker, even though it is a real branch.
        expect(find.text('Sahakar 360 Pharmacy Karinkallathani'), findsNothing);
        expect(find.text('Sahakar 360 Pharmacy Melattur'), findsOneWidget);

        await tester.tap(find.text('Sahakar 360 Pharmacy Melattur'));
        await tester.pumpAndSettle();

        expect(find.text('Sahakar 360 Pharmacy Melattur'), findsOneWidget);
        expect(LabCartService.instance.store?.id, 'SHD-MEL');
      },
    );
  });

  group('from the package list', () {
    testWidgets('Book opens the detail screen rather than booking blind', (
      tester,
    ) async {
      await pump(
        tester,
        const TopPackagesScreen(),
        size: const Size(400, 1400),
      );

      await tester.tap(find.text('Book').first);
      await tester.pumpAndSettle();

      expect(find.byType(LabPackageScreen), findsOneWidget);
      // Nothing is booked yet: the patient count is still unanswered.
      expect(LabCartService.instance.isEmpty, isTrue);
    });
  });

  group('proceeding to checkout', () {
    setUp(() => AuthService.instance.reset());
    tearDown(() => AuthService.instance.reset());

    Future<void> chooseBranch(WidgetTester tester) async {
      await tester.tap(find.text('Choose a branch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sahakar 360 Pharmacy Melattur'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'signed in, with a branch chosen, opens a real checkout screen — not '
      'a fake "choosing a slot" toast',
      (tester) async {
        AuthService.instance.signInAs();
        LabCartService.instance.book(_activeLife, patients: somePatients(2));
        await pump(tester, const LabCartScreen());
        await chooseBranch(tester);

        expect(find.text('Proceed to checkout'), findsOneWidget);
        await tester.tap(find.text('Proceed to checkout'));
        await tester.pumpAndSettle();

        expect(find.byType(LabCheckoutScreen), findsOneWidget);
        expect(find.text('Booking summary'), findsOneWidget);
        expect(find.text('Active Life'), findsOneWidget);
        expect(find.text('Place lab test'), findsOneWidget);
      },
    );

    testWidgets(
      'switching between Home Collection and Store Visit actually moves the blue highlight',
      (tester) async {
        // A non-const LabFulfillmentRow regression check — a const instance
        // would keep reading whichever option was selected at first build,
        // never rebuilding after a tap (see its own call site comment).
        AuthService.instance.signInAs();
        LabCartService.instance.book(_activeLife, patients: somePatients(1));
        await pump(tester, const LabCartScreen());
        await chooseBranch(tester);
        await tester.tap(find.text('Proceed to checkout'));
        await tester.pumpAndSettle();

        Color? colorOf(String label) =>
            tester.widget<Text>(find.text(label)).style?.color;

        expect(colorOf('Home Collection'), AppColors.brandBlue);
        expect(colorOf('Store Visit'), AppColors.textDark);

        await tester.tap(find.text('Store Visit'));
        await tester.pumpAndSettle();

        expect(colorOf('Store Visit'), AppColors.brandBlue);
        expect(colorOf('Home Collection'), AppColors.textDark);
      },
    );

    testWidgets(
      'a delivery address is required to place the booking, and the row '
      'picks up an address added elsewhere',
      (tester) async {
        AuthService.instance.signInAs();
        LabCartService.instance.book(_activeLife, patients: somePatients(1));
        await pump(tester, const LabCartScreen());
        await chooseBranch(tester);
        await tester.tap(find.text('Proceed to checkout'));
        await tester.pumpAndSettle();

        // Nothing on file yet: the row asks for one, same red-border guard
        // the branch row already uses, and "Place lab test" is disabled —
        // same as a missing branch already disables it.
        expect(find.text('Choose a collection address'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Place lab test'),
              )
              .onPressed,
          isNull,
        );

        // Added straight on AddressBook — the same singleton
        // ManageAddressesScreen (opened from "Change") would have written to
        // — and the row picks it up without anything else changing.
        AddressBook.instance.add(
          const Address(
            pincode: '679322',
            house: '12/A',
            area: 'Palm Grove',
            firstName: 'Asha',
            phone: '9000012345',
            label: AddressLabel.home,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Home (679322)'), findsOneWidget);

        await tester.tap(find.text('Place lab test'));
        await tester.pumpAndSettle();
        expect(find.byType(LabBookingPlacedScreen), findsOneWidget);
      },
    );

    testWidgets('signed out, asks to sign in before opening checkout', (
      tester,
    ) async {
      LabCartService.instance.book(_activeLife, patients: somePatients(2));
      await pump(tester, const LabCartScreen());
      await chooseBranch(tester);

      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      expect(find.byType(LabCheckoutScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets(
      'Place lab test files the booking, empties the basket and shows the '
      'confirmation screen',
      (tester) async {
        AuthService.instance.signInAs();
        giveAddress();
        LabCartService.instance.book(_activeLife, patients: somePatients(2));
        await pump(tester, const LabCartScreen());
        await chooseBranch(tester);
        await tester.tap(find.text('Proceed to checkout'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Place lab test'));
        await tester.pumpAndSettle();

        expect(find.byType(LabBookingPlacedScreen), findsOneWidget);
        expect(find.text('Lab test booked'), findsOneWidget);
        expect(LabCartService.instance.isEmpty, isTrue);
      },
    );
  });
}
