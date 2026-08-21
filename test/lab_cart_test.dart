import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/labtest/lab_cart_badge.dart';
import 'package:shield/module/labtest/lab_cart_screen.dart';
import 'package:shield/module/labtest/lab_cart_service.dart';
import 'package:shield/module/labtest/lab_package.dart';
import 'package:shield/module/labtest/lab_package_screen.dart';
import 'package:shield/module/labtest/patient_count_sheet.dart';
import 'package:shield/module/labtest/top_packages_screen.dart';

void main() {
  setUp(() {
    LabCartService.instance.reset();
    CartService.instance.reset();
  });
  tearDown(() {
    LabCartService.instance.reset();
    CartService.instance.reset();
  });

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
      expect(LabCatalogue.activeLife.priceValue, 1299);
      expect(LabCatalogue.activeLife.mrpValue, 3248);
      expect(LabCatalogue.preventivePlus.priceValue, 999);
    });

    test('the discount label matches the two prices', () {
      // 1 - 1299/3248 = 60.01%
      expect(LabCatalogue.activeLife.discountLabel, '60.01% off');
    });
  });

  group('the lab basket', () {
    test('is a different basket from the medicine cart', () {
      LabCartService.instance.book(LabCatalogue.activeLife, patients: 2);

      expect(LabCartService.instance.bookingCount, 1);
      // Booking a test does not put anything in the medicine cart.
      expect(CartService.instance.itemCount, 0);

      CartService.instance.add(name: 'Dolo 650', pack: 'Strip', price: 32.5);

      expect(CartService.instance.itemCount, 1);
      expect(LabCartService.instance.bookingCount, 1);
    });

    test('prices a booking per patient', () {
      LabCartService.instance.book(LabCatalogue.activeLife, patients: 3);

      final booking = LabCartService.instance.bookings.single;
      expect(booking.amount, 1299 * 3);
      expect(LabCartService.instance.subtotal, 3897);
      expect(LabCartService.instance.patientCount, 3);
    });

    test('booking the same package again corrects the count', () {
      LabCartService.instance.book(LabCatalogue.activeLife, patients: 2);
      LabCartService.instance.book(LabCatalogue.activeLife, patients: 4);

      // One line, not two visits.
      expect(LabCartService.instance.bookingCount, 1);
      expect(LabCartService.instance.bookings.single.patients, 4);
    });

    test('counts packages, not heads', () {
      LabCartService.instance.book(LabCatalogue.activeLife, patients: 3);
      LabCartService.instance.book(LabCatalogue.completeCare, patients: 2);

      expect(LabCartService.instance.bookingCount, 2);
      expect(LabCartService.instance.patientCount, 5);
    });

    test('the patient count is clamped to what the sheet offers', () {
      LabCartService.instance.book(LabCatalogue.activeLife, patients: 99);
      expect(LabCartService.instance.bookings.single.patients, 5);

      LabCartService.instance.book(LabCatalogue.activeLife, patients: 0);
      expect(LabCartService.instance.bookings.single.patients, 1);
    });

    test('savings are the gap between MRP and price, per patient', () {
      LabCartService.instance.book(LabCatalogue.activeLife, patients: 2);

      expect(LabCartService.instance.mrpTotal, 3248 * 2);
      expect(LabCartService.instance.savings, (3248 - 1299) * 2);
      expect(LabCartService.instance.payable, 1299 * 2);
    });

    test('patientsFor reports what is booked', () {
      expect(
        LabCartService.instance.patientsFor(LabCatalogue.activeLife),
        null,
      );

      LabCartService.instance.book(LabCatalogue.activeLife, patients: 2);

      expect(LabCartService.instance.patientsFor(LabCatalogue.activeLife), 2);
      expect(
        LabCartService.instance.patientsFor(LabCatalogue.completeCare),
        null,
      );
    });
  });

  group('the patient sheet', () {
    testWidgets('offers five counts, each with its own amount', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  PatientCountSheet.show(context, LabCatalogue.activeLife),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Select number of patients'), findsOneWidget);
      expect(find.text('1 patient'), findsOneWidget);
      expect(find.text('5 patients'), findsOneWidget);

      // The cost of each choice is visible before it is made.
      expect(find.text('₹1,299'), findsOneWidget);
      expect(find.text('₹2,598'), findsOneWidget);
      expect(find.text('₹6,495'), findsOneWidget);
    });

    testWidgets('cannot confirm until a count is chosen', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  PatientCountSheet.show(context, LabCatalogue.activeLife),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.text('Select patients'), findsOneWidget);

      await tester.tap(find.text('2 patients'));
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
        const LabPackageScreen(package: LabCatalogue.activeLife),
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
      await pump(
        tester,
        const LabPackageScreen(package: LabCatalogue.activeLife),
        size: const Size(400, 1800),
      );

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Select number of patients'), findsOneWidget);

      await tester.tap(find.text('3 patients'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add · ₹3,897'));
      await tester.pumpAndSettle();

      expect(LabCartService.instance.bookings.single.patients, 3);
      expect(LabCartService.instance.subtotal, 3897);

      // The button now reflects the booking rather than offering to add again.
      expect(find.text('Booked for 3 patients · Change'), findsOneWidget);
    });

    testWidgets('the badge counts the booking', (tester) async {
      await pump(
        tester,
        const LabPackageScreen(package: LabCatalogue.activeLife),
        size: const Size(400, 1800),
      );

      expect(
        find.descendant(
          of: find.byType(LabCartBadge),
          matching: find.text('1'),
        ),
        findsNothing,
      );

      LabCartService.instance.book(LabCatalogue.activeLife, patients: 2);
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
      LabCartService.instance.book(LabCatalogue.activeLife, patients: 2);
      await pump(tester, const LabCartScreen());

      expect(find.text('Active Life'), findsOneWidget);
      expect(find.text('2 patients'), findsOneWidget);
      expect(find.text('₹2,598'), findsWidgets);
      expect(find.text('₹1,299 × 2'), findsOneWidget);
      expect(find.text('For 2 patients'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
    });

    testWidgets('the patient count can be changed from the basket', (
      tester,
    ) async {
      LabCartService.instance.book(LabCatalogue.activeLife, patients: 2);
      await pump(tester, const LabCartScreen());

      await tester.tap(find.text('2 patients'));
      await tester.pumpAndSettle();

      // Reopens on what is already booked rather than blank.
      expect(find.text('Add · ₹2,598'), findsOneWidget);

      await tester.tap(find.text('4 patients'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add · ₹5,196'));
      await tester.pumpAndSettle();

      expect(LabCartService.instance.bookings.single.patients, 4);
      expect(find.text('₹5,196'), findsWidgets);
    });

    testWidgets('a booking can be removed', (tester) async {
      LabCartService.instance.book(LabCatalogue.activeLife, patients: 2);
      await pump(tester, const LabCartScreen());

      await tester.tap(find.byTooltip('Remove booking'));
      await tester.pumpAndSettle();

      expect(LabCartService.instance.isEmpty, isTrue);
      expect(find.text('No tests booked yet'), findsOneWidget);
    });
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
}
