import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/cart/cart_bar.dart';
import 'package:shield/module/cart/cart_control.dart';
import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/categories/category_catalogue.dart';
import 'package:shield/module/categories/category_listing_screen.dart';
import 'package:shield/module/home/product_showcase.dart';
import 'package:shield/module/product/product_detail_content.dart';
import 'package:shield/module/product/product_detail_screen.dart';

import 'support/fake_catalogue.dart';

void main() {
  setUp(() {
    CartService.instance.reset();
    // The "Customers also bought" rail and listing screens read from
    // CatalogueService, which has no database in a test.
    seedFakeCatalogue();
  });
  tearDown(() {
    CartService.instance.reset();
    resetFakeCatalogue();
  });

  const dolo = Product(
    name: 'Dolo 650mg Tablet',
    pack: 'Strip of 15 tablets',
    price: '32',
    mrp: '40',
    discountLabel: '20% OFF',
    icon: Icons.medication_outlined,
  );

  const monitor = Product(
    name: 'Digital BP Monitor',
    pack: '1 device',
    price: '1,749',
    mrp: '2,499',
    icon: Icons.monitor_heart_outlined,
  );

  Future<void> pumpDetail(
    WidgetTester tester,
    Product product, {
    Size size = const Size(430, 2600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: ProductDetailScreen(product: product)),
    );
    await tester.pumpAndSettle();
  }

  group('product detail content', () {
    test('an oral pack reads as a medicine and prices per unit', () {
      final detail = ProductDetail.of(dolo);

      expect(detail.form, ProductForm.oral);
      expect(detail.discountPercent, 20);
      expect(detail.saveLabel, '₹8');
      expect(detail.unitPriceLabel, '₹2.13/unit');
      expect(detail.directions.first, contains('doctor'));
      expect(detail.faqs, hasLength(4));
    });

    test('a device pack reads as a device with no per-unit price', () {
      final detail = ProductDetail.of(monitor);

      expect(detail.form, ProductForm.device);
      expect(detail.unitPriceLabel, isNull);
      expect(detail.directions.join(' '), contains('manual'));
      expect(detail.storage, contains('dry place'));
    });

    test('a price above its own MRP never shows a negative saving', () {
      const odd = Product(
        name: 'Odd Priced Item',
        pack: 'Pack of 1',
        price: '100',
        mrp: '80',
        icon: Icons.help_outline,
      );
      final detail = ProductDetail.of(odd);

      expect(detail.save, 0);
      expect(detail.discountPercent, 0);
    });
  });

  group('product detail screen', () {
    testWidgets('lays out the header, price, MRP and saving', (tester) async {
      await pumpDetail(tester, dolo);

      expect(find.text('Product Details'), findsOneWidget);
      expect(find.text('Dolo 650mg Tablet'), findsWidgets);
      expect(find.text('Strip of 15 tablets'), findsWidgets);
      expect(find.text('₹32'), findsWidgets);
      expect(find.text('MRP ₹40'), findsOneWidget);
      expect(find.textContaining('You save ₹8'), findsOneWidget);
    });

    testWidgets('highlights are open by default, other sections collapsed', (
      tester,
    ) async {
      await pumpDetail(tester, dolo);

      expect(find.textContaining('100% genuine'), findsOneWidget);
      expect(find.textContaining('oral formulation'), findsNothing);
    });

    testWidgets('a section reveals its body when its header is tapped', (
      tester,
    ) async {
      await pumpDetail(tester, dolo);

      await tester.tap(find.text('Product description'));
      await tester.pumpAndSettle();
      expect(find.textContaining('oral formulation'), findsOneWidget);

      await tester.tap(find.text('Directions for use'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Swallow whole'), findsOneWidget);
    });

    testWidgets('a FAQ row opens its answer', (tester) async {
      await pumpDetail(tester, dolo);

      final question = ProductDetail.of(dolo).faqs[1].question;
      expect(find.text(question), findsOneWidget);

      await tester.tap(find.text(question));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Take exactly as directed'),
        findsOneWidget,
      );
    });

    testWidgets('ADD puts the product in the shared cart', (tester) async {
      await pumpDetail(tester, dolo);

      expect(find.byType(CartBar), findsOneWidget);
      expect(find.text('View cart'), findsNothing);

      await tester.tap(find.text('ADD').first);
      await tester.pumpAndSettle();

      expect(CartService.instance.itemCount, 1);
      expect(CartService.instance.lines.single.name, 'Dolo 650mg Tablet');
      expect(find.text('View cart'), findsOneWidget);
    });

    testWidgets('"Customers also bought" lists other products', (tester) async {
      await pumpDetail(tester, dolo);

      final rail = find.text('Customers also bought');
      await tester.scrollUntilVisible(
        rail,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(rail, findsOneWidget);

      // The header carries one cart control; the rail adds several more.
      expect(
        find.byType(CartControl).evaluate().length,
        greaterThan(1),
      );
    });

    testWidgets('a device product shows device-specific directions', (
      tester,
    ) async {
      await pumpDetail(tester, monitor);

      await tester.tap(find.text('Directions for use'));
      await tester.pumpAndSettle();

      expect(find.textContaining('instruction manual'), findsOneWidget);
    });
  });

  testWidgets('tapping a product tile in a listing opens its details page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final personalCare = CategoryCatalogue.groups.firstWhere(
      (group) => group.title == 'Personal Care',
    );
    final skinCare = personalCare.items.firstWhere(
      (item) => item.label == 'Skin Care',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryListingScreen(group: personalCare, initial: skinCare),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ProductTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(find.text('Product Details'), findsOneWidget);
  });
}
