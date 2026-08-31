import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/money.dart';
import 'package:shield/module/earnings/earnings_detail_screen.dart';
import 'package:shield/module/home/earnings_section.dart';
import 'package:shield/module/home/refer_earn_card.dart';
import 'package:shield/module/orders/orders_screen.dart';
import 'package:shield/module/orders/purchase_service.dart';
import 'package:shield/module/privilege/privilege_card.dart';
import 'package:shield/module/privilege/privilege_tier.dart';
import 'package:shield/module/wallet/wallet_service.dart';
import 'package:shield/screens/home_screen.dart';

void main() {
  void resetAll() {
    PurchaseService.instance.reset();
    WalletService.instance.reset();
  }

  setUp(resetAll);
  tearDown(resetAll);

  Future<void> pumpSection(
    WidgetTester tester, {
    Size size = const Size(400, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EarningsSection())),
    );
    await tester.pumpAndSettle();
  }

  group('what a purchase earns', () {
    test('the saving is the gap between the printed price and the bill', () {
      // The whole rule: listed at ₹500, bought for ₹450, earned ₹50.
      const purchase = Purchase(
        id: 'SHD-1',
        placedOn: '01 Aug 2026',
        itemCount: 1,
        mrpTotal: 500,
        paidTotal: 450,
        status: OrderStatus.delivered,
      );

      expect(purchase.saved, 50);
      expect(purchase.savedLabel, '₹50');
      expect(purchase.paidLabel, '₹450');
      expect(purchase.mrpLabel, '₹500');
    });

    test('an order that cost list price earned nothing, not less', () {
      const noDiscount = Purchase(
        id: 'SHD-2',
        placedOn: '01 Aug 2026',
        itemCount: 1,
        mrpTotal: 500,
        paidTotal: 500,
        status: OrderStatus.delivered,
      );
      expect(noDiscount.saved, 0);

      // Never negative: an order that somehow cost more than list price did
      // not earn a negative amount, it earned nothing.
      const overpaid = Purchase(
        id: 'SHD-3',
        placedOn: '01 Aug 2026',
        itemCount: 1,
        mrpTotal: 400,
        paidTotal: 450,
        status: OrderStatus.delivered,
      );
      expect(overpaid.saved, 0);
    });

    test('the totals are added up from the orders, not stored', () {
      final orders = PurchaseService.instance;

      final counted = orders.purchases.where((order) => order.status.counts);
      expect(
        orders.savedTotal,
        counted.fold<int>(0, (sum, order) => sum + order.saved),
      );
      expect(
        orders.paidTotal,
        counted.fold<int>(0, (sum, order) => sum + order.paidTotal),
      );
      expect(orders.savedTotal, orders.mrpTotal - orders.paidTotal);
    });

    test('a cancelled order is listed but earns nothing', () {
      final orders = PurchaseService.instance;
      final cancelled = orders.purchases.firstWhere(
        (order) => order.status == OrderStatus.cancelled,
      );

      // It is still in the book the member can scroll.
      expect(orders.purchases, contains(cancelled));
      // It was never paid for, so it cannot have saved anything.
      expect(cancelled.status.counts, isFalse);
      expect(orders.savedTotal, isNot(contains(cancelled.saved)));
      expect(
        orders.mrpTotal,
        orders.purchases.fold<int>(0, (sum, order) => sum + order.mrpTotal) -
            cancelled.mrpTotal,
      );
    });

    test('the percentage is taken over the totals, not averaged', () {
      final orders = PurchaseService.instance;

      // A 40% saving on ₹100 and a 5% saving on ₹5,000 do not average to
      // 22.5% of anything a member spent.
      expect(
        orders.savedFraction,
        closeTo(orders.savedTotal / orders.mrpTotal, 0.0001),
      );
    });

    test('an empty book earns nothing and divides by nothing', () {
      PurchaseService.instance.clear();

      expect(PurchaseService.instance.savedTotal, 0);
      expect(PurchaseService.instance.savedFraction, 0);
      expect(PurchaseService.instance.savedPercentLabel, '0%');
    });

    test('active orders are the ones still on their way', () {
      // Delivered is done and cancelled never happened.
      expect(PurchaseService.instance.activeCount, 2);
    });
  });

  group('your earnings on home', () {
    testWidgets('shows only total earnings and no order button or sub-tiles', (tester) async {
      await pumpSection(tester);

      final orders = PurchaseService.instance;

      expect(find.text('Your savings'), findsOneWidget);
      // A plain-language label spells out what the big figure is, so it is not
      // mistaken for a spendable balance.
      expect(find.text('Total money you have saved'), findsOneWidget);
      expect(find.text(orders.savedLabel), findsOneWidget);
      expect(
        find.text('Kept out of ${orders.mrpLabel} of total price.'),
        findsOneWidget,
      );

      // Sub-tiles and Your orders button are NOT on the home card.
      expect(find.text('Total price'), findsNothing);
      expect(find.text('You paid'), findsNothing);
      expect(find.text('You saved'), findsNothing);
      expect(find.text('Your orders'), findsNothing);
    });

    testWidgets('tapping opens the dedicated earnings detail screen', (tester) async {
      await pumpSection(tester);

      await tester.tap(find.byType(EarningsSection));
      await tester.pumpAndSettle();

      expect(find.byType(EarningsDetailScreen), findsOneWidget);
      expect(find.text('Your Earnings'), findsOneWidget);
      expect(find.text('Total price'), findsOneWidget);
      expect(find.text('You paid'), findsOneWidget);
      expect(find.text('You saved'), findsOneWidget);
      expect(find.text('Earnings Breakdown by Order'), findsOneWidget);
      // No plan has been activated, so there is nothing to show here.
      expect(find.text('Privilege Plan Bonus'), findsNothing);

      // Does not show the Your orders button on the details page either.
      expect(find.text('Your orders'), findsNothing);
    });

    testWidgets('referral figures are not in this total', (tester) async {
      await pumpSection(tester);

      expect(find.text('Sahakar'), findsNothing);
      expect(find.text('Points'), findsNothing);
      expect(find.textContaining('pts'), findsNothing);
      expect(find.textContaining('invites'), findsNothing);
    });

    testWidgets(
      'activating a privilege plan folds its 10% bonus into the total',
      (tester) async {
        final ordersOnly = PurchaseService.instance.savedTotal;
        final silver = PrivilegeProgramme.silver.entry;
        WalletService.instance.activate(silver);

        await pumpSection(tester);

        // ₹1,000 on a ₹10,000 Silver load — on top of what the orders alone
        // already saved, not instead of it.
        expect(silver.bonus, 1000);
        expect(
          find.text('₹${formatRupees(ordersOnly + silver.bonus)}'),
          findsOneWidget,
        );

        await tester.tap(find.byType(EarningsSection));
        await tester.pumpAndSettle();

        expect(find.text('Privilege Plan Bonus'), findsOneWidget);
        expect(find.text(silver.name), findsOneWidget);
        expect(find.text('+${silver.bonusLabel}'), findsOneWidget);
      },
    );

    testWidgets('the total moves when an order is placed', (tester) async {
      await pumpSection(tester);

      final before = PurchaseService.instance.savedTotal;

      PurchaseService.instance.record(
        id: 'SHD-100500',
        placedOn: '27 Aug 2026',
        itemCount: 2,
        mrpTotal: 500,
        paidTotal: 450,
      );
      await tester.pumpAndSettle();

      expect(PurchaseService.instance.savedTotal, before + 50);
      expect(find.text('₹${_grouped(before + 50)}'), findsOneWidget);
    });

    testWidgets('a member who has bought nothing is told how to start', (
      tester,
    ) async {
      PurchaseService.instance.clear();
      await pumpSection(tester);

      expect(
        find.text('Buy at SHIELD prices and the difference is yours.'),
        findsOneWidget,
      );
      expect(find.textContaining('Kept out of'), findsNothing);
      expect(find.text('₹0'), findsOneWidget);
    });

    testWidgets('sits under the privilege card, above refer & earn', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 7000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EarningsSection), findsOneWidget);

      final privilege = tester.getTopLeft(find.byType(PrivilegeCard)).dy;
      final earnings = tester.getTopLeft(find.byType(EarningsSection)).dy;
      final refer = tester.getTopLeft(find.byType(ReferEarnCard)).dy;

      expect(earnings, greaterThan(privilege));
      expect(earnings, lessThan(refer));
    });
  });

  group('the orders screen reads the same book', () {
    testWidgets('lists every order, with what each one saved', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: OrdersScreen()));
      await tester.pumpAndSettle();

      for (final order in PurchaseService.instance.purchases) {
        expect(find.text(order.id), findsOneWidget, reason: order.id);
      }

      final counted = PurchaseService.instance.purchases.where(
        (order) => order.status.counts,
      );
      for (final order in counted) {
        expect(
          find.text('Saved ${order.savedLabel}'),
          findsOneWidget,
          reason: order.id,
        );
      }

      final cancelled = PurchaseService.instance.purchases.firstWhere(
        (order) => order.status == OrderStatus.cancelled,
      );
      expect(find.text('Saved ${cancelled.savedLabel}'), findsNothing);
    });
  });
}

/// Indian digit grouping, so the expectations read as the screen prints them.
String _grouped(int amount) {
  final digits = amount.toString();
  if (digits.length <= 3) {
    return digits;
  }
  final tail = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) {
    groups.insert(0, rest);
  }
  return '${groups.join(',')},$tail';
}
