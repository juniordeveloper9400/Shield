import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/data/neon/care_repository.dart';
import 'package:shield/module/dietitian/dietitian.dart';
import 'package:shield/module/dietitian/dietitian_screen.dart';

const _dietitians = [
  Dietitian(
    id: '1',
    name: 'Dr. Anjali Menon',
    qualification: 'PhD Clinical Nutrition, RD',
    focus: ['Diabetes', 'Thyroid', 'PCOS'],
    experienceYears: 12,
    languages: ['Malayalam', 'English'],
    fee: 400,
    nextSlot: 'Today, 4:00 PM',
    initials: 'AM',
  ),
  Dietitian(
    id: '2',
    name: 'Fathima Rasheed',
    qualification: 'MSc Food & Nutrition, RD',
    focus: ['Weight management', 'Pregnancy', 'Child nutrition'],
    experienceYears: 8,
    languages: ['Malayalam', 'English', 'Tamil'],
    fee: 300,
    nextSlot: 'Tomorrow, 10:30 AM',
    initials: 'FR',
  ),
  Dietitian(
    id: '3',
    name: 'Vishnu Prasad',
    qualification: 'MSc Dietetics',
    focus: ['Heart health', 'Cholesterol', 'Sports nutrition'],
    experienceYears: 6,
    languages: ['Malayalam', 'English', 'Hindi'],
    fee: 250,
    nextSlot: 'Tomorrow, 6:00 PM',
    initials: 'VP',
  ),
  Dietitian(
    id: '4',
    name: 'Dr. Sreelakshmi Nair',
    qualification: 'MD Ayurveda, Diploma in Nutrition',
    focus: ['Digestive health', 'Post-surgery recovery'],
    experienceYears: 15,
    languages: ['Malayalam', 'English'],
    fee: 500,
    nextSlot: 'Thu, 11:00 AM',
    initials: 'SN',
  ),
];

void main() {
  setUp(() {
    CareRepository.dietitiansOverride = () async => _dietitians;
  });
  tearDown(() {
    CareRepository.dietitiansOverride = null;
  });

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
      expect(_dietitians, isNotEmpty);

      for (final dietitian in _dietitians) {
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
        _dietitians.every((d) => d.languages.contains('Malayalam')),
        isTrue,
      );
    });

    test('the summary reads as experience and languages', () {
      expect(_dietitians.first.summary, '12 yrs · Malayalam, English');
    });

    test('search matches a name, a qualification or a condition', () {
      expect(
        DietitianDirectory.search(_dietitians, 'anjali').single.initials,
        'AM',
      );
      expect(
        DietitianDirectory.search(_dietitians, 'THYROID').single.initials,
        'AM',
      );
      expect(
        DietitianDirectory.search(_dietitians, 'Ayurveda').single.initials,
        'SN',
      );
      expect(
        DietitianDirectory.search(_dietitians, 'quantum surgery'),
        isEmpty,
      );
    });

    test('an empty search returns the panel, not nothing', () {
      expect(DietitianDirectory.search(_dietitians, ''), _dietitians);
      expect(DietitianDirectory.search(_dietitians, '   '), _dietitians);
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

      for (final dietitian in _dietitians) {
        expect(find.text(dietitian.name), findsOneWidget);
        expect(find.text(dietitian.nextSlot), findsOneWidget);
      }
      expect(find.text('₹400'), findsOneWidget);
      expect(find.text('Book'), findsNWidgets(_dietitians.length));
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

    testWidgets('a fetch with nothing to show explains itself', (
      tester,
    ) async {
      CareRepository.dietitiansOverride = () async => const [];
      await pumpScreen(tester);

      expect(find.text('No dietitians available right now'), findsOneWidget);
    });

    testWidgets('booking names the dietitian and the slot', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Book').first);
      await tester.pumpAndSettle();

      // One string, not two finders: the card also shows the slot, so
      // matching on it alone would find the card as well as the notice.
      final first = _dietitians.first;
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
      expect(find.text(_dietitians.last.name), findsOneWidget);
    });
  });
}
