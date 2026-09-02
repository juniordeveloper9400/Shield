import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/categories/category_catalogue.dart';
import 'package:shield/module/categories/category_listing_screen.dart';
import 'package:shield/module/categories/listing_catalogue.dart';
import 'package:shield/module/search/search_catalogue.dart';
import 'package:shield/module/search/search_screen.dart';
import 'package:shield/screens/home_screen.dart';

import 'support/fake_catalogue.dart';

void main() {
  // Search runs against CatalogueService, which has no database in a test.
  setUp(seedFakeCatalogue);
  tearDown(resetFakeCatalogue);

  group('the search catalogue', () {
    test('a blank query turns up nothing', () {
      expect(SearchCatalogue.search(''), isEmpty);
      expect(SearchCatalogue.search('   '), isEmpty);
    });

    test('matches by name, case-insensitively', () {
      final results = SearchCatalogue.search('dolo');
      expect(results, isNotEmpty);
      expect(results.every((p) => p.name.toLowerCase().contains('dolo')), isTrue);

      expect(SearchCatalogue.search('DOLO'), hasLength(results.length));
    });

    test('matches by pack as well as name', () {
      final results = SearchCatalogue.search('strip of 15');
      expect(results, isNotEmpty);
      expect(
        results.every((p) => p.pack.toLowerCase().contains('strip of 15')),
        isTrue,
      );
    });

    test('the catalogue lists each product once', () {
      // The catalogue is the single `app.product` list, so a name resolves to
      // exactly one row — a search never doubles it up.
      final results = SearchCatalogue.search('Accu-Chek Test Strips');
      expect(
        results.where((p) => p.name == 'Accu-Chek Test Strips'),
        hasLength(1),
      );
    });

    test('nonsense turns up nothing', () {
      expect(SearchCatalogue.search('zzzznotaproduct'), isEmpty);
    });

    test('every category group contributes to the pool', () {
      final names = SearchCatalogue.all.map((p) => p.name).toSet();
      for (final group in CategoryCatalogue.groups) {
        for (final item in group.items) {
          for (final product in ListingCatalogue.forSubCategory(item)) {
            expect(
              names,
              contains(product.name),
              reason: '${group.title} · ${item.label} · ${product.name}',
            );
          }
        }
      }
    });
  });

  group('reaching search', () {
    testWidgets('the home search bar opens the search screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('tapping the search icon inside the bar also opens it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('the category listing search icon opens it too', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: CategoryListingScreen(group: CategoryCatalogue.groups.first),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
    });
  });

  group('the search screen', () {
    Future<void> pumpSearch(WidgetTester tester, {String initial = ''}) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: SearchScreen(initialQuery: initial)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens on suggestions, before anything is typed', (
      tester,
    ) async {
      await pumpSearch(tester);

      expect(find.text('Popular searches'), findsOneWidget);
      for (final suggestion in SearchCatalogue.suggestions) {
        expect(find.text(suggestion), findsOneWidget, reason: suggestion);
      }
    });

    testWidgets('typing filters straight to a results grid', (tester) async {
      await pumpSearch(tester);

      await tester.enterText(find.byType(TextField), 'dolo');
      await tester.pumpAndSettle();

      final count = SearchCatalogue.search('dolo').length;
      expect(
        find.text('$count result${count == 1 ? '' : 's'} for "dolo"'),
        findsOneWidget,
      );
      expect(find.textContaining('Dolo'), findsWidgets);
      expect(find.text('Popular searches'), findsNothing);
    });

    testWidgets('a tapped suggestion fills the box and searches', (
      tester,
    ) async {
      await pumpSearch(tester);

      final suggestion = SearchCatalogue.suggestions.first;
      await tester.tap(find.text(suggestion));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, suggestion), findsOneWidget);
      expect(find.text('Popular searches'), findsNothing);
    });

    testWidgets('nothing matching says so, with the query named', (
      tester,
    ) async {
      await pumpSearch(tester);

      await tester.enterText(find.byType(TextField), 'zzzznotaproduct');
      await tester.pumpAndSettle();

      expect(find.text('No results for "zzzznotaproduct"'), findsOneWidget);
    });

    testWidgets('the clear button empties the box back to suggestions', (
      tester,
    ) async {
      await pumpSearch(tester, initial: 'dolo');

      expect(find.text('Popular searches'), findsNothing);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, ''), findsOneWidget);
      expect(find.text('Popular searches'), findsOneWidget);
    });

    testWidgets('the back arrow leaves the screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsNothing);
    });
  });
}
