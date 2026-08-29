import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:shield/module/categories/categories_screen.dart';
import 'package:shield/module/categories/category_card.dart';
import 'package:shield/module/categories/category_catalogue.dart';
import 'package:shield/module/categories/category_listing_screen.dart';
import 'package:shield/module/home/category_section.dart';

void main() {
  Future<void> pumpCategories(
    WidgetTester tester, {
    Size size = const Size(400, 2000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));
    await tester.pumpAndSettle();
  }

  /// The panels are tall, so anything past the first two groups has to be
  /// scrolled into existence before it can be found.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('catalogue', () {
    test('every shoppable sub-category carries artwork', () {
      for (final group in CategoryCatalogue.shoppable) {
        expect(group.items, hasLength(6), reason: group.title);
        if (CategoryCatalogue.withoutArtwork.contains(group.title)) {
          continue;
        }
        for (final item in group.items) {
          expect(
            item.image,
            isNotNull,
            reason: '${group.title} / ${item.label} has no image',
          );
        }
      }
    });

    test('category artwork has transparent card backgrounds', () {
      final paths = {
        for (final group in CategoryCatalogue.shoppable) ...[
          if (group.image != null) group.image!,
          for (final item in group.items)
            if (item.image != null) item.image!,
        ],
      };

      for (final path in paths) {
        final decoded = img.decodePng(File(path).readAsBytesSync());
        expect(decoded, isNotNull, reason: path);
        final image = decoded!.convert(numChannels: 4);
        var transparentBorder = 0;

        void sample(int x, int y) {
          if (image.getPixel(x, y).a == 0) {
            transparentBorder++;
          }
        }

        for (var x = 0; x < image.width; x++) {
          sample(x, 0);
          sample(x, image.height - 1);
        }
        for (var y = 0; y < image.height; y++) {
          sample(0, y);
          sample(image.width - 1, y);
        }

        expect(
          transparentBorder,
          greaterThan(0),
          reason: '$path should let the card colour show through',
        );
      }
    });

    test('the artwork exemption list is honest about what it covers', () {
      // A group may only appear in withoutArtwork while it genuinely has no
      // images, so the exemption cannot outlive the gap it documents.
      for (final title in CategoryCatalogue.withoutArtwork) {
        final group = CategoryCatalogue.groups.firstWhere(
          (group) => group.title == title,
        );
        expect(
          group.items.every((item) => item.image == null),
          isTrue,
          reason: '$title has artwork and should leave withoutArtwork',
        );
      }
    });

    test('lab tests is last and is not shoppable', () {
      expect(CategoryCatalogue.groups.last.title, 'Lab Tests');
      expect(
        CategoryCatalogue.shoppable.map((group) => group.title),
        isNot(contains('Lab Tests')),
      );
      for (final item in CategoryCatalogue.groups.last.items) {
        expect(item.image, isNull);
      }
    });

    test('every group has its own panel colour', () {
      final tints = CategoryCatalogue.groups
          .map((group) => group.panelTint)
          .toSet();
      expect(tints, hasLength(CategoryCatalogue.groups.length));
    });

    test('the view-all label names the group', () {
      expect(
        CategoryCatalogue.groups.first.viewAllLabel,
        'View all Personal Care products',
      );
    });
  });

  group('the screen', () {
    testWidgets('opens on a panel of image cards, not bare icons', (
      tester,
    ) async {
      await pumpCategories(tester);

      expect(find.text('Personal Care'), findsOneWidget);
      expect(find.text('Skin Care'), findsOneWidget);
      expect(find.text('Up to 50% off'), findsWidgets);

      final images = find.descendant(
        of: find.byType(CategoryCard),
        matching: find.byType(Image),
      );
      expect(images, findsWidgets);
    });

    testWidgets('every group gets a panel and a view-all link', (tester) async {
      await pumpCategories(tester);

      for (final group in CategoryCatalogue.groups) {
        await scrollTo(tester, find.text(group.title));
        expect(find.text(group.title), findsOneWidget);
        expect(find.text(group.viewAllLabel), findsOneWidget);
      }
    });

    testWidgets('lab tests section is present with its tiles', (tester) async {
      await pumpCategories(tester);
      await scrollTo(tester, find.text('Lab Tests'));

      expect(find.text('Full Body Checkup'), findsOneWidget);
      expect(find.text('Blood Tests'), findsOneWidget);
      expect(find.text('Thyroid Profile'), findsOneWidget);
      expect(find.text('Vitamin Tests'), findsOneWidget);
    });

    testWidgets('a card opens that sub-category listing', (tester) async {
      await pumpCategories(tester);

      await tester.tap(find.text('Skin Care'));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryListingScreen), findsOneWidget);
      // Opened on the tapped sub-category, not the whole group.
      expect(find.textContaining('Sunscreen'), findsWidgets);
    });

    testWidgets('the view-all link opens the group listing', (tester) async {
      await pumpCategories(tester);

      await tester.tap(find.text('View all Personal Care products'));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryListingScreen), findsOneWidget);
      // The All chip heads the rail. Top deals sits below 24 products here,
      // far past the fold, so it is not built at this viewport.
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('narrow viewport lays out without overflow', (tester) async {
      await pumpCategories(tester, size: const Size(320, 2000));
      await scrollTo(tester, find.text('Lab Tests'));

      expect(find.text('Full Body Checkup'), findsOneWidget);
    });
  });

  group('shared with the home strip', () {
    testWidgets('the home strip renders the same card', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: CategorySection())),
        ),
      );
      await tester.pumpAndSettle();

      // Vitamins & Supplements is the chip the strip opens on: its
      // sub-categories are the wellness products the feed shows underneath.
      expect(find.text('Multivitamins'), findsOneWidget);
      expect(find.text('Immunity'), findsOneWidget);
      expect(find.text('Protein Powder'), findsOneWidget);
      // And not Personal Care's, which is what it used to open on.
      expect(find.text('Skin Care'), findsNothing);
      expect(find.byType(CategoryCard), findsNWidgets(6));
    });

    testWidgets('the strip offers every shoppable group as a chip', (
      tester,
    ) async {
      // Wide enough that the whole rail lays out at once; at phone width the
      // trailing chips scroll out of view and are never built.
      tester.view.physicalSize = const Size(640, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: CategorySection())),
        ),
      );
      await tester.pumpAndSettle();

      for (final group in CategoryCatalogue.shoppable) {
        expect(find.text(group.tabLabel), findsOneWidget);
      }
      // Bookings are not shoppable, so the strip does not offer them.
      expect(find.text('Lab\nTests'), findsNothing);
    });
  });
}
