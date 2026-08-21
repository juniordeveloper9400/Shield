import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/refer/journey_map.dart';
import 'package:shield/module/refer/refer_earn_screen.dart';
import 'package:shield/module/refer/referral_level.dart';
import 'package:shield/screens/home_screen.dart';

void main() {
  const levels = ReferralLadder.levels;

  group('level rules', () {
    test(
      'a level needs direct referrals and enough of them activating privilege card',
      () {
        const level2 = ReferralLevel(
          level: 2,
          title: 'Silver Shield',
          cardName: 'Silver Shield',
          requirement: 'Refer 2 members and activate Silver Privilege Card',
          directRequired: 2,
          cardsRequired: 2,
          reward: '₹200',
          isCash: true,
        );

        // Two referrals, but neither has activated a card yet.
        const noCards = ReferralProgress(directReferrals: 2, cardsActivated: 0);
        expect(noCards.isLevelCleared(level2), isFalse);

        // Only one of the two activated — still short of the rule.
        const oneCard = ReferralProgress(directReferrals: 2, cardsActivated: 1);
        expect(oneCard.isLevelCleared(level2), isFalse);

        const bothCards = ReferralProgress(
          directReferrals: 2,
          cardsActivated: 2,
        );
        expect(bothCards.isLevelCleared(level2), isTrue);
      },
    );

    test('card activations cannot exceed referrals', () {
      // Inconsistent upstream data must not unlock a level: you cannot have
      // more card activations than people you referred.
      const bogus = ReferralProgress(directReferrals: 1, cardsActivated: 9);
      expect(bogus.effectiveCards, 1);
      expect(bogus.currentLevel(levels), 1);
    });

    test('current level is the highest consecutively cleared level', () {
      const nothing = ReferralProgress(directReferrals: 0, cardsActivated: 0);
      expect(nothing.currentLevel(levels), 0);

      const one = ReferralProgress(directReferrals: 1, cardsActivated: 0);
      expect(one.currentLevel(levels), 1);

      // 3 referrals with 2 cards activated clears levels 1 and 2 but not 3, which
      // needs 4 referrals and 3 card activations.
      const three = ReferralProgress(directReferrals: 3, cardsActivated: 2);
      expect(three.currentLevel(levels), 2);
    });

    test('a later level cannot be cleared while an earlier one is not', () {
      // 16 referrals but nobody activated a card: level 2 onwards stay locked, so
      // the ladder must not report level 5.
      const lopsided = ReferralProgress(directReferrals: 16, cardsActivated: 0);
      expect(lopsided.currentLevel(levels), 1);
    });

    test('next level is the first uncleared one', () {
      const three = ReferralProgress(directReferrals: 3, cardsActivated: 2);
      expect(three.nextLevel(levels)?.level, 3);

      const maxed = ReferralProgress(directReferrals: 99, cardsActivated: 99);
      expect(maxed.nextLevel(levels), isNull);
    });

    test('progress towards a level is clamped to 0..1', () {
      const over = ReferralProgress(directReferrals: 20, cardsActivated: 0);
      expect(over.progressTowards(levels[0]), 1.0);

      const partial = ReferralProgress(directReferrals: 2, cardsActivated: 0);
      expect(partial.progressTowards(levels[2]), 0.5);
    });
  });

  group('refer & earn screen', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      ReferralProgress progress = ReferralLadder.sampleProgress,
      Size size = const Size(400, 2600),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: ReferEarnScreen(progress: progress)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the current level and every rung of the ladder', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Current level'), findsOneWidget);
      expect(find.text('Level 2 · Silver Shield'), findsWidgets);
      expect(find.text('2 of 5'), findsOneWidget);

      for (final level in levels) {
        expect(
          find.textContaining('Level ${level.level} · ${level.title}'),
          findsWidgets,
          reason: 'level ${level.level} card should render',
        );
      }
      expect(find.textContaining('Earn 100 points'), findsOneWidget);
      expect(find.textContaining('Earn ₹3,000'), findsOneWidget);
    });

    testWidgets('level cards expose the underlying detail counts', (
      tester,
    ) async {
      await pumpScreen(tester);

      // Scoped to the map: the standing card carries its own "Referred"
      // metric, which would otherwise inflate these counts.
      Finder inMap(String text) => find.descendant(
        of: find.byType(JourneyMap),
        matching: find.text(text),
      );

      // Every level shows a Referred bar; those gated on card activations also
      // show a Privilege bar. Levels 2-5 require cards, level 1 does
      // not.
      expect(inMap('Referred'), findsNWidgets(levels.length));
      expect(inMap('Privilege'), findsNWidgets(levels.length - 1));

      // Cleared levels cap the displayed figure at the requirement rather than
      // reporting a raw total such as 3/1.
      expect(find.text('1/1'), findsOneWidget);
      expect(find.text('2/2'), findsNWidgets(2));

      // Level 3 is in progress: 3 of 4 referred, 2 of 3 cards activated.
      expect(find.text('3/4'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);

      expect(find.text('Cleared'), findsNWidgets(2));
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Locked'), findsNWidgets(2));
    });

    testWidgets('offers invite rather than copy or share', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Invite'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
      expect(find.byIcon(Icons.copy_rounded), findsNothing);
    });

    testWidgets('reflects a beginner with nothing cleared', (tester) async {
      await pumpScreen(
        tester,
        progress: const ReferralProgress(directReferrals: 0, cardsActivated: 0),
      );

      expect(find.text('Not started'), findsOneWidget);
      expect(find.text('0 of 5'), findsOneWidget);
    });

    testWidgets('narrow viewport lays out without overflow', (tester) async {
      await pumpScreen(tester, size: const Size(320, 2600));

      expect(find.text('Your journey'), findsOneWidget);
      expect(find.text('SHIELD-RN4821'), findsOneWidget);
    });
  });

  testWidgets('home card opens the refer & earn screen', (tester) async {
    tester.view.physicalSize = const Size(400, 5200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Refer & Earn'), findsOneWidget);

    await tester.tap(find.text('Refer & Earn'));
    await tester.pumpAndSettle();

    expect(find.text('Your journey'), findsOneWidget);
    expect(find.text('Current level'), findsOneWidget);
  });
}
