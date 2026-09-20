import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/data/neon/prescription_repository.dart';
import 'package:shield/module/orders/order_track.dart';
import 'package:shield/module/orders/purchase_service.dart';
import 'package:shield/module/patients/patient_book.dart';
import 'package:shield/module/prescription/prescription_record.dart';
import 'package:shield/module/prescription/upload_prescription_screen.dart';

final _patient = Patient(
  id: 'p1',
  name: 'Test Patient',
  phone: '9000000000',
  dob: DateTime(1990, 1, 1),
  gender: PatientGender.male,
  relation: PatientRelation.self,
);

LinkedOrder _link([OrderStatus status = OrderStatus.processing]) =>
    LinkedOrder(code: 'RX-MU8BWHGBD56A', status: status);

void main() {
  final book = PrescriptionBook.instance;

  setUp(() {
    book.reset();
    PurchaseService.instance.clear();
  });
  tearDown(() {
    book.reset();
    PurchaseService.instance.clear();
  });

  group('reading the order off a prescription row', () {
    test('maps each order status token', () {
      expect(
        LinkedOrder.fromTokens(code: 'A', status: 'PROCESSING')!.status,
        OrderStatus.processing,
      );
      expect(
        LinkedOrder.fromTokens(code: 'A', status: 'OUT_FOR_DELIVERY')!.status,
        OrderStatus.outForDelivery,
      );
      expect(
        LinkedOrder.fromTokens(code: 'A', status: 'DELIVERED')!.status,
        OrderStatus.delivered,
      );
      expect(
        LinkedOrder.fromTokens(code: 'A', status: 'CANCELLED')!.status,
        OrderStatus.cancelled,
      );
    });

    test('is null for a prescription that was never ordered', () {
      expect(LinkedOrder.fromTokens(code: null, status: null), isNull);
      expect(LinkedOrder.fromTokens(code: '  ', status: 'PROCESSING'), isNull);
    });

    test('the Neon row columns become the link', () {
      final link = PrescriptionRepository.linkedOrderFromRow({
        'order_code': 'RX-ABC',
        'order_status': 'DELIVERED',
      });

      expect(link?.code, 'RX-ABC');
      expect(link?.status, OrderStatus.delivered);
      expect(
        PrescriptionRepository.linkedOrderFromRow({
          'order_code': null,
          'order_status': null,
        }),
        isNull,
      );
    });

    test('a refresh folds the order onto the record, and a later one moves it on', () {
      final record = book.add(patient: _patient, fileName: 's.jpg');

      book.applyIntakeCard(record.id, medicines: const [], order: _link());
      expect(record.order?.status, OrderStatus.processing);

      book.applyIntakeCard(
        record.id,
        medicines: const [],
        order: _link(OrderStatus.outForDelivery),
      );
      expect(record.order?.status, OrderStatus.outForDelivery);
    });

    test('the loaded order book is matched to the link by order code', () {
      PurchaseService.instance.record(
        id: 'RX-MU8BWHGBD56A',
        placedOn: '19 Sep 2026',
        itemCount: 1,
        mrpTotal: 0,
        paidTotal: 0,
        kind: OrderKind.prescription,
      );

      expect(PurchaseService.instance.purchaseFor(_link())?.id, 'RX-MU8BWHGBD56A');
      expect(
        PurchaseService.instance.purchaseFor(
          const LinkedOrder(code: 'OTHER', status: OrderStatus.processing),
        ),
        isNull,
      );
      expect(PurchaseService.instance.purchaseFor(null), isNull);
    });
  });

  group('the card on Your prescriptions', () {
    Future<void> pump(WidgetTester tester) async {
      // Wider than a phone: the test font (Ahem) is one em per glyph, which
      // overflows rows that a real font fits.
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: UploadPrescriptionScreen()),
      );
      await tester.pumpAndSettle();
    }

    PrescriptionRecord withOrder([LinkedOrder? link]) {
      final record = book.add(patient: _patient, fileName: 'script.jpg');
      book.markOrdered(record.id);
      if (link != null) {
        book.applyIntakeCard(record.id, medicines: const [], order: link);
      }
      return record;
    }

    String chip(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const ValueKey('order-stage-chip'))).data!;

    testWidgets('shows nothing for a prescription that is not linked to an order', (
      tester,
    ) async {
      withOrder();

      await pump(tester);

      expect(find.text('Order status'), findsNothing);
    });

    testWidgets('follows the order through every status', (tester) async {
      final cases = <(OrderStatus, String, String)>[
        (OrderStatus.processing, 'Processing', 'We have your order'),
        (OrderStatus.outForDelivery, 'Out for delivery', 'Your order is on its way'),
        (OrderStatus.delivered, 'Delivered', 'Your order has been delivered'),
        (OrderStatus.cancelled, 'Cancelled', 'This order was cancelled'),
      ];

      for (final (status, label, detail) in cases) {
        book.reset();
        withOrder(_link(status));
        await pump(tester);

        expect(find.text('Order status'), findsOneWidget, reason: label);
        expect(chip(tester), label, reason: label);
        expect(find.textContaining(detail), findsOneWidget, reason: label);
        expect(find.text('RX-MU8BWHGBD56A'), findsOneWidget, reason: label);
      }
    });

    testWidgets('a live order shows the four-step track; a cancelled one drops it', (
      tester,
    ) async {
      withOrder(_link(OrderStatus.outForDelivery));
      await pump(tester);

      // The chip says "Out for delivery" once; the track repeats it as a step.
      for (final label in ['Order placed', 'Processing', 'Out for delivery', 'Delivered']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Processing'), findsOneWidget);

      book.reset();
      withOrder(_link(OrderStatus.cancelled));
      await pump(tester);

      expect(find.text('Processing'), findsNothing);
      expect(find.text('Delivered'), findsNothing);
    });

    testWidgets('agrees with the Track order screen about the same order', (
      tester,
    ) async {
      // The prescription row still says "processing", but the order book —
      // refreshed more often — already has the order out for delivery.
      withOrder(_link());
      final purchase = PurchaseService.instance.record(
        id: 'RX-MU8BWHGBD56A',
        placedOn: '19 Sep 2026',
        itemCount: 1,
        mrpTotal: 0,
        paidTotal: 0,
        status: OrderStatus.outForDelivery,
        kind: OrderKind.prescription,
      );

      await pump(tester);

      final current = OrderTrack(purchase).steps.lastWhere(
        (s) => s.state == TrackState.current,
      );
      expect(current.title, 'Out for delivery');
      expect(chip(tester), current.title);
      expect(find.text('Track order'), findsOneWidget);
    });

    testWidgets('offers Track order only once the order book has the order', (
      tester,
    ) async {
      withOrder(_link());

      await pump(tester);

      expect(find.text('Track order'), findsNothing);
    });

    testWidgets('reads in Malayalam when the language is switched', (
      tester,
    ) async {
      withOrder(_link(OrderStatus.delivered));
      await pump(tester);

      await tester.tap(find.text('മ'));
      await tester.pumpAndSettle();

      expect(find.text('ഓർഡർ നില'), findsOneWidget);
      expect(chip(tester), 'എത്തിച്ചു');
    });
  });
}
