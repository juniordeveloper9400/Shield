import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/auth/login_screen.dart';
import 'package:shield/module/privilege/privilege_card.dart';
import 'package:shield/module/privilege/privilege_card_face.dart';
import 'package:shield/module/privilege/privilege_screen.dart';
import 'package:shield/module/privilege/privilege_wallet.dart';
import 'package:shield/module/privilege/privilege_tier.dart';
import 'package:shield/module/registration/registration_service.dart';
import 'package:shield/module/registration/shield_store.dart';
import 'package:shield/module/wallet/wallet_flip_card.dart';
import 'package:shield/module/wallet/wallet_screen.dart';
import 'package:shield/module/wallet/wallet_service.dart';
import 'package:shield/screens/home_screen.dart';
import 'package:shield/theme/app_colors.dart';

void main() {
  setUp(() {
    WalletService.instance.reset();
    AuthService.instance.reset();
    RegistrationService.instance.reset();
  });
  tearDown(() {
    WalletService.instance.reset();
    AuthService.instance.reset();
    RegistrationService.instance.reset();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(400, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  /// The activation guard opens the auth dialog for a guest, so a test that
  /// wants to reach the wallet has to be signed in and registered first.
  void signIn() {
    AuthService.instance.signInAs();
    RegistrationService.instance.save(
      Registration(
        name: 'Asha Nair',
        phone: '9000012345',
        email: 'asha@example.com',
        gender: Gender.female,
        dob: DateTime(1995, 8, 20),
        address: '123 Test St',
        place: 'Kochi',
        pincode: '682001',
        state: 'Kerala',
        storeId: StoreDirectory.all.first.id,
      ),
    );
  }

  group('the programme rules', () {
    test('three cards, each carrying its own band of loads', () {
      expect(PrivilegeProgramme.tiers.map((tier) => tier.name), [
        'Silver Shield',
        'Gold Shield',
        'Platinum Shield',
      ]);
      expect(PrivilegeProgramme.tiers.map((tier) => tier.amounts), [
        [10000, 20000, 30000],
        [40000, 50000],
        [60000, 70000, 80000, 90000, 100000],
      ]);
    });

    test('the bands ascend, never overlap, and leave no gap', () {
      final published = [
        for (final tier in PrivilegeProgramme.tiers) ...tier.amounts,
      ];

      // Ascending, and no amount on two cards — which is what lets the
      // screen drop its free-entry amount box entirely.
      expect(published, orderedEquals(List.of(published)..sort()));
      expect(published.toSet(), hasLength(published.length));
      expect(PrivilegeProgramme.minAmount, 10000);
      expect(PrivilegeProgramme.maxAmount, 100000);

      // Contiguous in whole steps from ₹10,000 to ₹1,00,000. ₹60,000 used
      // to fall in a hole between gold and platinum; it is platinum's entry
      // load now, so there is no amount in the range no card is issued for.
      // Pinned here rather than left to be discovered, because a hole in the
      // ladder would be a decision, not an oversight.
      expect(published, [
        for (var amount = 10000; amount <= 100000; amount += 10000) amount,
      ]);
      expect(PrivilegeProgramme.loadFor(60000), isNotNull);
    });

    test('the bonus is 10% of the load, on every card', () {
      final silver = PrivilegeProgramme.tiers.first.entry;
      expect(silver.amount, 10000);
      expect(silver.bonus, 1000);
      expect(silver.credited, 11000);

      for (final tier in PrivilegeProgramme.tiers) {
        for (final load in tier.loads) {
          expect(load.bonus, load.amount ~/ 10, reason: load.amountLabel);
          expect(load.credited, load.amount + load.bonus);
        }
      }
    });

    test('a card says what it covers month by month', () {
      // A card is a year of medicine bought up front, so what it carries comes
      // due a twelfth at a time. ₹10,000 loads ₹11,000, which is ₹916 a month
      // — the figure a member can hold against the bill they already pay.
      final silver = PrivilegeProgramme.tiers.first.entry;
      expect(silver.credited, 11000);
      expect(silver.monthlyCoverage, 916);
      expect(silver.monthlyCoverageLabel, '₹916');

      for (final tier in PrivilegeProgramme.tiers) {
        for (final load in tier.loads) {
          // Twelve of them never add up to more than the card carries, and
          // fall short by less than a rupee a month — which is what the
          // "about" on the screen is covering.
          final year = load.monthlyCoverage * PrivilegeProgramme.validityMonths;
          expect(
            year,
            lessThanOrEqualTo(load.credited),
            reason: load.amountLabel,
          );
          expect(
            load.credited - year,
            lessThan(PrivilegeProgramme.validityMonths),
            reason: load.amountLabel,
          );

          // And it is the very twelfth the wallet will release, not a second
          // rounding of the same sum.
          expect(
            WalletCard(
              load: load,
              issuedOn: DateTime(2026, 1, 1),
              rechargedOn: DateTime(2026, 1, 1),
            ).monthlyRedeemable,
            load.monthlyCoverage,
            reason: load.amountLabel,
          );
        }
      }
    });

    test('a card entered at its smallest load', () {
      expect(PrivilegeProgramme.tiers[1].entry.amount, 40000);
      expect(PrivilegeProgramme.tiers[2].entry.amount, 60000);
      expect(PrivilegeProgramme.tiers[2].rangeLabel, '₹60,000 – ₹1,00,000');
    });

    test('the bonus rounds down, never up', () {
      // Not reachable through the UI, which only allows multiples of 10,000,
      // but a promise must never be overstated by a rounding rule.
      expect(PrivilegeProgramme.bonusOn(10009), 1000);
      expect(PrivilegeProgramme.bonusOn(0), 0);
      expect(PrivilegeProgramme.bonusOn(-5000), 0);
    });

    test('only a published load is valid', () {
      expect(PrivilegeProgramme.isValidAmount(10000), isTrue);
      expect(PrivilegeProgramme.isValidAmount(70000), isTrue);
      expect(PrivilegeProgramme.isValidAmount(100000), isTrue);
      expect(PrivilegeProgramme.isValidAmount(9999), isFalse);
      expect(PrivilegeProgramme.isValidAmount(15000), isFalse);
      expect(PrivilegeProgramme.isValidAmount(0), isFalse);
      // Past the top card. The programme stops at a lakh rather than running
      // on into amounts no card is issued for.
      expect(PrivilegeProgramme.isValidAmount(110000), isFalse);
    });

    test('an amount says which card it is issued as', () {
      expect(PrivilegeProgramme.tierFor(20000)?.name, 'Silver Shield');
      expect(PrivilegeProgramme.tierFor(50000)?.name, 'Gold Shield');
      expect(PrivilegeProgramme.tierFor(100000)?.name, 'Platinum Shield');
      expect(PrivilegeProgramme.tierFor(15000), isNull);

      final top = PrivilegeProgramme.loadFor(100000)!;
      expect(top.name, 'Platinum Shield');
      expect(top.bonus, 10000);
      expect(top.credited, 110000);
      expect(PrivilegeProgramme.loadFor(15000), isNull);
    });

    test('every card owns a colour, and no two share one', () {
      final accents = PrivilegeProgramme.tiers
          .map((tier) => tier.accent)
          .toSet();
      final tints = PrivilegeProgramme.tiers.map((tier) => tier.tint).toSet();

      expect(accents, hasLength(3));
      expect(tints, hasLength(3));

      // Every load on a card wears that card's colour, so the face, the
      // amount row and the activate bar can never disagree.
      for (final tier in PrivilegeProgramme.tiers) {
        for (final load in tier.loads) {
          expect(load.accent, tier.accent, reason: load.amountLabel);
          expect(load.tint, tier.tint, reason: load.amountLabel);
        }
      }
    });

    test('labels are grouped the Indian way', () {
      final top = PrivilegeProgramme.tiers.last.loads.last;
      expect(top.amountLabel, '₹1,00,000');
      expect(top.bonusLabel, '₹10,000');
      expect(top.creditedLabel, '₹1,10,000');
    });
  });

  group('the wallet', () {
    /// Opens the wallet the only way it can be opened.
    void activateSilver() {
      WalletService.instance.activate(PrivilegeProgramme.silver.entry);
    }

    test('a wallet is closed until a card opens it', () {
      expect(WalletService.instance.isActivated, isFalse);
      expect(WalletService.instance.card, isNull);

      activateSilver();

      expect(WalletService.instance.isActivated, isTrue);
      expect(WalletService.instance.card, PrivilegeProgramme.silver.entry);
    });

    test('activation posts two lines, not one', () {
      activateSilver();

      expect(
        WalletService.instance.balance,
        WalletService.openingBalance + 11000,
      );

      final entries = WalletService.instance.entries;
      expect(entries[0].label, 'Silver Shield bonus · 10%');
      expect(entries[0].amount, 1000);
      expect(entries[1].label, 'Silver Shield activation');
      expect(entries[1].amount, 10000);
    });

    test('a wallet holds nothing but what a plan put in it', () {
      // It used to open at ₹3,472 against five invented transactions — an
      // order, a top-up, a referral reward, a cashback — none of which any
      // member had done. A wallet is opened by a plan and filled by that plan.
      expect(WalletService.instance.balance, 0);
      expect(WalletService.instance.entries, isEmpty);
      expect(WalletService.instance.rewardPoints, 0);

      activateSilver();

      // Two lines, both the plan's, and nothing underneath them.
      final entries = WalletService.instance.entries;
      expect(entries, hasLength(2));
      expect(
        entries.map((entry) => entry.label),
        ['Silver Shield bonus · 10%', 'Silver Shield activation'],
      );
      expect(WalletService.instance.balance, 11000);

      // And the balance is exactly the plan, not the plan on top of a figure
      // that came from nowhere.
      expect(
        WalletService.instance.balance,
        PrivilegeProgramme.silver.entry.credited,
      );
    });

    test('nothing can be added to a closed wallet', () {
      final before = WalletService.instance.balance;
      final entries = WalletService.instance.entries.length;

      expect(WalletService.instance.topUp(amount: 500), isFalse);
      expect(WalletService.instance.redeemPoints(), isFalse);

      // Not merely hidden in the UI: the service refuses, so no other path
      // into it can move money either.
      expect(WalletService.instance.balance, before);
      expect(WalletService.instance.entries.length, entries);
      expect(
        WalletService.instance.rewardPoints,
        WalletService.openingRewardPoints,
      );
    });

    test('a top-up with no bonus posts one line, once the wallet is open', () {
      activateSilver();
      final before = WalletService.instance.entries.length;
      final balance = WalletService.instance.balance;

      expect(WalletService.instance.topUp(amount: 500), isTrue);
      expect(WalletService.instance.entries.length, before + 1);
      expect(WalletService.instance.balance, balance + 500);
    });

    test('a non-positive top-up is refused', () {
      activateSilver();
      final before = WalletService.instance.balance;

      expect(WalletService.instance.topUp(amount: 0), isFalse);
      expect(WalletService.instance.topUp(amount: -100), isFalse);
      expect(WalletService.instance.balance, before);
    });

    test('activating a different card issues a second one alongside it', () {
      activateSilver();
      final afterSilver = WalletService.instance.balance;

      final gold = PrivilegeProgramme.gold.entry;
      WalletService.instance.activate(gold);

      // The card in hand is the new one, and the old one is still on the
      // account rather than having been thrown away with its remaining
      // credit.
      expect(WalletService.instance.card, gold);
      expect(WalletService.instance.balance, afterSilver + gold.credited);
      expect(WalletService.instance.cards.map((card) => card.load), [
        PrivilegeProgramme.silver.entry,
        gold,
      ]);
    });

    test('activating the same card again recharges it', () {
      activateSilver();
      final silver = PrivilegeProgramme.silver.entry;
      WalletService.instance.activate(silver);

      expect(WalletService.instance.cards, hasLength(1));
      // Issued with 11,000 and recharged with another 11,000.
      expect(WalletService.instance.cards.single.loaded, 22000);
    });

    test('a card runs for a year from the day it was issued', () {
      WalletService.instance.activate(
        PrivilegeProgramme.silver.entry,
        on: DateTime(2026, 8, 22),
      );

      final card = WalletService.instance.cards.single;
      expect(card.rechargedOnLabel, '22 Aug 2026');
      expect(card.expiresOnLabel, '22 Aug 2027');
    });

    test('a top-up recharges the card in hand', () {
      WalletService.instance.activate(
        PrivilegeProgramme.silver.entry,
        on: DateTime(2026, 8, 22),
      );
      WalletService.instance.topUp(amount: 2000, on: DateTime(2026, 9, 4));

      final card = WalletService.instance.cards.single;
      expect(card.loaded, 13000);
      expect(card.rechargedOnLabel, '04 Sep 2026');
      // Recharging does not push the expiry out: validity runs from issue.
      expect(card.expiresOnLabel, '22 Aug 2027');
    });

    test('a twelfth of what is on the cards comes due each month', () {
      WalletService.instance.activate(PrivilegeProgramme.silver.entry);
      // 11,000 over twelve months.
      expect(WalletService.instance.monthlyRedeemable, 916);
      expect(WalletService.instance.redeemedThisMonth, 0);
      expect(WalletService.instance.monthlyBalance, 916);

      WalletService.instance.activate(PrivilegeProgramme.gold.entry);
      // And 44,000 on top, pooled: 916 + 3,666.
      expect(WalletService.instance.monthlyRedeemable, 4582);
    });

    test('spending draws on this month\'s allowance', () {
      activateSilver();
      final balance = WalletService.instance.balance;

      expect(
        WalletService.instance.spend(amount: 400, label: 'Order SHD-100500'),
        isTrue,
      );
      expect(WalletService.instance.balance, balance - 400);
      expect(WalletService.instance.redeemedThisMonth, 400);
      expect(WalletService.instance.monthlyBalance, 516);
      expect(WalletService.instance.entries.first.amount, -400);
    });

    test('the wallet cannot be overdrawn, or spent while closed', () {
      expect(
        WalletService.instance.spend(amount: 100, label: 'Order'),
        isFalse,
        reason: 'a closed wallet holds no money to spend',
      );

      activateSilver();
      final balance = WalletService.instance.balance;
      expect(
        WalletService.instance.spend(amount: balance + 1, label: 'Order'),
        isFalse,
      );
      expect(WalletService.instance.balance, balance);
      expect(WalletService.instance.redeemedThisMonth, 0);
    });

    test('the monthly balance never goes negative', () {
      activateSilver();
      // Well past the 916 that comes due this month.
      WalletService.instance.spend(amount: 5000, label: 'Order');

      expect(WalletService.instance.redeemedThisMonth, 5000);
      expect(WalletService.instance.monthlyBalance, 0);
    });
  });

  group('when a plan comes due', () {
    WalletCard cardOn(DateTime issued, {int amount = 10000}) => WalletCard(
      load: PrivilegeProgramme.loadFor(amount)!,
      issuedOn: issued,
      rechargedOn: issued,
    );

    test('a plan comes due on the day of the month it was taken', () {
      // The case the whole thing is built around: a plan taken on the 10th
      // and one taken on the 25th do not come round together, so an account
      // holding both cannot draw on them both at once.
      final tenth = cardOn(DateTime(2026, 8, 10));
      final twentyFifth = cardOn(DateTime(2026, 8, 25));

      expect(tenth.cycleDay, 10);
      expect(twentyFifth.cycleDay, 25);

      // On the 24th of the following month the first has come round and the
      // second has not.
      final on24Sep = DateTime(2026, 9, 24);
      expect(tenth.isActiveOn(on24Sep), isTrue);
      expect(twentyFifth.isActiveOn(on24Sep), isFalse);
      expect(twentyFifth.dueDayIn(on24Sep), DateTime(2026, 9, 25));

      // And on the 25th it opens, on the same day of the month it was taken.
      expect(twentyFifth.isActiveOn(DateTime(2026, 9, 25)), isTrue);
    });

    test('a plan stays on one instalment until its day comes round', () {
      final card = cardOn(DateTime(2026, 8, 25));

      expect(card.instalmentOn(DateTime(2026, 8, 25)), 1);
      expect(card.instalmentOn(DateTime(2026, 9, 24)), 1);
      expect(card.instalmentOn(DateTime(2026, 9, 25)), 2);
      expect(card.instalmentOn(DateTime(2027, 7, 25)), 12);
      // Never past the twelve it was issued for, whatever the date.
      expect(card.instalmentOn(DateTime(2030, 1, 1)), 12);
    });

    test('a plan taken on the 31st comes due on a short month\'s last day', () {
      final card = cardOn(DateTime(2026, 1, 31));

      // February 2026 has 28 days, so the plan comes due on the 28th rather
      // than slipping into March and skipping a month.
      expect(card.dueDayIn(DateTime(2026, 2, 15)), DateTime(2026, 2, 28));
      expect(card.isActiveOn(DateTime(2026, 2, 27)), isFalse);
      expect(card.isActiveOn(DateTime(2026, 2, 28)), isTrue);
    });

    test('what a plan has released, and what is still to come', () {
      final card = cardOn(DateTime(2026, 8, 10));

      expect(card.monthlyRedeemable, 916);
      expect(card.releasedBy(DateTime(2026, 8, 24)), 916);
      expect(card.remainingAfter(DateTime(2026, 8, 24)), 11000 - 916);

      // A year in, all twelve instalments have been let out.
      expect(card.instalmentOn(DateTime(2027, 7, 10)), 12);
      expect(card.releasedBy(DateTime(2027, 7, 10)), 916 * 12);
    });

    test('only the plans that have come round pool into the month', () {
      final wallet = WalletService.instance;
      wallet.activate(
        PrivilegeProgramme.loadFor(10000)!,
        on: DateTime(2026, 8, 10),
      );
      wallet.activate(
        PrivilegeProgramme.loadFor(40000)!,
        on: DateTime(2026, 8, 25),
      );

      expect(wallet.cards[0].monthlyRedeemable, 916);
      expect(wallet.cards[1].monthlyRedeemable, 3666);

      // On the 24th the account can draw only on the plan taken on the 10th.
      // This is the rule the wallet used to get wrong: it pooled every card
      // whatever its date, and offered a twelfth of the second plan a day
      // before that plan had come round.
      expect(wallet.monthlyRedeemableOn(DateTime(2026, 9, 24)), 916);
      expect(
        wallet.activeCardsOn(DateTime(2026, 9, 24)).map((card) => card.name),
        ['Silver Shield'],
      );
      expect(
        wallet.waitingCardsOn(DateTime(2026, 9, 24)).map((card) => card.name),
        ['Gold Shield'],
      );

      // On the 25th the second joins it and they pool.
      expect(wallet.monthlyRedeemableOn(DateTime(2026, 9, 25)), 916 + 3666);
      expect(wallet.waitingCardsOn(DateTime(2026, 9, 25)), isEmpty);
    });

    testWidgets('the back marks an open plan green and a waiting one red', (
      tester,
    ) async {
      final cards = [
        WalletCard(
          load: PrivilegeProgramme.loadFor(10000)!,
          issuedOn: DateTime(2026, 8, 10),
          rechargedOn: DateTime(2026, 8, 10),
        ),
        WalletCard(
          load: PrivilegeProgramme.loadFor(40000)!,
          issuedOn: DateTime(2026, 8, 25),
          rechargedOn: DateTime(2026, 8, 25),
        ),
      ];

      await pump(
        tester,
        Scaffold(
          body: WalletFlipCard(
            cards: cards,
            balance: 14472,
            monthlyRedeemable: 916,
            redeemed: 0,
            monthlyBalance: 916,
            asOf: DateTime(2026, 9, 24),
          ),
        ),
      );

      await tester.tap(find.byType(WalletFlipCard));
      await tester.pumpAndSettle();

      // Closed, the panel shows the one plan it has room for and says how
      // many more there are.
      expect(find.text('1 more plan'), findsOneWidget);

      await tester.tap(find.text('1 more plan'));
      await tester.pumpAndSettle();

      // One of each, and the date each one turns on — which for the waiting
      // plan is the only thing the member is actually waiting for.
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Waiting'), findsOneWidget);
      expect(find.text('Renews 10 Oct'), findsOneWidget);
      expect(find.text('Opens 25 Sep'), findsOneWidget);

      final active = tester.widget<Text>(find.text('Active'));
      final waiting = tester.widget<Text>(find.text('Waiting'));
      expect(active.style?.color, AppColors.planActive);
      expect(waiting.style?.color, AppColors.planWaiting);
    });

    testWidgets('the back turns itself to the release page', (tester) async {
      final cards = [
        WalletCard(
          load: PrivilegeProgramme.loadFor(10000)!,
          issuedOn: DateTime(2026, 8, 10),
          rechargedOn: DateTime(2026, 8, 10),
        ),
      ];

      await pump(
        tester,
        Scaffold(
          body: WalletFlipCard(
            cards: cards,
            balance: 14472,
            monthlyRedeemable: 916,
            redeemed: 0,
            monthlyBalance: 916,
            asOf: DateTime(2026, 9, 24),
          ),
        ),
      );

      await tester.tap(find.byType(WalletFlipCard));
      await tester.pumpAndSettle();

      // It comes round on the plans, because that is what the front promised.
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller;
      expect(controller?.page, closeTo(0, 0.01));
      expect(find.text('Your plan'), findsOneWidget);

      // Then turns itself, so the second page is discovered rather than left
      // behind a swipe nobody knew to make.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(controller?.page, closeTo(1, 0.01));
      expect(find.text('Monthly release'), findsOneWidget);
      // Taken on 10 Aug and read on 24 Sep: the second twelfth is out.
      expect(find.text('2 of 12 released'), findsOneWidget);
      expect(find.text('₹916 / month'), findsOneWidget);
    });
  });

  group('the home card', () {
    testWidgets('sits under the banner and names the programme', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(body: HomeScreen()),
        size: const Size(400, 4200),
      );

      expect(find.byType(PrivilegeCard), findsOneWidget);
      expect(find.text('Activate your Privilege Programme'), findsOneWidget);
    });

    testWidgets('opens the programme', (tester) async {
      await pump(
        tester,
        const Scaffold(body: HomeScreen()),
        size: const Size(400, 4200),
      );

      await tester.tap(find.text('Activate your Privilege Programme'));
      await tester.pumpAndSettle();

      expect(find.byType(PrivilegeScreen), findsOneWidget);
    });

    testWidgets('stands down once a plan is active', (tester) async {
      // A plan is already active, so the call to activate has nothing to ask
      // for and takes no room on the feed.
      WalletService.instance.activate(PrivilegeProgramme.silver.entry);

      await pump(
        tester,
        const Scaffold(body: HomeScreen()),
        size: const Size(400, 4200),
      );

      expect(find.text('Activate your Privilege Programme'), findsNothing);
      expect(find.byType(PrivilegeWallet), findsNothing);
    });
  });

  group('the programme screen', () {
    testWidgets('opens on the cards, with only that card\'s loads below', (
      tester,
    ) async {
      await pump(tester, const PrivilegeScreen());

      final silver = PrivilegeProgramme.tiers.first;
      expect(find.text(silver.name), findsOneWidget);
      expect(find.text(silver.rangeLabel), findsOneWidget);

      // Silver's three loads, each with its bonus and what it credits. The
      // entry load is written on the card face as well, so these are counted
      // as "at least one" rather than exactly one.
      for (final load in silver.loads) {
        expect(find.text(load.amountLabel), findsWidgets, reason: load.name);
        expect(
          find.text('+ ${load.bonusLabel} free'),
          findsOneWidget,
          reason: load.amountLabel,
        );
        expect(
          find.text(load.creditedLabel),
          findsWidgets,
          reason: load.amountLabel,
        );
      }

      // And no other card's loads: the panel belongs to the card above it,
      // not to the programme. The gold face is still built as the next page
      // of the carousel, so it is the amount rows that must be absent.
      expect(find.text(PrivilegeProgramme.tiers[1].name), findsNothing);
      expect(find.text('+ ₹4,000 free'), findsNothing);
      // The old tier list and free-entry amount box are gone with it.
      expect(find.text('Choose your card'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the panel is washed in the card\'s own colour', (
      tester,
    ) async {
      await pump(tester, const PrivilegeScreen());

      final silver = PrivilegeProgramme.tiers.first;
      final washed = find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == silver.tint,
      );
      expect(washed, findsOneWidget);

      // The chosen load fills in with the accent itself. The amount appears
      // on the card face too, and the panel row is the later of the two.
      await tester.tap(find.text('₹20,000').last);
      await tester.pumpAndSettle();

      // Twice: the row itself, and the activate bar, which wears the colour
      // of what is about to be activated.
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Material && widget.color == silver.accent,
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('Activate is disabled until a card is picked', (tester) async {
      await pump(tester, const PrivilegeScreen());

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('Pick a card'), findsOneWidget);

      await tester.tap(find.text('₹30,000').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(find.text('You pay ₹30,000'), findsOneWidget);
      expect(find.text('₹33,000'), findsWidgets);
    });

    testWidgets('the chosen load says what it covers a month', (tester) async {
      await pump(tester, const PrivilegeScreen());

      // Nothing is chosen on opening, so no row is claiming a monthly figure.
      expect(find.textContaining('a month for 12 months'), findsNothing);

      await tester.tap(find.text('₹10,000').last);
      await tester.pumpAndSettle();

      // ₹10,000 credits ₹11,000 across the year the card is live for.
      expect(
        find.text('Covers about ₹916 of bills a month for 12 months'),
        findsOneWidget,
      );

      // It belongs to the row chosen rather than to the panel, so picking
      // another amount moves the line instead of printing a second one.
      await tester.tap(find.text('₹30,000').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('a month for 12 months'), findsOneWidget);
      expect(
        find.text('Covers about ₹2,750 of bills a month for 12 months'),
        findsOneWidget,
      );
      // ₹916 was ₹10,000's figure and belongs to no part of the screen now:
      // not the row's line, and not the benefits list under it either.
      expect(find.textContaining('₹916'), findsNothing);
    });

    testWidgets('switching card switches the loads under it', (tester) async {
      await pump(tester, const PrivilegeScreen());

      await tester.tap(find.bySemanticsLabel('Platinum Shield').last);
      await tester.pumpAndSettle();

      expect(find.text('Platinum Shield'), findsOneWidget);
      expect(find.text('₹60,000'), findsWidgets);
      expect(find.text('₹70,000'), findsWidgets);
      expect(find.text('₹1,00,000'), findsWidgets);
      expect(find.text('+ ₹10,000 free'), findsOneWidget);
      // Silver's rows have gone with silver.
      expect(find.text('+ ₹2,000 free'), findsNothing);
      // Landing on a card picks its smallest load, not its largest.
      expect(find.text('You pay ₹60,000'), findsOneWidget);
    });

    testWidgets('a load chosen on a card survives switching away and back', (
      tester,
    ) async {
      await pump(tester, const PrivilegeScreen());

      await tester.tap(find.text('₹30,000').last);
      await tester.pumpAndSettle();
      expect(find.text('You pay ₹30,000'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Gold Shield').last);
      await tester.pumpAndSettle();
      expect(find.text('You pay ₹40,000'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Silver Shield').last);
      await tester.pumpAndSettle();

      expect(find.text('You pay ₹30,000'), findsOneWidget);
    });

    testWidgets('activating credits the amount and the bonus', (tester) async {
      signIn();
      await pump(tester, const PrivilegeScreen());

      await tester.tap(find.text('₹10,000').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activate'));
      await tester.pumpAndSettle();

      expect(
        WalletService.instance.balance,
        WalletService.openingBalance + 11000,
      );
      expect(
        WalletService.instance.entries.first.label,
        'Silver Shield bonus · 10%',
      );
    });

    testWidgets('a guest is asked to sign in before any money moves', (
      tester,
    ) async {
      await pump(tester, const PrivilegeScreen());

      await tester.tap(find.text('₹10,000').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activate'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        WalletService.instance.balance,
        WalletService.openingBalance,
        reason: 'nothing may be credited before the account exists',
      );
    });
  });

  group('the wallet screen', () {
    /// The wallet only has anything to show once a card has opened it.
    void openWallet([PrivilegeLoad? load]) {
      WalletService.instance.activate(load ?? PrivilegeProgramme.silver.entry);
    }

    testWidgets('a closed wallet shows no figures and one way in', (
      tester,
    ) async {
      await pump(tester, const WalletScreen());

      expect(find.text('Wallet locked'), findsOneWidget);
      expect(find.text('₹ ••••••'), findsOneWidget);
      // The balance is masked, not merely absent from the panel.
      expect(find.text('₹3,472.00'), findsNothing);
      expect(find.text('₹0.00'), findsNothing);
      // Shield points are not part of this screen any more, masked or not.
      expect(find.textContaining('Shield Points'), findsNothing);
      expect(find.textContaining('Shield points'), findsNothing);

      // Twice: the button on the locked panel, and the heading of the offer
      // that replaces the rest of the screen.
      expect(find.text('Activate your Privilege Card'), findsNWidgets(2));
      // Nothing to move money with, and no ledger to read.
      expect(find.text('Add money'), findsNothing);
      expect(
        find.text('Spend the balance across the whole app'),
        findsOneWidget,
      );
      expect(find.text('Redeem points'), findsNothing);
      expect(find.text('Top up your Privilege Programme'), findsNothing);
      expect(find.text('Transaction history'), findsNothing);
      expect(find.text('Wallet top-up'), findsNothing);
    });

    testWidgets('the locked wallet opens the programme', (tester) async {
      await pump(tester, const WalletScreen());

      await tester.tap(find.text('Activate your Privilege Card').first);
      await tester.pumpAndSettle();

      expect(find.byType(PrivilegeScreen), findsOneWidget);
    });

    // The three ways into the programme from a shut wallet. Each one takes
    // the cards out of the pocket first, the way the home strip does — the
    // artwork included, since the cards are the obvious thing to tap.
    final triggers = <String, Finder Function()>{
      'the locked card button': () =>
          find.text('Activate your Privilege Card').first,
      'the panel button': () => find.text('See the cards'),
      'the cards themselves': () => find.byType(PrivilegeWallet),
    };

    triggers.forEach((name, trigger) {
      testWidgets('$name empties the wallet, then opens it', (tester) async {
        await pump(tester, const WalletScreen());

        Finder cards() => find.descendant(
          of: find.byType(PrivilegeWallet),
          matching: find.byType(PrivilegeCardFace),
        );
        final atRest = tester.getTopLeft(cards().first).dy;

        await tester.tap(trigger());
        // Part-way through the fan, before the programme has opened.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        expect(
          tester.getTopLeft(cards().first).dy,
          lessThan(atRest),
          reason: 'the back card should be on its way out of the pocket',
        );
        expect(find.byType(PrivilegeScreen), findsNothing);

        await tester.pumpAndSettle();
        expect(find.byType(PrivilegeScreen), findsOneWidget);
      });
    });

    testWidgets('coming back puts the wallet cards away again', (tester) async {
      await pump(tester, const WalletScreen());

      Finder cards() => find.descendant(
        of: find.byType(PrivilegeWallet),
        matching: find.byType(PrivilegeCardFace),
      );
      final atRest = tester.getTopLeft(cards().first).dy;

      await tester.tap(find.text('See the cards'));
      await tester.pumpAndSettle();
      expect(find.byType(PrivilegeScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(PrivilegeScreen), findsNothing);
      expect(tester.getTopLeft(cards().first).dy, atRest);
    });

    testWidgets('the locked wallet holds all three cards, in the pocket', (
      tester,
    ) async {
      await pump(tester, const WalletScreen());

      final faces = tester
          .widgetList<PrivilegeCardFace>(
            find.descendant(
              of: find.byType(PrivilegeWallet),
              matching: find.byType(PrivilegeCardFace),
            ),
          )
          .toList();

      // One card per tier, at its own entry load, in issue order — silver
      // furthest back and so highest, platinum in front.
      expect(faces, hasLength(PrivilegeProgramme.tiers.length));
      expect(
        faces.map((face) => face.load),
        PrivilegeProgramme.tiers.map((tier) => tier.entry),
      );
    });

    testWidgets('the open wallet leads with its own card, not a plan card', (
      tester,
    ) async {
      final gold = PrivilegeProgramme.gold.entry;
      openWallet(gold);

      await pump(tester, const WalletScreen());

      expect(find.byType(WalletFlipCard), findsOneWidget);
      expect(find.text('Wallet locked'), findsNothing);

      // The programme's own artwork stays on the programme screen: repeating
      // it here would say the wallet is one of the plans rather than the
      // account holding them.
      expect(find.byType(PrivilegeCardFace), findsNothing);
      expect(find.byType(PrivilegeCardSurface), findsNothing);

      // And nothing on the panel pretends to be a payment card: no chip, no
      // long number. Nothing here is swiped or keyed in, so drawing either
      // would promise a card that does not exist.
      expect(find.byType(PrivilegeCardChip), findsNothing);
      expect(find.text(gold.cardNumber), findsNothing);

      // The SHIELD mark stays: it says whose panel this is, which is true.
      expect(find.byType(PrivilegeIssuerMark), findsOneWidget);
    });

    testWidgets('the front carries the balance and the month\'s figures', (
      tester,
    ) async {
      openWallet();
      await pump(tester, const WalletScreen());

      expect(find.text('SHIELD wallet'), findsOneWidget);
      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      expect(find.text('Tap to see your plan'), findsOneWidget);
      // The silver activation and nothing else: ₹10,000 loaded plus its
      // ₹1,000 bonus. The wallet opens empty, so the balance is the plan.
      expect(find.text('₹11,000.00'), findsOneWidget);

      // "Monthly" is said once, over the three figures it qualifies.
      expect(find.text('THIS MONTH'), findsOneWidget);
      expect(find.text('REDEEMABLE'), findsOneWidget);
      expect(find.text('REDEEMED'), findsOneWidget);
      expect(find.text('REMAINING'), findsOneWidget);
      // A twelfth of 11,000, none of it drawn yet.
      expect(find.text('₹916'), findsNWidgets(2));
      expect(find.text('₹0'), findsOneWidget);
    });

    testWidgets('tapping the card turns it over onto the cards behind it', (
      tester,
    ) async {
      WalletService.instance.activate(
        PrivilegeProgramme.silver.entry,
        on: DateTime(2026, 8, 22),
      );
      WalletService.instance.activate(
        PrivilegeProgramme.gold.entry,
        on: DateTime(2026, 8, 22),
      );

      await pump(tester, const WalletScreen());

      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      expect(find.text('Your plans'), findsNothing);

      await tester.tap(find.byType(WalletFlipCard));
      await tester.pumpAndSettle();

      // The panel is the size it always is, so only the first plan is on it
      // — and the arrow says the other one is there to be had.
      expect(find.text('Your plans'), findsOneWidget);
      expect(find.text('Gold Shield'), findsNothing);
      expect(find.text('1 more plan'), findsOneWidget);

      await tester.tap(find.text('1 more plan'));
      await tester.pumpAndSettle();

      // Both plans, each a tile carrying what it holds and its two dates.
      expect(find.text('Silver Shield'), findsOneWidget);
      expect(find.text('Gold Shield'), findsOneWidget);
      expect(find.text('₹11,000'), findsOneWidget);
      expect(find.text('₹44,000'), findsOneWidget);
      expect(find.text('Recharged 22 Aug 2026'), findsNWidgets(2));
      expect(find.text('Expires 22 Aug 2027'), findsNWidgets(2));
      // And the balance stays on the front. It used to be reprinted down here
      // in a smaller size, which cost the back the height of a whole row and
      // left two figures on one panel both claiming to be the balance.
      expect(find.text('TOTAL BALANCE'), findsNothing);

      // And back again.
      await tester.tap(find.byType(WalletFlipCard));
      await tester.pumpAndSettle();

      expect(find.text('Your plans'), findsNothing);
      expect(find.text('REDEEMABLE'), findsOneWidget);
    });

    testWidgets('both faces lay out on the narrowest phone', (tester) async {
      WalletService.instance.activate(
        PrivilegeProgramme.silver.entry,
        on: DateTime(2026, 8, 22),
      );
      WalletService.instance.activate(
        PrivilegeProgramme.platinum.loads.last,
        on: DateTime(2026, 8, 22),
      );

      // 320 is the narrowest screen the app is built for, and the back is
      // carrying two cards with the longest names and amounts in the
      // programme — the worst case for a face that has to fit them.
      await pump(tester, const WalletScreen(), size: const Size(320, 2400));

      expect(find.byType(WalletFlipCard), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(WalletFlipCard));
      await tester.pumpAndSettle();

      expect(find.text('Your plans'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Let it turn itself to the release page first: a finger on the panel
      // is the member taking the pages over, so opening it here would stop
      // the turn this test is waiting for.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Monthly release'), findsOneWidget);

      // Opened out, so both tiles are laid out at 320 rather than only the
      // one the closed panel has room for. The release tile carries the
      // longest line on the panel: a six-figure amount and a count of
      // instalments on one row.
      await tester.tap(find.text('1 more plan'));
      await tester.pumpAndSettle();

      expect(find.text('Platinum Shield'), findsOneWidget);
      expect(find.textContaining(' left'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('one plan reads as one plan on the back', (tester) async {
      openWallet();
      await pump(tester, const WalletScreen());

      await tester.tap(find.byType(WalletFlipCard));
      await tester.pumpAndSettle();

      // Singular, and no count beside it: "1" next to "Your plan" would tell
      // nobody anything.
      expect(find.text('Your plan'), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(find.text('Silver Shield'), findsOneWidget);
      // What the plan carries: 10,000 loaded plus the 10% bonus.
      expect(find.text('₹11,000'), findsOneWidget);
    });

    testWidgets('shows the live balance and the bonus line', (tester) async {
      openWallet(PrivilegeProgramme.silver.loads.last);

      await pump(tester, const WalletScreen());

      // ₹30,000 loaded plus its ₹3,000 bonus, and nothing underneath it.
      expect(find.text('₹33,000.00'), findsOneWidget);
      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      expect(find.text('Silver Shield bonus · 10%'), findsOneWidget);
      expect(find.text('+₹3,000'), findsOneWidget);
      expect(find.text('+₹30,000'), findsOneWidget);
    });

    testWidgets('an open wallet offers no way to push money in', (
      tester,
    ) async {
      openWallet();
      await pump(tester, const WalletScreen());

      // The silver activation alone, and no control anywhere
      // that would add to it. A plan is the only way money arrives, so the
      // banner is the only offer on the screen.
      expect(find.text('₹11,000.00'), findsOneWidget);
      expect(find.text('Add money'), findsNothing);
      expect(find.text('Add Money to Wallet'), findsNothing);
      expect(find.text('₹500'), findsNothing);
      expect(find.text('₹1,000'), findsNothing);
      expect(find.text('₹2,000'), findsNothing);

      // One control, and it is the programme. Points had a strip and a
      // button here; neither is left.
      expect(find.text('Redeem points'), findsNothing);
      expect(find.textContaining('Shield points'), findsNothing);
      expect(find.text('Top up your Privilege Programme'), findsOneWidget);
      expect(find.text('Load ₹10,000 or more and we add 10%.'), findsOneWidget);
    });

    testWidgets('the balance still moves when a plan is recharged', (
      tester,
    ) async {
      openWallet();
      await pump(tester, const WalletScreen());

      expect(find.text('₹11,000.00'), findsOneWidget);

      // The service still takes a recharge — it is the screen that no longer
      // offers one, not the wallet that stopped accepting money.
      WalletService.instance.topUp(amount: 2000);
      await tester.pumpAndSettle();

      // The plan's ₹11,000 plus the ₹2,000 recharge, and nothing beneath it.
      expect(find.text('₹13,000.00'), findsOneWidget);
    });

    testWidgets('the top-up control opens the programme', (tester) async {
      openWallet();
      await pump(tester, const WalletScreen());

      await tester.tap(find.text('Top up your Privilege Programme'));
      await tester.pumpAndSettle();

      expect(find.byType(PrivilegeScreen), findsOneWidget);
    });

    testWidgets('activating from the programme opens the wallet', (
      tester,
    ) async {
      signIn();
      await pump(tester, const WalletScreen());

      expect(find.text('Wallet locked'), findsOneWidget);

      await tester.tap(find.text('Activate your Privilege Card').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('₹10,000').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activate'));
      await tester.pumpAndSettle();

      // Back on the wallet, open, with the card that opened it.
      expect(find.byType(PrivilegeScreen), findsNothing);
      expect(find.text('Wallet locked'), findsNothing);
      expect(find.text('₹11,000.00'), findsOneWidget);
      expect(
        WalletService.instance.cards.single.load,
        PrivilegeProgramme.silver.entry,
      );
    });
  });
  group('the card face', () {
    test('every tier gets eighteen rings, dark at the centre', () {
      for (final tier in PrivilegeProgramme.tiers) {
        final rings = PrivilegeCardFace.ringsFor(tier.accent);
        expect(rings, hasLength(18), reason: tier.name);

        final outer = HSLColor.fromColor(rings.first).lightness;
        final inner = HSLColor.fromColor(rings.last).lightness;
        expect(
          inner,
          lessThan(outer),
          reason: '${tier.name} must deepen towards the middle',
        );
      }
    });

    test('the rings are built from the tier, so no two cards match', () {
      final firstRings = PrivilegeProgramme.tiers
          .map((tier) => PrivilegeCardFace.ringsFor(tier.accent).first)
          .toSet();
      expect(firstRings, hasLength(3));

      // Silver is nearly colourless, and must stay that way rather than being
      // saturated into a blue card by the ramp.
      final silver = PrivilegeProgramme.tiers.first;
      final silverRing = HSLColor.fromColor(
        PrivilegeCardFace.ringsFor(silver.accent).first,
      );
      final gold = PrivilegeProgramme.tiers[1];
      final goldRing = HSLColor.fromColor(
        PrivilegeCardFace.ringsFor(gold.accent).first,
      );
      expect(silverRing.saturation, lessThan(goldRing.saturation));
    });

    test('a card keeps the proportions of a card', () {
      expect(PrivilegeCardFace.aspectRatio, closeTo(1.58, 0.01));
    });
  });

  group('switching cards', () {
    PageController pageController(WidgetTester tester) {
      return tester.widget<PageView>(find.byType(PageView)).controller!;
    }

    Iterable<PrivilegeCardFace> faces(WidgetTester tester) {
      return tester.widgetList<PrivilegeCardFace>(
        find.byType(PrivilegeCardFace),
      );
    }

    testWidgets('the programme opens on the cards', (tester) async {
      await pump(tester, const PrivilegeScreen());

      expect(find.byType(PageView), findsOneWidget);
      expect(faces(tester), isNotEmpty);
      // Silver is in hand, and nothing has been picked by merely arriving.
      expect(pageController(tester).page, 0);
      expect(find.text('Pick a card'), findsOneWidget);
    });

    testWidgets('swiping to a card picks it at its smallest load', (
      tester,
    ) async {
      await pump(tester, const PrivilegeScreen());

      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await tester.pumpAndSettle();

      expect(pageController(tester).page, 1);
      // The bar and the card agree on what is about to be activated.
      expect(find.text('You pay ₹40,000'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('a pip switches to its own card', (tester) async {
      await pump(tester, const PrivilegeScreen());

      // The pips carry the tier name for a screen reader, which is also how
      // they are found without depending on their shape.
      await tester.tap(find.bySemanticsLabel('Platinum Shield').last);
      await tester.pumpAndSettle();

      expect(pageController(tester).page, 2);
      expect(find.text('You pay ₹60,000'), findsOneWidget);
    });

    testWidgets('the chosen load is the one drawn on the card', (tester) async {
      await pump(tester, const PrivilegeScreen());

      await tester.tap(find.text('₹30,000').last);
      await tester.pumpAndSettle();

      expect(pageController(tester).page, 0);
      expect(
        faces(tester).any((face) => face.load.amount == 30000),
        isTrue,
        reason: 'the card must show the load that was picked',
      );
      // And the cards behind it still show their own entry loads.
      expect(faces(tester).any((face) => face.load.amount == 40000), isTrue);
    });

    testWidgets('the home strip holds all three cards, in a wallet', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(body: HomeScreen()),
        size: const Size(400, 4200),
      );

      expect(find.byType(PrivilegeWallet), findsOneWidget);

      final onHome = tester
          .widgetList<PrivilegeCardFace>(
            find.descendant(
              of: find.byType(PrivilegeCard),
              matching: find.byType(PrivilegeCardFace),
            ),
          )
          .toList();

      // One card per tier, each at its own entry load, in issue order.
      expect(onHome, hasLength(PrivilegeProgramme.tiers.length));
      expect(
        onHome.map((face) => face.load),
        PrivilegeProgramme.tiers.map((tier) => tier.entry),
      );
      for (final face in onHome) {
        expect(face.compact, isTrue, reason: face.load.name);
      }
    });

    testWidgets('at rest the cards sit stacked, deepest card highest', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(body: HomeScreen()),
        size: const Size(400, 4200),
      );

      final tops = [
        for (var index = 0; index < PrivilegeProgramme.tiers.length; index++)
          tester
              .getTopLeft(
                find
                    .descendant(
                      of: find.byType(PrivilegeCard),
                      matching: find.byType(PrivilegeCardFace),
                    )
                    .at(index),
              )
              .dy,
      ];

      // Silver furthest back and so highest on screen, platinum in front and
      // lowest — which is the only thing that makes a stack read as a stack.
      expect(tops[0], lessThan(tops[1]));
      expect(tops[1], lessThan(tops[2]));
    });

    testWidgets('tapping the strip empties the wallet, then opens it', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(body: HomeScreen()),
        size: const Size(400, 4200),
      );

      Finder cards() => find.descendant(
        of: find.byType(PrivilegeCard),
        matching: find.byType(PrivilegeCardFace),
      );
      final atRest = tester.getTopLeft(cards().first).dy;

      await tester.tap(find.text('Activate your Privilege Programme'));
      // Part-way through the fan, before the programme has opened.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      expect(
        tester.getTopLeft(cards().first).dy,
        lessThan(atRest),
        reason: 'the back card should be on its way out of the pocket',
      );
      expect(find.byType(PrivilegeScreen), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(PrivilegeScreen), findsOneWidget);
    });

    testWidgets('coming back puts the cards away again', (tester) async {
      await pump(
        tester,
        const Scaffold(body: HomeScreen()),
        size: const Size(400, 4200),
      );

      Finder cards() => find.descendant(
        of: find.byType(PrivilegeCard),
        matching: find.byType(PrivilegeCardFace),
      );
      final atRest = tester.getTopLeft(cards().first).dy;

      await tester.tap(find.text('Activate your Privilege Programme'));
      await tester.pumpAndSettle();
      expect(find.byType(PrivilegeScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(PrivilegeScreen), findsNothing);
      expect(tester.getTopLeft(cards().first).dy, atRest);
    });

    testWidgets('the strip still lays out where it is narrowest', (
      tester,
    ) async {
      // The pips and the card face share one row here; an overflow anywhere
      // in the strip throws, so reaching the assertion is it.
      await pump(
        tester,
        const Scaffold(body: HomeScreen()),
        size: const Size(320, 5200),
      );

      expect(find.byType(PrivilegeCard), findsOneWidget);
      expect(find.text('Activate your Privilege Programme'), findsOneWidget);
    });
  });
  group('the card front', () {
    test('every card carries a number, and no two share one', () {
      expect(
        PrivilegeProgramme.tiers.first.entry.cardNumber,
        '9010 8801 0010 4821',
      );
      expect(
        PrivilegeProgramme.tiers.last.loads.last.cardNumber,
        '9030 8801 0100 4821',
      );

      final numbers = [
        for (final tier in PrivilegeProgramme.tiers)
          for (final load in tier.loads) load.cardNumber,
      ];
      expect(numbers.toSet(), hasLength(numbers.length));

      for (final number in numbers) {
        // Four groups of four, the shape a card is read in.
        expect(number.split(' ').map((group) => group.length), [4, 4, 4, 4]);

        final digits = number.replaceAll(' ', '');
        expect(digits.length, 16, reason: number);
        expect(int.tryParse(digits), isNotNull, reason: number);
        // A 9 prefix, which is not one a payment network issues on — so a
        // number of this length still cannot be read as a real card.
        expect(digits[0], '9', reason: number);
      }
    });

    testWidgets('the front shows the number, the mark and the chip', (
      tester,
    ) async {
      await pump(tester, const PrivilegeScreen());

      expect(find.text('9010 8801 0010 4821'), findsOneWidget);
      expect(
        find.image(const AssetImage('assets/logos/shield_mark.png')),
        findsWidgets,
      );
      expect(find.text('HOLDER'), findsWidgets);
      expect(find.text('SHIELD MEMBER'), findsWidgets);
    });

    testWidgets(
      'the number spans about three fifths of the card, not all of it',
      (tester) async {
        await pump(tester, const PrivilegeScreen());

        final cardWidth = tester
            .getSize(find.byType(PrivilegeCardFace).first)
            .width;
        final numberWidth = tester
            .getSize(find.byKey(PrivilegeCardFace.numberKey).first)
            .width;

        // A payment card sets its number across roughly three fifths of the
        // front. Edge to edge reads as a banner, not a card number.
        // Sixteen digits need more of the front than twelve did; edge to edge
        // would be about 0.9, and that reads as a banner rather than a number.
        final share = numberWidth / cardWidth;
        expect(share, greaterThan(0.45), reason: 'share was $share');
        expect(share, lessThan(0.80), reason: 'share was $share');
      },
    );

    testWidgets('the chip stays chip-shaped', (tester) async {
      await pump(tester, const PrivilegeScreen());

      // The card body stretches its children, so a chip laid out without an
      // alignment ends up a gold bar across the whole card.
      final chip = tester.getSize(find.byKey(PrivilegeCardFace.chipKey).first);
      expect(chip.width, 34);
      expect(chip.height, 26);
    });
  });

  group('what a card includes', () {
    test('the bonus leads, then the amount\'s own benefits', () {
      for (final tier in PrivilegeProgramme.tiers) {
        for (final load in tier.loads) {
          expect(
            load.inclusions.first,
            '${load.bonusLabel} bonus credited to your wallet at once',
            reason: load.amountLabel,
          );
          // The bonus is the only thing inclusions adds: it is a credit rather
          // than a service, and everything after it is what the credit buys.
          expect(load.inclusions.skip(1), load.benefits);
        }
      }
    });

    test('the first two lines are arithmetic off the load itself', () {
      // Written nowhere, so neither can drift from the amount above it.
      for (final tier in PrivilegeProgramme.tiers) {
        for (final load in tier.loads) {
          expect(
            load.benefits[0],
            'Grab service up to ${load.creditedLabel}',
            reason: load.amountLabel,
          );
          expect(
            load.benefits[1],
            '${load.monthlyCoverageLabel} monthly bills coverage',
            reason: load.amountLabel,
          );
          // Grab service is the whole of what the card can be spent on: the
          // amount loaded plus the bonus on it.
          expect(load.credited, load.amount + load.bonus);
        }
      }
    });

    test('every card carries free home delivery, whatever is on it', () {
      for (final tier in PrivilegeProgramme.tiers) {
        for (final load in tier.loads) {
          expect(
            load.benefits,
            contains('Free home delivery'),
            reason: load.amountLabel,
          );
        }
      }
    });

    test('what an amount carries climbs with the amount', () {
      // The reason the list moved off the card and onto the row: ₹10,000 is
      // one free dental consultation and ₹30,000 is three, so a list stated
      // once for silver would be wrong for two of its three amounts.
      String dentalOn(int amount) => PrivilegeProgramme.loadFor(
        amount,
      )!.benefits.firstWhere((line) => line.contains('dental'));

      expect(dentalOn(10000), 'Free dental consultation × 1');
      expect(dentalOn(20000), 'Free dental consultation × 2');
      expect(dentalOn(30000), 'Free dental consultation × 3');
      expect(dentalOn(60000), 'Free dental consultation × 6');
      expect(dentalOn(100000), 'Free dental consultation × 10');
    });

    test('the count is one per ten thousand loaded', () {
      for (final tier in PrivilegeProgramme.tiers) {
        for (final load in tier.loads) {
          expect(
            load.benefitUnits,
            load.amount ~/ PrivilegeProgramme.step,
            reason: load.amountLabel,
          );
        }
      }
      expect(PrivilegeProgramme.loadFor(10000)!.benefitUnits, 1);
      expect(PrivilegeProgramme.loadFor(100000)!.benefitUnits, 10);
    });

    test('silver buys consultations outright, gold buys them cheaply', () {
      // Two different offers, not two sizes of one. Silver hands over a fixed
      // number of free consultations; gold charges a flat ₹15 however often
      // they are used, which is why gold ignores the per-ten-thousand count.
      for (final load in PrivilegeProgramme.silver.loads) {
        expect(
          load.benefits,
          contains('Free dental consultation × ${load.benefitUnits}'),
          reason: load.amountLabel,
        );
        expect(load.benefits, contains('Home care at ₹50 a visit'));
      }
      for (final load in PrivilegeProgramme.gold.loads) {
        expect(load.benefits, contains('Dental consultation at ₹15'));
        expect(load.benefits, contains('Tele consultation at ₹15'));
        expect(
          load.benefits,
          isNot(contains('Free dental consultation × ${load.benefitUnits}')),
          reason: load.amountLabel,
        );
      }
    });

    test('the home care call-out is what separates the two gold loads', () {
      final forty = PrivilegeProgramme.loadFor(40000)!;
      final fifty = PrivilegeProgramme.loadFor(50000)!;

      expect(forty.benefits, contains('Home care at ₹20 a visit'));
      expect(fifty.benefits, contains('Free home care × 2'));
      expect(fifty.benefits, isNot(contains('Home care at ₹20 a visit')));
    });

    test('platinum carries two months of dietitian, at every load', () {
      // The one platinum benefit that does not climb with the amount.
      for (final load in PrivilegeProgramme.platinum.loads) {
        expect(
          load.benefits,
          contains(PrivilegeProgramme.dietitianPlatinum),
          reason: load.amountLabel,
        );
        expect(
          load.benefits,
          isNot(contains(PrivilegeProgramme.dietitianBase)),
          reason: load.amountLabel,
        );
      }
      // Silver and gold get the single consultation instead.
      for (final tier in [PrivilegeProgramme.silver, PrivilegeProgramme.gold]) {
        for (final load in tier.loads) {
          expect(
            load.benefits,
            contains(PrivilegeProgramme.dietitianBase),
            reason: load.amountLabel,
          );
        }
      }
    });

    test('monthly coverage is the twelfth the wallet actually releases', () {
      // Rounded down, like the bonus and for the same reason: twelve of these
      // must never add up to more than the card carries. ₹11,000 over twelve
      // months is ₹916 and a fraction, and the fraction is not promised.
      expect(PrivilegeProgramme.loadFor(10000)!.monthlyCoverage, 916);
      expect(PrivilegeProgramme.loadFor(20000)!.monthlyCoverage, 1833);
      expect(PrivilegeProgramme.loadFor(30000)!.monthlyCoverage, 2750);
      expect(PrivilegeProgramme.loadFor(40000)!.monthlyCoverage, 3666);
      expect(PrivilegeProgramme.loadFor(50000)!.monthlyCoverage, 4583);
      expect(PrivilegeProgramme.loadFor(60000)!.monthlyCoverage, 5500);

      for (final tier in PrivilegeProgramme.tiers) {
        for (final load in tier.loads) {
          expect(
            load.monthlyCoverage * PrivilegeProgramme.validityMonths,
            lessThanOrEqualTo(load.credited),
            reason: load.amountLabel,
          );
        }
      }
    });

    test('benefits up to is the biggest load plus its bonus', () {
      expect(PrivilegeProgramme.silver.benefitsUpTo, 33000);
      expect(PrivilegeProgramme.gold.benefitsUpTo, 55000);
      expect(PrivilegeProgramme.platinum.benefitsUpTo, 110000);

      expect(PrivilegeProgramme.silver.benefitsUpToLabel, '₹33,000');
      expect(PrivilegeProgramme.gold.benefitsUpToLabel, '₹55,000');
      expect(PrivilegeProgramme.platinum.benefitsUpToLabel, '₹1,10,000');
    });

    test('each card is issued for the amounts it publishes', () {
      expect(PrivilegeProgramme.silver.amounts, [10000, 20000, 30000]);
      expect(PrivilegeProgramme.gold.amounts, [40000, 50000]);
      expect(PrivilegeProgramme.platinum.amounts, [
        60000,
        70000,
        80000,
        90000,
        100000,
      ]);

      // 60,000 was a gold load once. It is the platinum entry now, not a gap.
      expect(PrivilegeProgramme.isValidAmount(60000), isTrue);
      expect(PrivilegeProgramme.tierFor(60000), PrivilegeProgramme.platinum);

      // The three cards still run in whole steps with nothing missing between
      // them, which is what lets the screen do without a type-an-amount box.
      final published = [
        for (final tier in PrivilegeProgramme.tiers) ...tier.amounts,
      ];
      expect(published, [
        for (var amount = 10000; amount <= 100000; amount += 10000) amount,
      ]);
    });

    testWidgets('the list follows the amount, not the card', (tester) async {
      await pump(tester, const PrivilegeScreen());

      // Before anything is chosen the panel stands on the card's entry load,
      // and says which amount it is describing.
      expect(
        find.text('What ₹10,000 on Silver Shield includes'),
        findsOneWidget,
      );
      expect(find.textContaining('includes'), findsOneWidget);
      expect(find.text('Free dental consultation × 1'), findsOneWidget);
      expect(find.text('Grab service up to ₹11,000'), findsOneWidget);
      expect(find.text('₹916 monthly bills coverage'), findsOneWidget);

      // Choosing a bigger load rewrites the list rather than leaving it.
      await tester.tap(find.text('₹30,000').last);
      await tester.pumpAndSettle();

      expect(
        find.text('What ₹30,000 on Silver Shield includes'),
        findsOneWidget,
      );
      expect(find.text('Free dental consultation × 3'), findsOneWidget);
      expect(find.text('Free tele consultation × 3'), findsOneWidget);
      expect(find.text('Grab service up to ₹33,000'), findsOneWidget);
      expect(find.text('₹2,750 monthly bills coverage'), findsOneWidget);

      // And the ₹10,000 list is gone, not stacked under it.
      expect(find.text('Free dental consultation × 1'), findsNothing);
      expect(find.text('Grab service up to ₹11,000'), findsNothing);
      expect(find.textContaining('includes'), findsOneWidget);
    });

    testWidgets('the headline figure stays the card\'s, not the amount\'s', (
      tester,
    ) async {
      await pump(tester, const PrivilegeScreen());

      // "Benefits up to ₹33,000" is what silver tops out at, so it holds
      // still while the list underneath follows the row.
      expect(find.textContaining('Benefits up to'), findsOneWidget);
      expect(find.text('Benefits up to '), findsNothing);
      expect(
        find.text(PrivilegeProgramme.silver.benefitsUpToLabel),
        findsWidgets,
      );

      await tester.tap(find.text('₹20,000').last);
      await tester.pumpAndSettle();

      expect(
        find.text(PrivilegeProgramme.silver.benefitsUpToLabel),
        findsWidgets,
      );
    });

    testWidgets('switching card switches the benefits with it', (tester) async {
      await pump(tester, const PrivilegeScreen());

      expect(find.text('Grab service up to ₹11,000'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Gold Shield').last);
      await tester.pumpAndSettle();

      expect(find.text('What ₹40,000 on Gold Shield includes'), findsOneWidget);
      expect(find.text('Home care at ₹20 a visit'), findsOneWidget);
      expect(find.text('Dental consultation at ₹15'), findsOneWidget);
      expect(find.text('Grab service up to ₹44,000'), findsOneWidget);
      // Silver's are gone with silver.
      expect(find.text('Grab service up to ₹11,000'), findsNothing);
      expect(find.text('Free dental consultation × 1'), findsNothing);

      // Gold's second load is the one that stops paying the call-out.
      await tester.tap(find.text('₹50,000').last);
      await tester.pumpAndSettle();

      expect(find.text('Free home care × 2'), findsOneWidget);
      expect(find.text('Home care at ₹20 a visit'), findsNothing);
    });
  });
}
