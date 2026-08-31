import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/privilege/privilege_card_face.dart';
import 'package:shield/module/privilege/privilege_tier.dart';
import 'package:shield/module/refer/journey_map.dart';
import 'package:shield/module/refer/refer_earn_screen.dart';
import 'package:shield/module/refer/referral_level.dart';
import 'package:shield/module/refer/reward_graph.dart';
import 'package:shield/screens/home_screen.dart';
import 'package:shield/theme/app_colors.dart';

void main() {
  const levels = ReferralLadder.levels;

  group('the ladder', () {
    test('five rungs, named and numbered without gaps', () {
      expect(levels, hasLength(5));
      expect(levels.map((level) => level.name), [
        'Starter',
        'Riser',
        'Achiever',
        'Champion',
        'Legend',
      ]);
      // Level numbers run 1..n with no gaps, so "1 of 5" means what it says.
      expect(levels.map((level) => level.level), [1, 2, 3, 4, 5]);
    });

    test('a rung asks for referrals and nothing else', () {
      // The ladder used to be built on the privilege cards: a rung was
      // cleared by referring people who then bought Silver, Gold or Platinum.
      // Referring and buying are two different acts and only one of them is
      // what this screen asks for.
      for (final level in levels) {
        expect(
          level.requirement,
          'Refer ${level.referralsRequired} members',
          reason: level.name,
        );
        for (final tier in PrivilegeProgramme.tiers) {
          expect(
            level.requirement,
            isNot(contains(tier.name)),
            reason: level.name,
          );
        }
      }
    });

    test('no rung borrows a privilege card colour', () {
      final planColours = {
        for (final tier in PrivilegeProgramme.tiers) tier.accent,
      };
      for (final level in levels) {
        expect(planColours, isNot(contains(level.accent)), reason: level.name);
      }
      // And no two rungs share one, so the ladder reads as a climb.
      expect(
        levels.map((level) => level.accent).toSet(),
        hasLength(levels.length),
      );
    });

    test('the ladder gets harder and pays more as it climbs', () {
      for (var i = 1; i < levels.length; i++) {
        expect(
          levels[i].referralsRequired,
          greaterThan(levels[i - 1].referralsRequired),
          reason: levels[i].name,
        );
        expect(
          levels[i].points,
          greaterThan(levels[i - 1].points),
          reason: levels[i].name,
        );
      }
    });

    test('progress fills across the rung being worked on', () {
      // Measured from the rung below, not from zero: 19 of 20 on Champion is
      // nearly there, not nearly nothing.
      const onChampion = ReferralProgress(directReferrals: 19);
      expect(onChampion.progressTowards(levels[3], levels), closeTo(0.9, 0.01));
      const justStarted = ReferralProgress(directReferrals: 10);
      expect(justStarted.progressTowards(levels[3], levels), 0);
    });

    test('the ladder pays points, in the published amounts', () {
      // Points, not rupees. The figures are the published ladder and are
      // pinned here so a change to them is a deliberate one.
      expect(levels.map((level) => level.points), [100, 200, 500, 1500, 3000]);
      expect(levels.first.pointsLabel, '100 points');
      expect(levels[3].pointsLabel, '1,500 points');
      expect(levels[3].pointsShort, '1,500 pts');
    });

    test(
      'points earned are the cleared rungs added up, not a stored figure',
      () {
        const nothing = ReferralProgress(directReferrals: 0);
        expect(ReferralLadder.pointsEarnedBy(nothing), 0);
        expect(ReferralLadder.pointsEarnedLabel(nothing), '0');

        // Three referrals clears Starter's two and nothing above it.
        expect(
          ReferralLadder.pointsEarnedBy(ReferralLadder.sampleProgress),
          100,
        );

        const maxed = ReferralProgress(directReferrals: 99);
        expect(
          ReferralLadder.pointsEarnedBy(maxed),
          levels.fold<int>(0, (sum, level) => sum + level.points),
        );
      },
    );

    test('Sahakar money is the commission, not points valued in rupees', () {
      // The two never convert into each other. Clearing the whole ladder pays
      // 5,300 points and not one rupee of Sahakar money; the money comes only
      // from invites activating plans.
      const maxed = ReferralProgress(directReferrals: 99);
      expect(ReferralLadder.pointsEarnedBy(maxed), 5300);
      expect(maxed.sahakarMoney, 0);
      expect(maxed.sahakarMoneyLabel, '₹0');

      // And an invite activating a plan pays money without moving a rung.
      const paid = ReferralProgress(
        directReferrals: 1,
        plansActivated: 1,
        sahakarMoney: 800,
      );
      expect(paid.currentLevel(levels), 0);
      expect(ReferralLadder.pointsEarnedBy(paid), 0);
      expect(paid.sahakarMoneyLabel, '₹800');
    });

    test('Sahakar money is reported, not multiplied out of the count', () {
      // Two activations pay anywhere from ₹400 to ₹4,000 depending on which
      // cards were bought, so the sum has to arrive with the count. What the
      // fixture carries has to sit inside those bounds all the same.
      const sample = ReferralLadder.sampleProgress;
      final least =
          sample.plansActivated *
          ReferralLadder.planCommissionOn(PrivilegeProgramme.minAmount);
      final most =
          sample.plansActivated *
          ReferralLadder.planCommissionOn(PrivilegeProgramme.maxAmount);

      expect(sample.sahakarMoney, greaterThanOrEqualTo(least));
      expect(sample.sahakarMoney, lessThanOrEqualTo(most));
    });

    test('no plan activated means no Sahakar money', () {
      // There is nothing for a commission to be a share of.
      const none = ReferralProgress(directReferrals: 9);
      expect(none.plansActivated, 0);
      expect(none.sahakarMoney, 0);
    });

    test('plans activated is reported, and never clears a rung', () {
      // A referral who buys a card counts for more, but the ladder is still
      // climbed on referrals alone: the same three referrals stand on the
      // same rung whether none of them activated a plan or all of them did.
      const none = ReferralProgress(directReferrals: 3);
      const all = ReferralProgress(directReferrals: 3, plansActivated: 3);

      expect(none.plansActivated, 0);
      expect(all.plansActivated, 3);
      expect(all.currentLevel(levels), none.currentLevel(levels));
      expect(
        ReferralLadder.pointsEarnedBy(all),
        ReferralLadder.pointsEarnedBy(none),
      );

      // A plan can only be activated by somebody who was referred first.
      expect(
        ReferralLadder.sampleProgress.plansActivated,
        lessThanOrEqualTo(ReferralLadder.sampleProgress.directReferrals),
      );
    });

    test('a plan activated by an invite pays 2% back', () {
      expect(ReferralLadder.planCommissionPercent, 2);

      // Exact on every published load — no fraction of a percent inherited
      // from a binary rate.
      for (final tier in PrivilegeProgramme.tiers) {
        for (final amount in tier.amounts) {
          expect(
            ReferralLadder.planCommissionOn(amount),
            amount * 2 ~/ 100,
            reason: '₹$amount',
          );
        }
      }

      expect(ReferralLadder.planCommissionOn(10000), 200);
      expect(ReferralLadder.planCommissionOn(50000), 1000);
      expect(ReferralLadder.planCommissionOn(100000), 2000);
      expect(ReferralLadder.planCommissionLabel(100000), '₹2,000');

      expect(ReferralLadder.planCommissionOn(0), 0);
      expect(ReferralLadder.planCommissionOn(-10000), 0);
    });

    test('the commission never overstates itself', () {
      // Truncating, like the programme's own bonus: a hundred times the
      // commission can never exceed two hundred times the load.
      for (var amount = 1; amount <= 100000; amount += 137) {
        final paid = ReferralLadder.planCommissionOn(amount);
        expect(paid * 100, lessThanOrEqualTo(amount * 2), reason: '₹$amount');
      }
    });

    test('the rung a member is standing on', () {
      const nothing = ReferralProgress(directReferrals: 0);
      // Nothing cleared, so the rung shown is the one being worked towards
      // rather than no rung at all.
      expect(ReferralLadder.standingFor(nothing).name, 'Starter');
      // Three referrals clears Starter's two and no more.
      expect(
        ReferralLadder.standingFor(ReferralLadder.sampleProgress).name,
        'Starter',
      );

      const maxed = ReferralProgress(directReferrals: 99);
      expect(ReferralLadder.standingFor(maxed).name, 'Legend');
    });

    test('clearing the whole ladder pays the sum of its rungs', () {
      const maxed = ReferralProgress(directReferrals: 99);
      expect(ReferralLadder.pointsEarnedBy(maxed), ReferralLadder.totalPoints);
      expect(ReferralLadder.totalPoints, 100 + 200 + 500 + 1500 + 3000);
      expect(ReferralLadder.totalPointsLabel, '5,300 points');
    });
  });

  group('level rules', () {
    test('a level needs referrals, and only referrals', () {
      const level2 = ReferralLevel(
        level: 2,
        name: 'Riser',
        referralsRequired: 2,
        points: 200,
        accent: Color(0xFF2F8F7A),
        tint: Color(0xFFE3F2EE),
      );

      expect(
        const ReferralProgress(directReferrals: 1).isLevelCleared(level2),
        isFalse,
      );
      expect(
        const ReferralProgress(directReferrals: 2).isLevelCleared(level2),
        isTrue,
      );
      expect(
        const ReferralProgress(directReferrals: 3).isLevelCleared(level2),
        isTrue,
      );
    });

    test('current level is the highest consecutively cleared level', () {
      const nothing = ReferralProgress(directReferrals: 0);
      expect(nothing.currentLevel(levels), 0);

      // One short of Starter's two.
      expect(
        const ReferralProgress(directReferrals: 1).currentLevel(levels),
        0,
      );
      // Starter's two exactly.
      expect(
        const ReferralProgress(directReferrals: 2).currentLevel(levels),
        1,
      );
      // Three clears Starter and is short of Riser's five.
      expect(
        const ReferralProgress(directReferrals: 3).currentLevel(levels),
        1,
      );
      expect(
        const ReferralProgress(directReferrals: 5).currentLevel(levels),
        2,
      );
      expect(
        const ReferralProgress(directReferrals: 40).currentLevel(levels),
        5,
      );
    });

    test('the rungs clear in order, because each asks for more', () {
      // Every rung asks for strictly more referrals than the one below, so
      // clearing one implies clearing all beneath it and the ladder can never
      // report a gap.
      for (var referrals = 0; referrals <= 45; referrals++) {
        final progress = ReferralProgress(directReferrals: referrals);
        final cleared = progress.currentLevel(levels);
        for (final level in levels) {
          expect(
            progress.isLevelCleared(level),
            level.level <= cleared,
            reason: '$referrals referrals, level ${level.level}',
          );
        }
      }
    });

    test('next level is the first uncleared one', () {
      const three = ReferralProgress(directReferrals: 3);
      expect(three.nextLevel(levels)?.level, 2);

      const maxed = ReferralProgress(directReferrals: 99);
      expect(maxed.nextLevel(levels), isNull);
    });

    test('progress towards a level is clamped to 0..1', () {
      const over = ReferralProgress(directReferrals: 99);
      expect(over.progressTowards(levels[0], levels), 1.0);

      const none = ReferralProgress(directReferrals: 0);
      expect(none.progressTowards(levels[4], levels), 0.0);
    });
  });

  group('what a rung asks for in words', () {
    test('a rung counts only the members it adds to the one below', () {
      // Level 3 wants ten in total and level 2 already asked for five, so the
      // work left standing on level 2 is five more, not ten.
      expect(ReferralLadder.newMembersFor(levels[0]), 2);
      expect(ReferralLadder.newMembersFor(levels[1]), 3);
      expect(ReferralLadder.newMembersFor(levels[2]), 5);
      expect(ReferralLadder.newMembersFor(levels[3]), 10);
      expect(ReferralLadder.newMembersFor(levels[4]), 20);

      // Which is the ladder's own totals, taken a rung at a time.
      var running = 0;
      for (final level in levels) {
        running += ReferralLadder.newMembersFor(level);
        expect(running, level.referralsRequired, reason: level.name);
      }
    });

    test('every rung says what it pays for, in its own numbers', () {
      for (final level in levels) {
        final line = ReferralLadder.howItWorks(level);

        expect(line, contains('${level.referralsRequired} friends'));
        expect(line, contains('transaction'));
        expect(line, contains('invite link'));
        expect(
          line,
          contains(level.pointsLabel),
          reason: 'level ${level.level} must name its own reward',
        );
      }
    });

    test('every rung spells out the three steps a referral passes', () {
      for (final level in levels) {
        final steps = ReferralLadder.stepsFor(level);

        expect(steps, hasLength(3), reason: level.name);
        // Share, register, transact — in that order, because a referral that
        // skips one does not count.
        expect(steps[0], contains('invite link'));
        expect(steps[1], contains('registration'));
        expect(steps[2], contains('transaction'));
      }
    });

    test('the steps are the rungs own, not one paragraph five times', () {
      final wording = levels.map(ReferralLadder.stepsFor).toList();

      // No two rungs read the same, because no two ask for the same numbers.
      expect(wording.map((steps) => steps.join()).toSet(), hasLength(5));

      // The first rung asks outright; the ones above it ask for more on top.
      expect(wording.first.first, 'Share your invite link with 2 friends');
      expect(wording.first.last, 'Each one makes their first transaction');
      expect(wording[1].first, 'Share your invite link with 3 more friends');
      expect(wording[1].last, 'Each one makes a transaction — 5 in all');
      expect(wording.last.first, 'Share your invite link with 20 more friends');
      expect(wording.last.last, 'Each one makes a transaction — 40 in all');
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
      expect(find.text('Level 1 - Starter'), findsWidgets);
      expect(find.text('1 of 5'), findsOneWidget);

      // All five rungs are drawn, each named on its own card.
      for (final level in levels) {
        expect(
          find.text(level.name),
          findsWidgets,
          reason: 'level ${level.level} card should render',
        );
      }
      expect(find.textContaining('Earn 100 points'), findsOneWidget);
      expect(find.textContaining('Earn 3,000 points'), findsOneWidget);
      // No rung is priced in rupees any more — the ladder pays points.
      expect(find.textContaining('Earn ₹'), findsNothing);
    });

    /// Opens every rung's rules, which the cards keep folded away.
    Future<void> openEveryRung(WidgetTester tester) async {
      for (final level in levels) {
        await tester.tap(find.byKey(ValueKey('level-card-${level.level}')));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('a rung keeps its rules folded until the arrow is tapped', (
      tester,
    ) async {
      await pumpScreen(tester);

      final starter = levels.first;
      final rules = find.text(ReferralLadder.howItWorks(starter));

      // Every rung carries an arrow, and nothing behind it is on screen yet.
      for (final level in levels) {
        expect(
          find.byKey(ValueKey('level-details-arrow-${level.level}')),
          findsOneWidget,
          reason: level.name,
        );
        expect(
          find.text(ReferralLadder.howItWorks(level)),
          findsNothing,
          reason: level.name,
        );
      }
      // What the rung is and what it pays stay on the card regardless.
      expect(find.text(starter.name), findsWidgets);
      expect(find.textContaining('Earn ${starter.pointsLabel}'), findsWidgets);

      await tester.tap(find.byKey(ValueKey('level-card-${starter.level}')));
      await tester.pumpAndSettle();

      expect(rules, findsOneWidget);
      // Opening one rung leaves the rest folded.
      expect(find.text(ReferralLadder.howItWorks(levels[1])), findsNothing);

      await tester.tap(find.byKey(ValueKey('level-card-${starter.level}')));
      await tester.pumpAndSettle();

      expect(rules, findsNothing);
    });

    testWidgets('every rung carries its own rules, spelled out', (
      tester,
    ) async {
      await pumpScreen(tester, size: const Size(400, 3400));
      await openEveryRung(tester);

      for (final level in levels) {
        // Scoped to the rung's own card: the middle step reads the same on
        // every rung, so counting across the whole map would prove nothing
        // about where it is written.
        final card = find.byKey(ValueKey('level-card-${level.level}'));

        expect(
          find.descendant(
            of: card,
            matching: find.text(ReferralLadder.howItWorks(level)),
          ),
          findsOneWidget,
          reason: '${level.name} should say what it pays for',
        );

        final steps = ReferralLadder.stepsFor(level);
        for (final step in steps) {
          expect(
            find.descendant(of: card, matching: find.text(step)),
            findsOneWidget,
            reason: '${level.name}: $step',
          );
        }

        // Numbered, not bulleted: three steps, in order, on every card.
        for (final number in ['1', '2', '3']) {
          expect(
            find.descendant(of: card, matching: find.text(number)),
            findsOneWidget,
            reason: '${level.name}: step $number',
          );
        }
      }
    });

    testWidgets('the standing card keeps the journey detail below it', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Your journey'), findsOneWidget);
      expect(find.text('Where you are on the ladder'), findsNothing);
    });

    testWidgets('the standing card reports four figures, not three', (
      tester,
    ) async {
      await pumpScreen(tester);

      // Read across: what the invites brought in on the top row, what that
      // has paid on the bottom.
      //
      // Every rung down the journey map carries a 'Referred' bar of its own,
      // so the card's is one more than those rather than the only one.
      expect(
        find.descendant(
          of: find.byType(JourneyMap),
          matching: find.text('Referred'),
        ),
        findsNWidgets(levels.length),
      );
      expect(find.text('Referred'), findsNWidgets(levels.length + 1));
      expect(find.text('Plans activated'), findsOneWidget);
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('Sahakar money earned'), findsOneWidget);

      // The cash ladder's two are gone: 'Levels' said nothing the badge above
      // it did not already say, and 'Earned' was a rupee figure the ladder no
      // longer pays.
      expect(find.text('Levels'), findsNothing);
      expect(find.text('Earned'), findsNothing);

      // Sample standing: three referred, two of them on a plan. One rung
      // cleared pays 100 points; the two activations paid ₹1,000 between
      // them, which is a figure the fixture carries rather than one derived
      // from the points beside it.
      //
      // '100' shows twice: the Points figure, and the level-1 mark on the
      // reward graph's axis a little below it.
      expect(
        find.descendant(
          of: find.byType(RewardGraph),
          matching: find.text('100'),
        ),
        findsOneWidget,
      );
      expect(find.text('100'), findsNWidgets(2));
      expect(find.text('₹1,000'), findsWidgets);
    });

    testWidgets('the standing card is solid colour and compact', (
      tester,
    ) async {
      await pumpScreen(tester);

      final cardFinder = find.byKey(const ValueKey('standing-card'));
      final card = tester.widget<Container>(cardFinder);
      final decoration = card.decoration! as BoxDecoration;

      expect(decoration.gradient, isNull);
      expect(decoration.color, AppColors.brandBlueDeep);
      // Four figures, the reward graph, and the line to the next level — the
      // card carries the whole standing without scrolling.
      expect(tester.getSize(cardFinder).height, lessThan(440));
    });

    testWidgets('the figures follow the progress they are given', (
      tester,
    ) async {
      // Nothing cleared pays nothing, and a member who has referred nobody
      // cannot have anybody on a plan.
      await pumpScreen(
        tester,
        progress: const ReferralProgress(directReferrals: 0),
      );

      expect(find.text('0'), findsWidgets);
      expect(find.text('₹0'), findsOneWidget);

      // Two rungs cleared is 100 + 200 points. The money is its own figure
      // and moves independently of them.
      await pumpScreen(
        tester,
        progress: const ReferralProgress(
          directReferrals: 6,
          plansActivated: 4,
          sahakarMoney: 2600,
        ),
      );

      expect(find.text('300'), findsOneWidget);
      expect(find.text('₹2,600'), findsWidgets);
      expect(find.text('6'), findsWidgets);
      expect(find.text('4'), findsWidgets);
    });

    /// Opens the commission card, which sits folded to its headline.
    Future<void> openCommission(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('commission-card')));
      await tester.pumpAndSettle();
    }

    testWidgets('the commission card is folded to its rate until asked', (
      tester,
    ) async {
      await pumpScreen(tester);

      // The rate is the part worth seeing every visit.
      expect(find.text('2% on every plan they activate'), findsOneWidget);
      expect(find.text('Paid on top of your level points'), findsOneWidget);
      expect(find.byKey(const ValueKey('commission-arrow')), findsOneWidget);

      // The arithmetic behind it is not, until the arrow is turned over.
      expect(find.text('₹200 – ₹600'), findsNothing);
      expect(
        find.textContaining('2% of what they load comes back to you'),
        findsNothing,
      );

      await openCommission(tester);

      expect(
        find.textContaining('2% of what they load comes back to you'),
        findsOneWidget,
      );

      // And it folds away again.
      await openCommission(tester);
      expect(find.text('₹200 – ₹600'), findsNothing);
      expect(find.text('2% on every plan they activate'), findsOneWidget);
    });

    testWidgets('the commission card sits under the standing card', (
      tester,
    ) async {
      await pumpScreen(tester);

      // Above the invite code, not down past the whole ladder: it explains
      // the "Plans activated" figure on the card right above it, and a rule
      // that explains a figure has to be within reach of it.
      final card = tester.getTopLeft(
        find.byKey(const ValueKey('commission-card')),
      );
      final code = tester.getTopLeft(find.text('Your invite code'));
      final journey = tester.getTopLeft(find.text('Your journey'));

      expect(card.dy, lessThan(code.dy));
      expect(card.dy, lessThan(journey.dy));
    });

    testWidgets('the opened card shows what each plan pays back', (
      tester,
    ) async {
      await pumpScreen(tester, size: const Size(400, 3200));
      await openCommission(tester);

      // One band per card, worked out from the programme's own amounts:
      // silver ₹10,000–₹30,000 pays ₹200–₹600, and so on up.
      expect(find.text('₹200 – ₹600'), findsOneWidget);
      expect(find.text('₹800 – ₹1,000'), findsOneWidget);
      expect(find.text('₹1,200 – ₹2,000'), findsOneWidget);
      for (final tier in PrivilegeProgramme.tiers) {
        expect(find.text(tier.name), findsOneWidget, reason: tier.name);
      }
    });

    testWidgets('the opened card is the rate and the bands, nothing more', (
      tester,
    ) async {
      await pumpScreen(tester, size: const Size(400, 3200));
      await openCommission(tester);

      // The standing — the "N of your M invites activated a plan" line, its
      // Sahakar-money pill and the caption under it — has been taken off this
      // card. Only the rule and the three bands remain.
      expect(find.textContaining('invites activated a plan'), findsNothing);
      expect(find.textContaining('earned so far from referred members'), findsNothing);
      expect(
        find.text('None of your invites has activated a plan yet'),
        findsNothing,
      );
    });

    testWidgets('a rung is badged as a rank, not as a plan card', (
      tester,
    ) async {
      await pumpScreen(tester);

      // The ladder used to draw a privilege card face on every rung, which
      // said a level was something you buy. It is a rank you earn.
      expect(
        find.descendant(
          of: find.byType(JourneyMap),
          matching: find.byType(PrivilegeCardFace),
        ),
        findsNothing,
      );

      for (final level in levels) {
        expect(
          find.descendant(
            of: find.byType(JourneyMap),
            matching: find.text('LVL ${level.level}'),
          ),
          findsOneWidget,
          reason: level.name,
        );
      }
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

      // One bar per rung and one only: a rung is gated on referrals, so
      // there is no second bar counting privilege cards any more.
      expect(inMap('Referred'), findsNWidgets(levels.length));
      for (final tier in PrivilegeProgramme.tiers) {
        expect(
          inMap(tier.name.split(' ').first),
          findsNothing,
          reason: tier.name,
        );
      }
      // Every rung is named and badged.
      for (final level in levels) {
        expect(inMap(level.name), findsOneWidget, reason: level.name);
        expect(inMap('LVL ${level.level}'), findsOneWidget, reason: level.name);
      }

      // Cleared levels cap the displayed figure at the requirement rather
      // than reporting a raw total such as 3/2.
      expect(find.text('2/2'), findsOneWidget);

      // Riser is in progress: 3 of the 5 it asks for.
      expect(find.text('3/5'), findsOneWidget);
      // And the rungs above it are untouched.
      expect(find.text('3/10'), findsOneWidget);
      expect(find.text('3/20'), findsOneWidget);
      expect(find.text('3/40'), findsOneWidget);

      // Starter cleared, Riser under way, and the three above it shut.
      expect(find.text('Cleared'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Locked'), findsNWidgets(3));
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
        progress: const ReferralProgress(directReferrals: 0),
      );

      expect(find.text('Not started'), findsOneWidget);
      expect(find.text('0 of 5'), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);
    });

    testWidgets('narrow viewport lays out without overflow', (tester) async {
      await pumpScreen(tester, size: const Size(320, 2600));

      expect(find.text('Your journey'), findsOneWidget);
      expect(find.text('SHIELD-RN4821'), findsOneWidget);

      // The commission card carries the widest lines on the screen — a tier
      // name and a two-ended rupee range on one row — so it is opened here
      // too. An overflow paints an error banner and fails the test.
      await tester.tap(find.byKey(const ValueKey('commission-card')));
      await tester.pumpAndSettle();

      expect(find.text('₹1,200 – ₹2,000'), findsOneWidget);
      expect(find.text('Platinum Shield'), findsOneWidget);
    });

    testWidgets('folded, the card costs a headline of height', (tester) async {
      await pumpScreen(tester);

      final folded = tester
          .getSize(find.byKey(const ValueKey('commission-card')))
          .height;

      await tester.tap(find.byKey(const ValueKey('commission-card')));
      await tester.pumpAndSettle();

      final opened = tester
          .getSize(find.byKey(const ValueKey('commission-card')))
          .height;

      // Folded it is a header and its padding, and nothing else — the rate,
      // its one-line gloss, and the arrow. Small enough that dropping it
      // above the invite code costs the ladder almost nothing, where open it
      // is a screen's worth of bands.
      expect(folded, lessThan(120));
      expect(opened, greaterThan(folded * 2));
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
