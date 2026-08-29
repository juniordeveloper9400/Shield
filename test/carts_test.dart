import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/cart/cart_screen.dart';
import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/cart/carts_section.dart';
import 'package:shield/module/labtest/lab_cart_screen.dart';
import 'package:shield/module/labtest/lab_cart_service.dart';
import 'package:shield/module/labtest/lab_package.dart';
import 'package:shield/module/patients/patient_book.dart';
import 'package:shield/module/prescription/medicine_duration.dart';
import 'package:shield/module/prescription/prescription_cart_screen.dart';
import 'package:shield/module/prescription/prescription_cart_service.dart';
import 'package:shield/module/prescription/prescription_record.dart';

void main() {
  void resetAll() {
    CartService.instance.reset();
    PrescriptionCartService.instance.reset();
    LabCartService.instance.reset();
    PrescriptionBook.instance.reset();
    PatientBook.instance.reset();
  }

  setUp(resetAll);
  tearDown(resetAll);

  /// A prescription the counter has already read, so it has something to
  /// dispense against.
  PrescriptionRecord fileRecord({
    String patient = 'Asha Menon',
    List<PrescriptionMedicine>? medicines,
  }) {
    final person = PatientBook.instance.add(
      name: patient,
      phone: '9000012345',
      dob: DateTime(1990, 4, 12),
      gender: PatientGender.female,
      relation: PatientRelation.spouse,
    );
    final record = PrescriptionBook.instance.add(
      patient: person,
      fileName: 'prescription.jpg',
      duration: MedicineDuration.oneMonth,
      medicines:
          medicines ??
          [
            PrescriptionMedicine(
              name: 'Dolo 650',
              pack: 'Strip of 15 tablets',
              intake: IntakePattern(morning: 1, night: 1),
            ),
            PrescriptionMedicine(
              name: 'Shelcal 500',
              pack: 'Strip of 15 tablets',
              intake: IntakePattern(night: 1),
            ),
          ],
    );
    record.doctor = 'Dr. Menon';
    return record;
  }

  Future<void> pumpSection(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: CartsSection())),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the prescription basket', () {
    test('one prescription is one order, whatever is on it', () {
      final record = fileRecord();
      expect(record.dispensable, hasLength(2));

      PrescriptionCartService.instance.add(record);

      // Two medicines, one order. The basket holds paper, not products.
      expect(PrescriptionCartService.instance.orderCount, 1);
      expect(PrescriptionCartService.instance.orders.single.medicineCount, 2);
    });

    test('an order is identified by its prescription number', () {
      final record = fileRecord();
      PrescriptionCartService.instance.add(record);

      final order = PrescriptionCartService.instance.orders.single;
      expect(order.number, record.number);
      expect(order.number, matches(RegExp(r'^RX-\d{4}$')));
    });

    test('numbers are padded so a list of them lines up', () {
      final first = fileRecord();
      final second = fileRecord(patient: 'Ravi Nair');

      expect(first.number, 'RX-0001');
      expect(second.number, 'RX-0002');
      expect(first.number.length, second.number.length);
    });

    test('sending the same prescription again corrects it, not doubles it', () {
      final record = fileRecord();
      PrescriptionCartService.instance.add(record);
      PrescriptionCartService.instance.add(record);

      // A prescription can only be dispensed once, whatever the member taps.
      expect(PrescriptionCartService.instance.orderCount, 1);

      // And the second send picks up whatever the counter has keyed on since.
      record.medicines = [
        ...record.medicines,
        PrescriptionMedicine(
          name: 'Pan 40',
          pack: 'Strip of 10',
          intake: IntakePattern(morning: 1),
        ),
      ];
      PrescriptionCartService.instance.add(record);

      expect(PrescriptionCartService.instance.orderCount, 1);
      expect(PrescriptionCartService.instance.orders.single.medicineCount, 3);
    });

    test('counts prescriptions for the badge and medicines for the counter', () {
      PrescriptionCartService.instance.add(fileRecord());
      PrescriptionCartService.instance.add(fileRecord(patient: 'Ravi Nair'));

      // Two papers to collect; four medicines to dispense across them.
      expect(PrescriptionCartService.instance.orderCount, 2);
      expect(PrescriptionCartService.instance.medicineCount, 4);
    });

    test('nothing in the basket carries a price', () {
      PrescriptionCartService.instance.add(fileRecord());

      // A ₹0.00 would read as free rather than as not yet priced.
      expect(PrescriptionCartService.instance.orders.single.isPriced, isFalse);
    });

    test('removing by id takes only that prescription out', () {
      final first = fileRecord();
      final second = fileRecord(patient: 'Ravi Nair');
      PrescriptionCartService.instance
        ..add(first)
        ..add(second);

      PrescriptionCartService.instance.remove(first.id);

      expect(PrescriptionCartService.instance.orderCount, 1);
      expect(PrescriptionCartService.instance.contains(first.id), isFalse);
      expect(PrescriptionCartService.instance.contains(second.id), isTrue);
    });

    test('removing something that was never in it changes nothing', () {
      PrescriptionCartService.instance.add(fileRecord());
      PrescriptionCartService.instance.remove('rx999');

      expect(PrescriptionCartService.instance.orderCount, 1);
    });
  });

  group('the three baskets are separate', () {
    test('each holds its own kind of thing and none sees the others', () {
      CartService.instance.add(
        name: 'Dolo 650',
        pack: 'Strip of 15',
        price: 32.5,
        qty: 2,
      );
      PrescriptionCartService.instance.add(fileRecord());
      LabCartService.instance.book(
        LabCatalogue.packages.first,
        patients: 2,
      );

      expect(CartService.instance.itemCount, 2);
      expect(PrescriptionCartService.instance.orderCount, 1);
      expect(LabCartService.instance.bookingCount, 1);

      // Emptying one leaves the other two standing — they check out
      // separately and cannot be settled together.
      CartService.instance.clear();
      expect(CartService.instance.isEmpty, isTrue);
      expect(PrescriptionCartService.instance.isEmpty, isFalse);
      expect(LabCartService.instance.isEmpty, isFalse);
    });
  });

  group('the carts section', () {
    testWidgets('shows all three, empty', (tester) async {
      await pumpSection(tester);

      expect(find.text('Your carts'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Prescriptions'), findsOneWidget);
      expect(find.text('Lab tests'), findsOneWidget);

      // Drawn quiet rather than hidden: a tile that vanished would move the
      // other two under the reader's thumb.
      expect(find.text('Empty'), findsNWidgets(3));
    });

    testWidgets('each tile counts its own basket in its own unit', (
      tester,
    ) async {
      CartService.instance.add(
        name: 'Dolo 650',
        pack: 'Strip of 15',
        price: 32.5,
        qty: 2,
      );
      PrescriptionCartService.instance.add(fileRecord());
      LabCartService.instance.book(LabCatalogue.packages.first, patients: 3);

      await pumpSection(tester);

      // Units, orders and bookings — three kinds of thing, named as such.
      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('1 order'), findsOneWidget);
      expect(find.text('1 booking'), findsOneWidget);
      expect(find.text('Empty'), findsNothing);
    });

    testWidgets('a tile follows its basket without being rebuilt around', (
      tester,
    ) async {
      await pumpSection(tester);
      expect(find.text('Empty'), findsNWidgets(3));

      PrescriptionCartService.instance.add(fileRecord());
      await tester.pumpAndSettle();

      expect(find.text('1 order'), findsOneWidget);
      expect(find.text('Empty'), findsNWidgets(2));
    });

    testWidgets('each tile opens its own basket', (tester) async {
      await pumpSection(tester);

      await tester.tap(find.byKey(const ValueKey('cart-tile-prescriptions')));
      await tester.pumpAndSettle();
      expect(find.byType(PrescriptionCartScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(PrescriptionCartScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cart-tile-lab')));
      await tester.pumpAndSettle();
      expect(find.byType(LabCartScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(LabCartScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cart-tile-products')));
      await tester.pumpAndSettle();
      expect(find.byType(CartScreen), findsOneWidget);
    });

    testWidgets('three tiles fit the narrowest phone', (tester) async {
      CartService.instance.add(name: 'Dolo', pack: 'Strip', price: 10);
      PrescriptionCartService.instance.add(fileRecord());

      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: CartsSection())),
        ),
      );
      await tester.pumpAndSettle();

      // An overflow paints an error banner and fails the test.
      expect(find.text('Prescriptions'), findsOneWidget);
      expect(find.text('1 order'), findsOneWidget);
    });
  });

  group('the prescription basket screen', () {
    Future<void> pumpCart(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: PrescriptionCartScreen()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an empty basket says what would fill it', (tester) async {
      await pumpCart(tester);

      expect(find.text('No prescriptions to fill'), findsOneWidget);
      expect(find.text('Send to pharmacy'), findsNothing);
    });

    testWidgets('a row is led by the prescription number', (tester) async {
      final record = fileRecord();
      PrescriptionCartService.instance.add(record);
      await pumpCart(tester);

      expect(find.text(record.number), findsOneWidget);
      expect(find.text('Asha Menon'), findsOneWidget);
      expect(find.text('Dr. Menon'), findsOneWidget);

      // The medicines are a count, not a list: what is being confirmed here
      // is which papers to fill.
      expect(find.textContaining('2 medicines'), findsOneWidget);
      expect(find.text('Dolo 650'), findsNothing);
    });

    testWidgets('two prescriptions are two rows, not their medicines', (
      tester,
    ) async {
      PrescriptionCartService.instance.add(fileRecord());
      PrescriptionCartService.instance.add(fileRecord(patient: 'Ravi Nair'));
      await pumpCart(tester);

      expect(find.text('RX-0001'), findsOneWidget);
      expect(find.text('RX-0002'), findsOneWidget);
      expect(find.text('2 prescriptions'), findsOneWidget);
    });

    testWidgets('the basket carries no total, and says why', (tester) async {
      PrescriptionCartService.instance.add(fileRecord());
      await pumpCart(tester);

      expect(
        find.textContaining('prices each prescription once it has confirmed'),
        findsOneWidget,
      );
      expect(find.text('Priced at the counter'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
    });

    testWidgets('a row can be taken out by its number', (tester) async {
      PrescriptionCartService.instance.add(fileRecord());
      PrescriptionCartService.instance.add(fileRecord(patient: 'Ravi Nair'));
      await pumpCart(tester);

      await tester.tap(
        find.byKey(const ValueKey('remove-prescription-RX-0001')),
      );
      await tester.pumpAndSettle();

      expect(find.text('RX-0001'), findsNothing);
      expect(find.text('RX-0002'), findsOneWidget);
      expect(PrescriptionCartService.instance.orderCount, 1);
    });
  });
}
