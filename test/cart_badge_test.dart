import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/cart/cart_badge.dart';
import 'package:shield/module/cart/cart_screen.dart';
import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/screens/app_shell.dart';

void main() {
  setUp(CartService.instance.reset);
  tearDown(CartService.instance.reset);

  Future<void> pumpShell(
    WidgetTester tester, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();
  }

  /// Scrolls the home feed to the first ADD button and taps it.
  Future<void> tapFirstAdd(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Vitamins & Supplements'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final add = find.text('ADD').first;
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
  }

  group('cart service', () {
    test('counts units, not distinct lines', () {
      final cart = CartService.instance;
      expect(cart.itemCount, 0);

      cart.add(name: 'Dolo 650', pack: 'Strip of 15', price: 32.5);
      cart.add(name: 'Dolo 650', pack: 'Strip of 15', price: 32.5);
      cart.add(name: 'Shelcal', pack: 'Strip of 15', price: 118);

      // Two products, three units, and the repeat merged into one line.
      expect(cart.lines, hasLength(2));
      expect(cart.itemCount, 3);
    });

    test('stepping a line to zero removes it', () {
      final cart = CartService.instance;
      cart.add(name: 'Dolo 650', pack: 'Strip of 15', price: 32.5);

      cart.changeQty(0, -1);
      expect(cart.lines, isEmpty);
      expect(cart.itemCount, 0);
    });

    test('the bill follows the contents', () {
      final cart = CartService.instance;
      cart.add(name: 'Dolo 650', pack: 'Strip of 15', price: 100);

      expect(cart.subtotal, 100);
      expect(cart.discount, closeTo(26, 0.001));
      expect(cart.deliveryFee, 40);
      expect(cart.payable, closeTo(114, 0.001));
    });

    test('an empty cart carries no delivery fee', () {
      expect(CartService.instance.deliveryFee, 0);
      expect(CartService.instance.payable, 0);
    });
  });

  group('badge', () {
    testWidgets('is hidden until something is added', (tester) async {
      await pumpShell(tester);

      expect(find.byType(CartBadge), findsWidgets);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('appears with the count after adding to the cart', (
      tester,
    ) async {
      await pumpShell(tester);
      await tapFirstAdd(tester);

      expect(CartService.instance.itemCount, 1);
      // Shown on both the header badge and the pinned bar's badge.
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('the count rises on a second add', (tester) async {
      await pumpShell(tester);
      await tapFirstAdd(tester);
      await tapFirstAdd(tester);

      expect(CartService.instance.itemCount, 2);
      expect(find.text('2'), findsWidgets);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('caps the label past 99', (tester) async {
      for (var i = 0; i < 120; i++) {
        CartService.instance.add(name: 'Item $i', pack: 'Strip', price: 10);
      }
      await pumpShell(tester);

      expect(find.text('99+'), findsWidgets);
    });

    testWidgets('the badge is red', (tester) async {
      CartService.instance.add(name: 'Dolo', pack: 'Strip', price: 10);
      await pumpShell(tester);

      final badge = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(CartBadge).first,
              matching: find.byType(Container),
            ),
          )
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.color == CartBadge.badgeColour)
          .toList();

      expect(badge, isNotEmpty, reason: 'count bubble should be red');
    });
  });

  group('cart screen reads the same cart', () {
    testWidgets('an added product appears in the cart', (tester) async {
      await pumpShell(tester);
      await tapFirstAdd(tester);

      final added = CartService.instance.lines.single.name;

      await tester.tap(find.byType(CartBadge).first);
      await tester.pumpAndSettle();

      expect(find.byType(CartScreen), findsOneWidget);
      expect(find.text(added), findsOneWidget);
    });

    testWidgets('an empty cart shows the empty state', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.byType(CartBadge).first);
      await tester.pumpAndSettle();

      expect(find.text('Your cart is empty'), findsOneWidget);
    });
  });
}
