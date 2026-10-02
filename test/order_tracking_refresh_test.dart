import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shield/module/orders/order_track_screen.dart';
import 'package:shield/module/orders/purchase_service.dart';

void main() {
  testWidgets(
    'open tracker follows refreshed admin status and removes listener on close',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = PurchaseService.instance;
      addTearDown(service.clear);
      Purchase order(OrderStatus status) => Purchase(
        id: 'LIVE-ORDER',
        placedOn: '19 Sep 2026',
        itemCount: 1,
        mrpTotal: 100,
        paidTotal: 0,
        status: status,
      );
      final original = order(OrderStatus.processing);
      service.replaceRemote([original]);
      await tester.pumpWidget(
        MaterialApp(home: OrderTrackScreen(order: original)),
      );
      await tester.pumpAndSettle();
      service.replaceRemote([order(OrderStatus.outForDelivery)]);
      await tester.pumpAndSettle();
      // Out for delivery with nobody having pressed Call yet still counts as
      // "the store obviously handled it" — Processed, not stuck at Pending.
      expect(find.text('Processed'), findsWidgets);
      expect(find.text('Pending'), findsNothing);
      service.replaceRemote([order(OrderStatus.cancelled)]);
      await tester.pumpAndSettle();
      expect(find.text('Cancelled'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      service.replaceRemote([order(OrderStatus.delivered)]);
      await tester.pump(const Duration(seconds: 31));
      expect(tester.takeException(), isNull);
    },
  );
}
