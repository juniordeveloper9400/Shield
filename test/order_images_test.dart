import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shield/module/orders/order_detail_sections.dart';
import 'package:shield/module/orders/order_track_screen.dart';
import 'package:shield/module/orders/orders_screen.dart';
import 'package:shield/module/orders/purchase_service.dart';

/// The picture-bearing cards this feature added: a thumbnail on each My
/// Orders card, "Items in this order" on a standard order's tracker, and a
/// real prescription scan (not a generic icon and a toast) on a
/// prescription order's tracker.
///
/// None of these can reach Neon under `flutter test` (`NeonHttp.isConfigured`
/// is false in this environment by design — no `DATABASE_URL` is compiled
/// in). What is asserted here is that every one of these widgets tolerates
/// that: the surrounding card renders in full and nothing crashes or hangs
/// waiting on a fetch that was never going to land — not the picture itself,
/// which needs a live database.
void main() {
  final service = PurchaseService.instance;

  setUp(service.clear);
  tearDown(service.clear);

  Future<void> pumpOrders(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: OrdersScreen()));
    await tester.pumpAndSettle();
  }

  group('the My Orders list card', () {
    testWidgets('shows a standard order in full, thumbnail included', (
      tester,
    ) async {
      service.record(
        id: 'SH-THUMB-1',
        placedOn: '20 Sep 2026',
        itemCount: 2,
        mrpTotal: 500,
        paidTotal: 450,
      );

      await pumpOrders(tester);

      expect(find.text('SH-THUMB-1'), findsOneWidget);
      expect(find.text('Placed on 20 Sep 2026  ·  2 items'), findsOneWidget);
      expect(find.text('₹450'), findsOneWidget);
      // No picture ever arrives (no database in this environment), so the
      // fallback icon on the thumbnail is what stands in for it.
      expect(find.byIcon(Icons.medication_outlined), findsOneWidget);
    });

    testWidgets('shows a prescription order in full, its own fallback icon', (
      tester,
    ) async {
      service.record(
        id: 'RX-THUMB-1',
        placedOn: '20 Sep 2026',
        itemCount: 1,
        mrpTotal: 0,
        paidTotal: 0,
        kind: OrderKind.prescription,
      );

      await pumpOrders(tester);

      expect(find.text('RX-THUMB-1'), findsOneWidget);
      expect(find.text('Price on confirmation'), findsOneWidget);
      expect(find.byIcon(Icons.description_rounded), findsOneWidget);
    });

    testWidgets('a card for each order, never mixing up their thumbnails', (
      tester,
    ) async {
      service.record(
        id: 'SH-THUMB-2',
        placedOn: '20 Sep 2026',
        itemCount: 1,
        mrpTotal: 100,
        paidTotal: 100,
      );
      service.record(
        id: 'RX-THUMB-2',
        placedOn: '19 Sep 2026',
        itemCount: 1,
        mrpTotal: 0,
        paidTotal: 0,
        kind: OrderKind.prescription,
      );

      await pumpOrders(tester);

      expect(find.text('SH-THUMB-2'), findsOneWidget);
      expect(find.text('RX-THUMB-2'), findsOneWidget);
      expect(find.byIcon(Icons.medication_outlined), findsOneWidget);
      expect(find.byIcon(Icons.description_rounded), findsOneWidget);
    });
  });

  group('the Track order screen', () {
    Future<void> pumpTrack(WidgetTester tester, Purchase order) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: OrderTrackScreen(order: order)));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'never shows "Items in this order" for a standard order with nothing fetched, and never crashes',
      (tester) async {
        final order = service.record(
          id: 'SH-ITEMS-1',
          placedOn: '20 Sep 2026',
          itemCount: 2,
          mrpTotal: 300,
          paidTotal: 300,
        );

        await pumpTrack(tester, order);

        // Present in the tree — it is what will show real items once the
        // database answers — but rendering nothing (a zero-size box) while
        // that fetch has not landed, which is why it has to be looked for
        // with skipOffstage off: Flutter's default finder treats a
        // zero-size widget as offstage.
        expect(
          find.byType(OrderItemsCard, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('Items in this order'), findsNothing);
        expect(find.text('Item in this order'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shows the prescription-uploaded card, with its own fallback state, for a prescription order',
      (tester) async {
        final order = service.record(
          id: 'RX-ITEMS-1',
          placedOn: '20 Sep 2026',
          itemCount: 1,
          mrpTotal: 0,
          paidTotal: 0,
          kind: OrderKind.prescription,
        );

        await pumpTrack(tester, order);

        expect(find.text('Prescription uploaded'), findsOneWidget);
        expect(
          find.text('The pharmacist is reading this to price your order.'),
          findsOneWidget,
        );
        // No scan ever arrives (no database in this environment), so the
        // generic document icon is what stands in for it — and no "View"
        // button, which only ever shows once a real scan has loaded.
        expect(find.byIcon(Icons.description_rounded), findsOneWidget);
        expect(find.text('View'), findsNothing);
        expect(find.byType(OrderItemsCard), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'reflects a priced prescription order rather than always claiming it is still being read',
      (tester) async {
        final order = service.record(
          id: 'RX-ITEMS-2',
          placedOn: '20 Sep 2026',
          itemCount: 1,
          mrpTotal: 450,
          paidTotal: 450,
          kind: OrderKind.prescription,
        );

        await pumpTrack(tester, order);

        expect(
          find.text('Priced and confirmed by the pharmacist.'),
          findsOneWidget,
        );
        expect(
          find.text('The pharmacist is reading this to price your order.'),
          findsNothing,
        );
      },
    );
  });
}
