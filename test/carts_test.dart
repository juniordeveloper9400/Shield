import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/cart/cart_screen.dart';
import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/cart/carts_section.dart';
import 'package:shield/module/labtest/lab_cart_screen.dart';
import 'package:shield/module/labtest/lab_cart_service.dart';
import 'package:shield/module/labtest/lab_package.dart';

/// The "Your carts" home tile after prescriptions moved to an order-first flow
/// with no basket. Two priced baskets remain: Products and Lab tests.
void main() {
  void resetAll() {
    CartService.instance.reset();
    LabCartService.instance.reset();
  }

  setUp(resetAll);
  tearDown(resetAll);

  Future<void> pumpSection(
    WidgetTester tester, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: CartsSection())),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the two baskets are separate', () {
    test('each holds its own kind of thing and none sees the other', () {
      CartService.instance.add(
        name: 'Dolo 650',
        pack: 'Strip of 15',
        price: 32.5,
        qty: 2,
      );
      LabCartService.instance.book(LabCatalogue.packages.first, patients: 2);

      expect(CartService.instance.itemCount, 2);
      expect(LabCartService.instance.bookingCount, 1);

      // Emptying one leaves the other standing — they check out separately.
      CartService.instance.clear();
      expect(CartService.instance.isEmpty, isTrue);
      expect(LabCartService.instance.isEmpty, isFalse);
    });
  });

  group('the carts section', () {
    testWidgets('shows both, empty', (tester) async {
      await pumpSection(tester);

      expect(find.text('Your carts'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Lab tests'), findsOneWidget);
      expect(find.text('Prescriptions'), findsNothing);

      // Drawn quiet rather than hidden: a tile that vanished would move the
      // other under the reader's thumb.
      expect(find.text('Empty'), findsNWidgets(2));
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
      LabCartService.instance.book(LabCatalogue.packages.first, patients: 3);

      await pumpSection(tester);

      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('1 booking'), findsOneWidget);
      expect(find.text('Empty'), findsNothing);
    });

    testWidgets('a tile follows its basket without being rebuilt around', (
      tester,
    ) async {
      await pumpSection(tester);
      expect(find.text('Empty'), findsNWidgets(2));

      LabCartService.instance.book(LabCatalogue.packages.first, patients: 1);
      await tester.pumpAndSettle();

      expect(find.text('1 booking'), findsOneWidget);
      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('each tile opens its own basket', (tester) async {
      await pumpSection(tester);

      await tester.tap(find.byKey(const ValueKey('cart-tile-lab')));
      await tester.pumpAndSettle();
      expect(find.byType(LabCartScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(LabCartScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cart-tile-products')));
      await tester.pumpAndSettle();
      expect(find.byType(CartScreen), findsOneWidget);
    });

    testWidgets('both tiles fit the narrowest phone', (tester) async {
      CartService.instance.add(name: 'Dolo', pack: 'Strip', price: 10);
      LabCartService.instance.book(LabCatalogue.packages.first, patients: 1);

      await pumpSection(tester, size: const Size(320, 900));

      // An overflow paints an error banner and fails the test.
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Lab tests'), findsOneWidget);
    });
  });
}
