import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/orders/order_track.dart';
import 'package:shield/module/orders/order_track_screen.dart';
import 'package:shield/module/orders/orders_screen.dart';
import 'package:shield/module/orders/purchase_service.dart';

Purchase _order({
  OrderKind kind = OrderKind.standard,
  OrderStatus status = OrderStatus.processing,
  int mrp = 900,
  int paid = 720,
}) {
  return Purchase(
    id: 'SHD-900001',
    placedOn: '20 Aug 2026',
    itemCount: 3,
    mrpTotal: mrp,
    paidTotal: paid,
    status: status,
    kind: kind,
  );
}

Future<void> _pumpTrack(WidgetTester tester, Purchase order) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: OrderTrackScreen(order: order)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('OrderTrack model', () {
    test('a standard order runs the four-stage route', () {
      final track = OrderTrack(_order());
      expect(track.steps.map((s) => s.title), [
        'Order placed',
        'Packed',
        'Dispatched',
        'Delivered',
      ]);
    });

    test('a prescription order gains the two pharmacist stages', () {
      final track = OrderTrack(_order(kind: OrderKind.prescription));
      expect(track.steps.map((s) => s.title), [
        'Prescription received',
        'Pharmacist review',
        'Order confirmed',
        'Dispatched',
        'Delivered',
      ]);
    });

    test('an unpriced prescription order sits on pharmacist review', () {
      final track = OrderTrack(
        _order(kind: OrderKind.prescription, mrp: 0, paid: 0),
      );
      final current = track.steps.firstWhere(
        (s) => s.state == TrackState.current,
      );
      expect(current.title, 'Pharmacist review');
      expect(track.awaitingPayment, isTrue);
    });

    test('a priced prescription order has moved on to confirmed', () {
      final track = OrderTrack(_order(kind: OrderKind.prescription));
      final current = track.steps.firstWhere(
        (s) => s.state == TrackState.current,
      );
      expect(current.title, 'Order confirmed');
      expect(track.awaitingPayment, isFalse);
    });

    test('out for delivery lights the dispatch node on both routes', () {
      for (final kind in OrderKind.values) {
        final track = OrderTrack(
          _order(kind: kind, status: OrderStatus.outForDelivery),
        );
        final current = track.steps.firstWhere(
          (s) => s.state == TrackState.current,
        );
        expect(current.title, 'Dispatched', reason: kind.name);
      }
    });

    test('a delivered order has every node done and no window', () {
      final track = OrderTrack(_order(status: OrderStatus.delivered));
      expect(
        track.steps.every((s) => s.state == TrackState.done),
        isTrue,
      );
      expect(track.deliveryWindow, isNull);
    });

    test('a cancelled order stops at two nodes', () {
      final track = OrderTrack(_order(status: OrderStatus.cancelled));
      expect(track.steps.map((s) => s.title), ['Order placed', 'Cancelled']);
      expect(track.deliveryWindow, isNull);
    });
  });

  group('OrderTrackScreen', () {
    testWidgets('draws the standard route with a delivery window', (
      tester,
    ) async {
      await _pumpTrack(tester, _order());

      expect(find.text('Order placed'), findsOneWidget);
      expect(find.text('Packed'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.textContaining('Delivery by:'), findsOneWidget);
      // A standard order owes nothing here.
      expect(find.text('Make payment now'), findsNothing);
    });

    testWidgets('a prescription order shows the pharmacist stages and a '
        'payment nudge', (tester) async {
      await _pumpTrack(
        tester,
        _order(kind: OrderKind.prescription, mrp: 0, paid: 0),
      );

      expect(find.text('Prescription received'), findsOneWidget);
      expect(find.text('Pharmacist review'), findsOneWidget);
      expect(find.text('Order confirmed'), findsOneWidget);
      expect(find.text('Make payment now'), findsOneWidget);
    });

    testWidgets('a delivered order drops the window and the nudge', (
      tester,
    ) async {
      await _pumpTrack(
        tester,
        _order(kind: OrderKind.prescription, status: OrderStatus.delivered),
      );

      expect(find.textContaining('Delivery by:'), findsNothing);
      expect(find.text('Make payment now'), findsNothing);
      expect(find.text('Order delivered'), findsOneWidget);
    });
  });

  testWidgets('My Orders opens the tracker from the Track order button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: OrdersScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Track order'), findsWidgets);
    await tester.tap(find.text('Track order').first);
    await tester.pumpAndSettle();

    expect(find.byType(OrderTrackScreen), findsOneWidget);
    expect(find.text('Track order'), findsWidgets);
  });
}
