import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/location/address_book.dart';
import 'package:shield/module/orders/order_track_screen.dart';
import 'package:shield/module/orders/orders_screen.dart';
import 'package:shield/module/orders/purchase_service.dart';
import 'package:shield/module/patients/patient_book.dart';
import 'package:shield/module/prescription/medicine_duration.dart';
import 'package:shield/module/prescription/prescription_cart_screen.dart';
import 'package:shield/module/prescription/prescription_cart_service.dart';
import 'package:shield/module/prescription/prescription_checkout_screen.dart';
import 'package:shield/module/prescription/prescription_order_placed_screen.dart';
import 'package:shield/module/prescription/prescription_record.dart';

void main() {
  void giveAddress() {
    AddressBook.instance.add(
      const Address(
        pincode: '400079',
        house: '12 Palm Court',
        area: 'Ghatkopar East',
        firstName: 'Asha',
        phone: '9000012345',
        label: AddressLabel.home,
      ),
    );
  }

  void resetAll() {
    PrescriptionCartService.instance.reset();
    PrescriptionBook.instance.reset();
    PatientBook.instance.reset();
    PurchaseService.instance.clear();
    AddressBook.instance.reset();
    AuthService.instance.reset();
    AuthService.instance.signInAs();
    // Checkout cannot place an order without a delivery address, so every
    // flow test starts with one. The gate itself is tested on its own below.
    giveAddress();
  }

  setUp(resetAll);
  tearDown(() {
    PrescriptionCartService.instance.reset();
    PrescriptionBook.instance.reset();
    PatientBook.instance.reset();
    PurchaseService.instance.reset();
    AddressBook.instance.reset();
    AuthService.instance.reset();
  });

  PrescriptionRecord fileRecord({String patient = 'Asha Menon'}) {
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
      medicines: [
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

  Future<void> pumpBasket(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: PrescriptionCartScreen()));
    await tester.pumpAndSettle();
  }

  group('prescription checkout', () {
    testWidgets('the basket proceeds to a checkout with payment options', (
      tester,
    ) async {
      PrescriptionCartService.instance.add(fileRecord());
      await pumpBasket(tester);

      expect(find.text('Proceed to checkout'), findsOneWidget);
      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      expect(find.byType(PrescriptionCheckoutScreen), findsOneWidget);
      expect(find.text('Payment method'), findsOneWidget);
      expect(find.text('Bank account'), findsOneWidget);
      expect(find.text('Google Pay'), findsOneWidget);
      expect(find.text('Place order'), findsOneWidget);
    });

    testWidgets('a method that is not wired up says so', (tester) async {
      PrescriptionCartService.instance.add(fileRecord());
      await pumpBasket(tester);
      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Google Pay'));
      await tester.pump();

      expect(find.textContaining('coming soon'), findsOneWidget);
      // Bank transfer stays the one selected method.
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    });

    testWidgets('Place order files it in My Orders and empties the basket', (
      tester,
    ) async {
      PrescriptionCartService.instance.add(fileRecord());
      await pumpBasket(tester);
      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      final purchases = PurchaseService.instance.purchases;
      expect(purchases, hasLength(1));
      expect(purchases.first.status, OrderStatus.processing);
      expect(purchases.first.itemCount, 2, reason: 'two dispensable medicines');
      expect(PrescriptionCartService.instance.isEmpty, isTrue);

      // The checkout is gone; a confirmation with a tick has taken its place.
      expect(find.byType(PrescriptionCheckoutScreen), findsNothing);
      expect(find.byType(PrescriptionOrderPlacedScreen), findsOneWidget);
      expect(find.text('Order placed'), findsOneWidget);
      expect(find.textContaining(purchases.first.id), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('the order cannot be placed without a delivery address', (
      tester,
    ) async {
      AddressBook.instance.reset();
      PrescriptionCartService.instance.add(fileRecord());
      await pumpBasket(tester);
      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      expect(find.text('Add a delivery address first'), findsOneWidget);

      // The button is dead until an address is saved.
      await tester.tap(find.text('Place order'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Nothing was filed and the checkout is still up.
      expect(PurchaseService.instance.purchases, isEmpty);
      expect(find.byType(PrescriptionCheckoutScreen), findsOneWidget);
      expect(find.byType(PrescriptionOrderPlacedScreen), findsNothing);
    });

    testWidgets('the confirmation tracks the order that was just placed', (
      tester,
    ) async {
      PrescriptionCartService.instance.add(fileRecord());
      await pumpBasket(tester);
      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Track order'));
      await tester.pumpAndSettle();

      expect(find.byType(OrderTrackScreen), findsOneWidget);
      expect(find.byType(PrescriptionOrderPlacedScreen), findsNothing);
    });
  });

  testWidgets('an unpriced order reads "Price on confirmation" in My Orders', (
    tester,
  ) async {
    PurchaseService.instance.record(
      id: 'SHD-100500',
      placedOn: '27 Aug 2026',
      itemCount: 2,
      mrpTotal: 0,
      paidTotal: 0,
      status: OrderStatus.processing,
    );

    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: OrdersScreen()));
    await tester.pumpAndSettle();

    expect(find.text('SHD-100500'), findsOneWidget);
    expect(find.text('Price on confirmation'), findsOneWidget);
    expect(find.text('₹0'), findsNothing);
  });
}
