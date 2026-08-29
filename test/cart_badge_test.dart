import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/cart/cart_screen.dart';
import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/categories/category_catalogue.dart';
import 'package:shield/module/categories/category_listing_screen.dart';

void main() {
  setUp(CartService.instance.reset);
  tearDown(CartService.instance.reset);

  Future<void> pumpProductPage(
    WidgetTester tester, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryListingScreen(group: CategoryCatalogue.groups.first),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the first product ADD button on a page that owns the product cart.
  Future<void> tapFirstAdd(WidgetTester tester) async {
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
      cart.add(name: 'Dolo 650', pack: 'Strip of 15', price: 100, mrp: 126);

      expect(cart.subtotal, 100);
      expect(cart.discount, closeTo(26, 0.001));
      expect(cart.deliveryFee, 40);
      expect(cart.payable, closeTo(140, 0.001));
    });

    test('an empty cart carries no delivery fee', () {
      expect(CartService.instance.deliveryFee, 0);
      expect(CartService.instance.payable, 0);
    });
  });

  group('badge', () {
    testWidgets('is hidden until something is added', (tester) async {
      await pumpProductPage(tester);

      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('appears with the count after adding to the cart', (
      tester,
    ) async {
      await pumpProductPage(tester);
      await tapFirstAdd(tester);

      expect(CartService.instance.itemCount, 1);
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('the count rises on a second add', (tester) async {
      await pumpProductPage(tester);
      await tapFirstAdd(tester);
      CartService.instance.add(name: 'Second item', pack: 'Strip', price: 10);
      await tester.pumpAndSettle();

      expect(CartService.instance.itemCount, 2);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('caps the label past 99', (tester) async {
      for (var i = 0; i < 120; i++) {
        CartService.instance.add(name: 'Item $i', pack: 'Strip', price: 10);
      }
      await pumpProductPage(tester);

      expect(find.text('99+'), findsWidgets);
    });

    testWidgets('the badge is red', (tester) async {
      CartService.instance.add(name: 'Dolo', pack: 'Strip', price: 10);
      await pumpProductPage(tester);

      final badge = tester
          .widgetList<Container>(find.byType(Container))
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.color == const Color(0xFFD93A2B))
          .toList();

      expect(badge, isNotEmpty, reason: 'count bubble should be red');
    });
  });

  group('cart screen reads the same cart', () {
    testWidgets('an added product appears in the cart', (tester) async {
      await pumpProductPage(tester);
      await tapFirstAdd(tester);

      final added = CartService.instance.lines.single.name;

      await pumpProductPage(tester);
      await tester.pumpWidget(const MaterialApp(home: CartScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(CartScreen), findsOneWidget);
      expect(find.text(added), findsOneWidget);
    });

    testWidgets('an empty cart shows the empty state', (tester) async {
      await pumpProductPage(tester);

      await tester.tap(find.bySemanticsLabel('Cart'));
      await tester.pumpAndSettle();

      expect(find.text('Your cart is empty'), findsOneWidget);
    });
  });
}
