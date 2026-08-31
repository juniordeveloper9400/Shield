import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/cart/cart_bar.dart';
import 'package:shield/module/cart/cart_control.dart';
import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/categories/categories_screen.dart';
import 'package:shield/module/categories/category_catalogue.dart';
import 'package:shield/module/categories/category_listing_screen.dart';
import 'package:shield/module/categories/listing_catalogue.dart';
import 'package:shield/module/categories/listing_filter.dart';

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

    testWidgets('the tile opens a quantity picker once added', (tester) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));

      final firstAdd = find.text('ADD').first;
      await tester.tap(firstAdd);
      await tester.pumpAndSettle();

      // That tile now shows a quantity picker instead of ADD.
      expect(find.byType(CartControl), findsWidgets);
      expect(CartService.instance.lines.single.qty, 1);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Select quantity'), findsOneWidget);
      expect(find.text('Remove item'), findsOneWidget);

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      expect(CartService.instance.lines.single.qty, 3);
      expect(find.text('3 items'), findsOneWidget);
    });

    testWidgets('the picker has a stepper and goes up to the max', (
      tester,
    ) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));

      await tester.tap(find.text('ADD').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(QuantityStepper), findsOneWidget);

      // The typed field, inside the stepper, sets the quantity and clamps
      // anything over the ceiling back down to it.
      final field = find.descendant(
        of: find.byType(QuantityStepper),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, '9999');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(CartService.instance.lines.single.qty, CartService.maxLineQty);

      // The + button is now disabled at the ceiling.
      final plus = tester.widget<InkWell>(
        find.ancestor(
          of: find.byIcon(Icons.add_rounded),
          matching: find.byType(InkWell),
        ),
      );
      expect(plus.onTap, isNull);
    });

    testWidgets('quantity picker can remove the selected item', (tester) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));

      await tester.tap(find.text('ADD').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove item'));
      await tester.pumpAndSettle();

      expect(CartService.instance.itemCount, 0);
      expect(find.text('ADD'), findsWidgets);
      expect(find.text('View cart'), findsNothing);
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

    testWidgets('the chip rail and filter stay pinned as the grid scrolls', (
      tester,
    ) async {
      await pumpListing(
        tester,
        initial: subCategory('Skin Care'),
        size: const Size(400, 720),
      );

      // Before scrolling the strip sits below the banner.
      final filterBefore = tester.getTopLeft(find.text('Filter')).dy;
      expect(filterBefore, greaterThan(200));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // It is still there, and has risen to pin just under the app bar rather
      // than scrolling away with the banner.
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Skin Care'), findsWidgets);
      final filterAfter = tester.getTopLeft(find.text('Filter')).dy;
      expect(filterAfter, lessThan(filterBefore));
      expect(filterAfter, lessThan(260));
    });
  });

  group('listing filter', () {
    test('the inactive filter lists the whole group', () {
      expect(ListingFilter.none.isActive, isFalse);
      expect(ListingFilter.none.count, 0);
      expect(
        ListingFilter.none.resolve(personalCare).length,
        ListingCatalogue.forGroup(personalCare).length,
      );
    });

    test('a sub-category pick narrows to that sub-category', () {
      const filter = ListingFilter(subCategories: {'Hair Care'});
      expect(filter.count, 1);
      expect(
        filter.resolve(personalCare),
        equals(ListingCatalogue.forSubCategory(subCategory('Hair Care'))),
      );
    });

    test('two sub-category picks union their products', () {
      const filter = ListingFilter(subCategories: {'Skin Care', 'Hair Care'});
      final expected =
          ListingCatalogue.forSubCategory(subCategory('Skin Care')).length +
          ListingCatalogue.forSubCategory(subCategory('Hair Care')).length;
      expect(filter.resolve(personalCare).length, expected);
      expect(filter.count, 2);
    });

    test('a brand pick keeps only that brand', () {
      const filter = ListingFilter(brands: {'Cetaphil'});
      final result = filter.resolve(personalCare);
      expect(result, isNotEmpty);
      expect(
        result.every((p) => ListingCatalogue.brandOf(p) == 'Cetaphil'),
        isTrue,
      );
    });

    test('sub-category and brand picks combine', () {
      const filter = ListingFilter(
        subCategories: {'Skin Care'},
        brands: {'Minimalist'},
      );
      final skin = ListingCatalogue.forSubCategory(subCategory('Skin Care'));
      final result = filter.resolve(personalCare);
      expect(result, isNotEmpty);
      expect(
        result.every(
          (p) => ListingCatalogue.brandOf(p) == 'Minimalist' && skin.contains(p),
        ),
        isTrue,
      );
    });

    test('the chip selection applies only until the sheet overrides it', () {
      final skinChip = subCategory('Skin Care');
      expect(
        ListingFilter.none.resolve(personalCare, chip: skinChip),
        equals(ListingCatalogue.forSubCategory(skinChip)),
      );

      const withSheet = ListingFilter(subCategories: {'Hair Care'});
      expect(
        withSheet.resolve(personalCare, chip: skinChip),
        equals(ListingCatalogue.forSubCategory(subCategory('Hair Care'))),
      );
    });

    test('every product in every group resolves to one listed brand', () {
      for (final group in CategoryCatalogue.groups) {
        final brands = ListingCatalogue.brandsFor(group);
        expect(brands, isNotEmpty);
        for (final product in ListingCatalogue.forGroup(group)) {
          expect(brands, contains(ListingCatalogue.brandOf(product)));
        }
      }
    });
  });

  group('listing filter sheet', () {
    Finder inSheet(String text) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(text),
    );

    testWidgets('the Filter pill opens the two-pane sheet', (tester) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      expect(find.text('Filters'), findsOneWidget);
      expect(inSheet('Sub-categories'), findsOneWidget);
      expect(inSheet('Brands'), findsOneWidget);
      // The options pane opens on Sub-categories, headed by the group name.
      expect(inSheet('Personal Care'), findsOneWidget);
      expect(inSheet('Apply'), findsOneWidget);
      expect(inSheet('Clear'), findsOneWidget);
    });

    testWidgets('the sheet fills the screen, no gap at the top', (tester) async {
      await pumpListing(
        tester,
        initial: subCategory('Skin Care'),
        size: const Size(400, 800),
      );

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.top, lessThan(40), reason: 'starts at the top');
      expect(sheet.height, greaterThan(740), reason: 'covers the page');
    });

    testWidgets('picking a sub-category narrows the grid and numbers the pill', (
      tester,
    ) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Hair Care'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Apply (1)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Shampoo'), findsWidgets);
      expect(find.textContaining('Sunscreen'), findsNothing);
      expect(find.text('Filter · 1'), findsOneWidget);
    });

    testWidgets('the Brands tab filters the grid to a single brand', (
      tester,
    ) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Brands').first);
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Cetaphil'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Apply (1)'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductTile), findsOneWidget);
      final only = tester.widget<ProductTile>(find.byType(ProductTile));
      expect(only.product.name, contains('Cetaphil'));
      expect(find.text('Filter · 1'), findsOneWidget);
    });

    testWidgets('Clear empties every tab before Apply', (tester) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));
      final total = find.byType(ProductTile).evaluate().length;

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Brands').first);
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Cetaphil'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Apply'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductTile).evaluate().length, total);
      expect(find.text('Filter'), findsOneWidget);
    });

    testWidgets('an unmatched sub-category × brand shows the empty state', (
      tester,
    ) async {
      await pumpListing(tester, initial: subCategory('Skin Care'));

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Hair Care'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Brands').first);
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Cetaphil'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Apply (2)'));
      await tester.pumpAndSettle();

      expect(find.text('No products match your filters'), findsOneWidget);
      expect(find.byType(ProductTile), findsNothing);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductTile), findsWidgets);
    });
  });
}
