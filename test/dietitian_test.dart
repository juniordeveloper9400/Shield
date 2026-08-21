import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/dietitian/dietitian.dart';
import 'package:shield/module/dietitian/dietitian_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(400, 2600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: DietitianScreen()));
    await tester.pumpAndSettle();
  }

  group('the panel', () {
    test('every dietitian is bookable and priced', () {
      expect(DietitianDirectory.all, isNotEmpty);

      for (final dietitian in DietitianDirectory.all) {
        expect(dietitian.name, isNotEmpty, reason: dietitian.name);
        expect(dietitian.qualification, isNotEmpty, reason: dietitian.name);
        expect(dietitian.focus, isNotEmpty, reason: dietitian.name);
        expect(dietitian.languages, isNotEmpty, reason: dietitian.name);
        expect(dietitian.fee, greaterThan(0), reason: dietitian.name);
        expect(dietitian.nextSlot, isNotEmpty, reason: dietitian.name);
        expect(dietitian.initials.length, 2, reason: dietitian.name);
      }
    });

    test('Malayalam is covered, which is where the counters are', () {
      expect(
        DietitianDirectory.all.every((d) => d.languages.contains('Malayalam')),
        isTrue,
      );
    });

    test('the summary reads as experience and languages', () {
      expect(
        DietitianDirectory.all.first.summary,
        '12 yrs · Malayalam, English',
      );
    });

    test('search matches a name, a qualification or a condition', () {
      expect(DietitianDirectory.search('anjali').single.initials, 'AM');
      expect(DietitianDirectory.search('THYROID').single.initials, 'AM');
      expect(DietitianDirectory.search('Ayurveda').single.initials, 'SN');
      expect(DietitianDirectory.search('quantum surgery'), isEmpty);
    });

    test('an empty search returns the panel, not nothing', () {
      expect(DietitianDirectory.search(''), DietitianDirectory.all);
      expect(DietitianDirectory.search('   '), DietitianDirectory.all);
    });
  });

  group('the screen', () {
    testWidgets('leads with what a consultation includes', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Talk to a dietitian'), findsOneWidget);
      for (final line in DietitianDirectory.included) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
    });

    testWidgets('lists everyone, with fee and next slot', (tester) async {
      await pumpScreen(tester);

      for (final dietitian in DietitianDirectory.all) {
        expect(find.text(dietitian.name), findsOneWidget);
        expect(find.text(dietitian.nextSlot), findsOneWidget);
      }
      expect(find.text('₹400'), findsOneWidget);
      expect(find.text('Book'), findsNWidgets(DietitianDirectory.all.length));
    });

    testWidgets('search narrows the list and can come back', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'thyroid');
      await tester.pumpAndSettle();

      expect(find.text('Dr. Anjali Menon'), findsOneWidget);
      expect(find.text('Vishnu Prasad'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Vishnu Prasad'), findsOneWidget);
    });

    testWidgets('a search with no match explains itself', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('No dietitian matches that'), findsOneWidget);
      expect(find.text('Book'), findsNothing);
    });

    testWidgets('booking names the dietitian and the slot', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Book').first);
      await tester.pumpAndSettle();

      // One string, not two finders: the card also shows the slot, so
      // matching on it alone would find the card as well as the notice.
      final first = DietitianDirectory.all.first;
      expect(
        find.text(
          'Consultation with ${first.name} requested · ${first.nextSlot}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('lays out on a narrow phone', (tester) async {
      await pumpScreen(tester, size: const Size(320, 3400));

      expect(find.text('Talk to a dietitian'), findsOneWidget);
      expect(find.text(DietitianDirectory.all.last.name), findsOneWidget);
    });
  });
}
