import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/data/neon/product_repository.dart';
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
    ProductRepository.detailOverride = null;
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

  const adminContent = ProductDetailData(
    form: 'Tablet',
    manufacturer: 'Micro Labs',
    description: 'A fever and pain reliever dosed for adults.',
    ingredients: 'Paracetamol 650mg.',
    storage: 'Store below 25°C, away from moisture.',
    highlights: ['Fast-acting', 'No prescription needed'],
    benefits: ['Brings down fever', 'Eases body pain'],
    directions: ['Take one tablet every 6 hours as needed.'],
    safety: ['Do not exceed 4 tablets in 24 hours.'],
    faqs: [ProductFaq('Can I take this with food?', 'Yes, with or without food.')],
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
    test('with nothing admin-entered, every detail field is blank', () {
      final detail = ProductDetail.of(dolo);

      expect(detail.highlights, isEmpty);
      expect(detail.description, isEmpty);
      expect(detail.benefits, isEmpty);
      expect(detail.directions, isEmpty);
      expect(detail.safety, isEmpty);
      expect(detail.ingredients, isEmpty);
      expect(detail.storage, isEmpty);
      expect(detail.faqs, isEmpty);
      // Pricing is the catalogue's own data, not admin detail — still shown.
      expect(detail.discountPercent, 20);
      expect(detail.saveLabel, '₹8');
      expect(detail.unitPriceLabel, '₹2.13/unit');
      // The form still infers from the name/pack, since it only drives
      // numeric formatting (unitPriceLabel), not any shown copy.
      expect(detail.form, ProductForm.oral);
    });

    test('a device still prices with no per-unit figure, with nothing added', () {
      final detail = ProductDetail.of(monitor);

      expect(detail.form, ProductForm.device);
      expect(detail.unitPriceLabel, isNull);
      expect(detail.storage, isEmpty);
    });

    test('whatever the admin entered is shown exactly as typed', () {
      final detail = ProductDetail.of(dolo, content: adminContent);

      expect(detail.manufacturer, 'Micro Labs');
      expect(detail.description, adminContent.description);
      expect(detail.highlights, adminContent.highlights);
      expect(detail.benefits, adminContent.benefits);
      expect(detail.directions, adminContent.directions);
      expect(detail.safety, adminContent.safety);
      expect(detail.ingredients, adminContent.ingredients);
      expect(detail.storage, adminContent.storage);
      expect(detail.faqs, adminContent.faqs);
    });

    test('a field the admin left blank stays blank, even with others filled', () {
      const partial = ProductDetailData(highlights: ['Fast-acting']);
      final detail = ProductDetail.of(dolo, content: partial);

      expect(detail.highlights, ['Fast-acting']);
      expect(detail.description, isEmpty);
      expect(detail.benefits, isEmpty);
      expect(detail.faqs, isEmpty);
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

  group('product detail screen — nothing admin-entered', () {
    testWidgets('lays out the header, price, MRP and saving', (tester) async {
      await pumpDetail(tester, dolo);

      expect(find.text('Product Details'), findsOneWidget);
      expect(find.text('Dolo 650mg Tablet'), findsWidgets);
      expect(find.text('Strip of 15 tablets'), findsWidgets);
      expect(find.text('₹32'), findsWidgets);
      expect(find.text('MRP ₹40'), findsOneWidget);
      expect(find.textContaining('You save ₹8'), findsOneWidget);
    });

    testWidgets('shows no section a blank admin form would have left empty', (
      tester,
    ) async {
      await pumpDetail(tester, dolo);

      expect(find.byIcon(Icons.ac_unit_rounded), findsNothing); // storage strip
      expect(find.text('Product highlights'), findsNothing);
      expect(find.text('Product description'), findsNothing);
      expect(find.text('Key benefits'), findsNothing);
      expect(find.text('Directions for use'), findsNothing);
      expect(find.text('Ingredients'), findsNothing);
      expect(find.text('Safety information'), findsNothing);
      expect(find.text('Frequently asked questions'), findsNothing);
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

    testWidgets('"Customers also bought" still lists other products', (
      tester,
    ) async {
      await pumpDetail(tester, dolo);

      final rail = find.text('Customers also bought');
      await tester.scrollUntilVisible(
        rail,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(rail, findsOneWidget);

      // The header carries one cart control; the rail adds several more.
      expect(find.byType(CartControl).evaluate().length, greaterThan(1));
    });
  });

  group('product detail screen — admin-entered content', () {
    const idProduct = Product(
      name: 'Dolo 650mg Tablet',
      pack: 'Strip of 15 tablets',
      price: '32',
      mrp: '40',
      discountLabel: '20% OFF',
      icon: Icons.medication_outlined,
      id: 'rx-dolo-1',
    );

    testWidgets('shows exactly the sections the admin filled in, and no others', (
      tester,
    ) async {
      ProductRepository.detailOverride = (uuid) async {
        expect(uuid, 'rx-dolo-1');
        return adminContent;
      };

      await pumpDetail(tester, idProduct);

      expect(find.text('Product highlights'), findsOneWidget);
      expect(find.text('Product description'), findsOneWidget);
      expect(find.text('Key benefits'), findsOneWidget);
      expect(find.text('Directions for use'), findsOneWidget);
      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('Safety information'), findsOneWidget);
      expect(find.text('Frequently asked questions'), findsOneWidget);
      expect(find.byIcon(Icons.ac_unit_rounded), findsOneWidget);
      expect(find.text(adminContent.storage), findsOneWidget);
    });

    testWidgets('highlights are open by default, other sections collapsed', (
      tester,
    ) async {
      ProductRepository.detailOverride = (_) async => adminContent;

      await pumpDetail(tester, idProduct);

      expect(find.text('Fast-acting'), findsOneWidget);
      expect(find.textContaining('fever and pain reliever'), findsNothing);
    });

    testWidgets('a section reveals its body when its header is tapped', (
      tester,
    ) async {
      ProductRepository.detailOverride = (_) async => adminContent;

      await pumpDetail(tester, idProduct);

      await tester.tap(find.text('Product description'));
      await tester.pumpAndSettle();
      expect(find.textContaining('fever and pain reliever'), findsOneWidget);

      await tester.tap(find.text('Directions for use'));
      await tester.pumpAndSettle();
      expect(find.textContaining('every 6 hours'), findsOneWidget);
    });

    testWidgets('a FAQ row opens its answer', (tester) async {
      ProductRepository.detailOverride = (_) async => adminContent;

      await pumpDetail(tester, idProduct);

      final question = adminContent.faqs.first.question;
      expect(find.text(question), findsOneWidget);

      await tester.tap(find.text(question));
      await tester.pumpAndSettle();

      expect(find.textContaining('with or without food'), findsOneWidget);
    });

    testWidgets('a field left blank in a partial form still has no section', (
      tester,
    ) async {
      ProductRepository.detailOverride = (_) async =>
          const ProductDetailData(highlights: ['Fast-acting']);

      await pumpDetail(tester, idProduct);

      expect(find.text('Product highlights'), findsOneWidget);
      expect(find.text('Product description'), findsNothing);
      expect(find.text('Key benefits'), findsNothing);
      expect(find.text('Frequently asked questions'), findsNothing);
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
