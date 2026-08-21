import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/categories/categories_screen.dart';
import 'package:shield/module/categories/category_catalogue.dart';
import 'package:shield/module/categories/category_listing_screen.dart';
import 'package:shield/module/categories/listing_catalogue.dart';

void main() {
  setUp(CartService.instance.reset);

  final personalCare = CategoryCatalogue.groups.firstWhere(
    (group) => group.title == 'Personal Care',
  );

  Future<void> pumpListing(
    WidgetTester tester, {
    SubCategory? initial,
    Size size = const Size(400, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryListingScreen(group: personalCare, initial: initial),
      ),
    );
    await tester.pumpAndSettle();
  }

  SubCategory subCategory(String label) =>
      personalCare.items.firstWhere((item) => item.label == label);

  group('listing catalogue', () {
    test('curated sub-categories return their own products', () {
      final skin = ListingCatalogue.forSubCategory(subCategory('Skin Care'));
      expect(skin, isNotEmpty);
      expect(
        skin.any((p) => p.name.contains('Sunscreen')),
        isTrue,
        reason: 'skin care should list its curated stock',
      );
    });

    test('uncurated sub-categories still name their section', () {
      final surgical = ListingCatalogue.forSubCategory(
        CategoryCatalogue.groups
            .firstWhere((group) => group.title == 'Surgicals')
            .items
            .first,
      );
      expect(surgical, isNotEmpty);
      for (final product in surgical) {
        expect(
          product.name,
          contains('Gloves & Masks'),
          reason: 'generated stock must belong to the section it opened from',
        );
      }
    });

    test('curated personal care and vitamins return curated products', () {
      final grooming = ListingCatalogue.forSubCategory(
        subCategory('Men Grooming'),
      );
      expect(grooming, isNotEmpty);
      expect(grooming.any((p) => p.name.contains('Charcoal')), isTrue);

      final bath = ListingCatalogue.forSubCategory(subCategory('Bath & Body'));
      expect(bath, isNotEmpty);
      expect(bath.any((p) => p.name.contains('Body Wash')), isTrue);
    });

    test('the All view spans every sub-category', () {
      final all = ListingCatalogue.forGroup(personalCare);
      final skin = ListingCatalogue.forSubCategory(subCategory('Skin Care'));
      expect(all.length, greaterThan(skin.length));
    });

    test('top deals are the steepest discounts, capped at five', () {
      final deals = ListingCatalogue.topDeals(
        ListingCatalogue.forGroup(personalCare),
      );
      expect(deals.length, lessThanOrEqualTo(5));

      int percent(String? label) =>
          label == null ? 0 : int.parse(label.split('%').first.trim());

      for (var i = 1; i < deals.length; i++) {
        expect(
          percent(deals[i - 1].discountLabel),
          greaterThanOrEqualTo(percent(deals[i].discountLabel)),
          reason: 'deals must be ordered by discount',
        );
      }
    });
  });

  group('listing screen', () {
    testWidgets('opens on the tapped sub-category with banner and deals', (
      tester,
    ) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));

      expect(find.text('Personal Care'), findsWidgets);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Skin Care'), findsWidgets);
      expect(find.text('Top deals'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.textContaining('Sunscreen'), findsWidgets);
    });

    testWidgets('switching a chip swaps the products', (tester) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));
      expect(find.textContaining('Sunscreen'), findsWidgets);

      await tester.tap(find.text('Hair Care').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Shampoo'), findsWidgets);
      expect(find.textContaining('Sunscreen'), findsNothing);
    });

    testWidgets('ADD puts the product in the shared cart', (tester) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));

      expect(CartService.instance.itemCount, 0);
      expect(find.byType(CartBar), findsOneWidget);
      expect(find.text('View cart'), findsNothing);

      await tester.tap(find.text('ADD').first);
      await tester.pumpAndSettle();

      expect(CartService.instance.itemCount, 1);
      // The bar appears only once something is in the cart.
      expect(find.text('View cart'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
    });

    testWidgets('the tile becomes a stepper once added', (tester) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));

      final firstAdd = find.text('ADD').first;
      await tester.tap(firstAdd);
      await tester.pumpAndSettle();

      // That tile now shows a quantity instead of ADD.
      expect(find.byType(CartControl), findsWidgets);
      expect(CartService.instance.lines.single.qty, 1);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
      await tester.pumpAndSettle();
      expect(CartService.instance.lines.single.qty, 2);
      expect(find.text('2 items'), findsOneWidget);
    });

    testWidgets('a category tap from the Categories tab opens the listing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skin Care').first);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryListingScreen), findsOneWidget);
      expect(find.text('Top deals'), findsOneWidget);
    });

    testWidgets('listing lays out on a narrow phone', (tester) async {
      await pumpListing(
        tester,
        initial: subCategory('Skin Care'),
        size: const Size(320, 2400),
      );

      expect(find.text('Top deals'), findsOneWidget);
    });

    /// The artwork is square (512x512 assets), so its box has to be square
    /// too. Contained in a shorter box it is limited by the height and sits
    /// with a gutter down either side, which is what made it read as small.
    void expectSquareArtwork(WidgetTester tester) {
      final tile = find.byType(ProductTile).first;
      final art = find
          .descendant(of: tile, matching: find.byType(AspectRatio))
          .first;

      final tileSize = tester.getSize(tile);
      final artSize = tester.getSize(art);

      expect(artSize.width, artSize.height, reason: 'the box must be square');
      expect(
        artSize.width,
        greaterThan(tileSize.width - 4),
        reason: 'and span the tile, less its border',
      );
      expect(
        artSize.height,
        greaterThanOrEqualTo(tileSize.height - artSize.height),
        reason:
            'the artwork is never the smaller half of the tile. It is the '
            'larger one wherever a column is wider than the details extent, '
            'and exactly half on the narrowest phones.',
      );
    }

    testWidgets('the artwork is square and the larger half of the tile', (
      tester,
    ) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));

      expectSquareArtwork(tester);
    });

    testWidgets('it stays square on a narrow phone', (tester) async {
      await pumpListing(
        tester,
        initial: subCategory('Skin Care'),
        size: const Size(320, 2400),
      );

      expectSquareArtwork(tester);
    });
  });
}
