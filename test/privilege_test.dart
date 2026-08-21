import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/auth/login_screen.dart';
import 'package:shield/module/privilege/privilege_card.dart';
import 'package:shield/module/privilege/privilege_card_face.dart';
import 'package:shield/module/privilege/privilege_screen.dart';
import 'package:shield/module/privilege/privilege_tier.dart';
import 'package:shield/module/registration/registration_service.dart';
import 'package:shield/module/registration/shield_store.dart';
import 'package:shield/module/wallet/wallet_screen.dart';
import 'package:shield/module/wallet/wallet_service.dart';
import 'package:shield/screens/home_screen.dart';

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
    test('every published card starts at ₹10,000 and steps by ₹10,000', () {
      final amounts = PrivilegeProgramme.tiers
          .map((tier) => tier.amount)
          .toList();
      expect(amounts, [10000, 20000, 30000, 40000, 50000]);
    });

    test('each card is named', () {
      expect(PrivilegeProgramme.tiers.map((tier) => tier.name), [
        'Silver Shield',
        'Gold Shield',
        'Platinum Shield',
        'Titanium Shield',
        'Diamond Shield',
      ]);
    });

    test('the bonus is 10%, and it is what the brief asked for', () {
      final silver = PrivilegeProgramme.tiers.first;
      expect(silver.amount, 10000);
      expect(silver.bonus, 1000);
      expect(silver.credited, 11000);

      for (final tier in PrivilegeProgramme.tiers) {
        expect(tier.bonus, tier.amount ~/ 10, reason: tier.name);
      }
    });

    test('the bonus rounds down, never up', () {
      // Not reachable through the UI, which only allows multiples of 10,000,
      // but a promise must never be overstated by a rounding rule.
      expect(PrivilegeProgramme.bonusOn(10009), 1000);
      expect(PrivilegeProgramme.bonusOn(0), 0);
      expect(PrivilegeProgramme.bonusOn(-5000), 0);
    });

    test('only whole multiples of ₹10,000 are valid', () {
      expect(PrivilegeProgramme.isValidAmount(10000), isTrue);
      expect(PrivilegeProgramme.isValidAmount(70000), isTrue);
      expect(PrivilegeProgramme.isValidAmount(9999), isFalse);
      expect(PrivilegeProgramme.isValidAmount(15000), isFalse);
      expect(PrivilegeProgramme.isValidAmount(0), isFalse);
      expect(PrivilegeProgramme.isValidAmount(600000), isFalse);
    });

    test('a custom amount is issued as a card', () {
      expect(PrivilegeProgramme.tierFor(20000)?.name, 'Gold Shield');

      // Above the published cards the top name is kept rather than invented:
      // the rate is identical, so a new name would suggest a benefit that is
      // not there.
      final big = PrivilegeProgramme.tierFor(70000);
      expect(big?.name, 'Diamond Shield');
      expect(big?.bonus, 7000);
      expect(big?.credited, 77000);

      expect(PrivilegeProgramme.tierFor(15000), isNull);
    });

    test('every card owns a colour, and no two share one', () {
      final accents = PrivilegeProgramme.tiers
          .map((tier) => tier.accent)
          .toSet();
      final tints = PrivilegeProgramme.tiers.map((tier) => tier.tint).toSet();

      expect(accents, hasLength(PrivilegeProgramme.tiers.length));
      expect(tints, hasLength(PrivilegeProgramme.tiers.length));

      // A custom amount inherits the top card's colour along with its name,
      // so the two can never disagree.
      final custom = PrivilegeProgramme.tierFor(70000)!;
      expect(custom.accent, PrivilegeProgramme.tiers.last.accent);
      expect(custom.tint, PrivilegeProgramme.tiers.last.tint);
    });

    test('labels are grouped the Indian way', () {
      final diamond = PrivilegeProgramme.tiers.last;
      expect(diamond.amountLabel, '₹50,000');
      expect(diamond.bonusLabel, '₹5,000');
      expect(diamond.creditedLabel, '₹55,000');
    });
  });

  group('the wallet', () {
    test('a top-up with a bonus posts two lines, not one', () {
      WalletService.instance.topUp(
        amount: 10000,
        bonus: 1000,
        label: 'Silver Shield activation',
        bonusLabel: 'Silver Shield bonus · 10%',
      );

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

    test('a top-up with no bonus posts one line', () {
      final before = WalletService.instance.entries.length;
      WalletService.instance.topUp(amount: 500);

      expect(WalletService.instance.entries.length, before + 1);
      expect(
        WalletService.instance.balance,
        WalletService.openingBalance + 500,
      );
    });

    test('a non-positive top-up is refused', () {
      final before = WalletService.instance.balance;
      WalletService.instance.topUp(amount: 0);
      WalletService.instance.topUp(amount: -100);

      expect(WalletService.instance.balance, before);
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
  });

  group('the programme screen', () {
    testWidgets('lists every card with its amount and bonus', (tester) async {
      await pump(tester, const PrivilegeScreen());

      for (final tier in PrivilegeProgramme.tiers) {
        expect(find.text(tier.name), findsOneWidget, reason: tier.name);
        expect(
          find.text('+ ${tier.bonusLabel} free'),
          findsOneWidget,
          reason: tier.name,
        );
      }
      expect(find.text('₹10,000'), findsWidgets);
      expect(find.text('₹11,000 credited to your wallet'), findsOneWidget);
    });

    testWidgets('each card is painted in its own colour', (tester) async {
      await pump(tester, const PrivilegeScreen());

      // The full-height stripe down the left of each card.
      for (final tier in PrivilegeProgramme.tiers) {
        final stripe = find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == tier.accent,
        );
        expect(stripe, findsOneWidget, reason: tier.name);
      }
    });

    testWidgets('picking a card washes it in that card\'s tint', (
      tester,
    ) async {
      await pump(tester, const PrivilegeScreen());

      final gold = PrivilegeProgramme.tiers[1];
      final tinted = find.byWidgetPredicate(
        (widget) => widget is Material && widget.color == gold.tint,
      );
      expect(tinted, findsNothing);

      await tester.tap(find.text('Gold Shield'));
      await tester.pumpAndSettle();

      expect(tinted, findsOneWidget);
      // And only that one: picking gold must not tint the other four.
      for (final other in PrivilegeProgramme.tiers) {
        if (other.amount == gold.amount) {
          continue;
        }
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Material && widget.color == other.tint,
          ),
          findsNothing,
          reason: other.name,
        );
      }
    });

    testWidgets('Activate is disabled until a card is picked', (tester) async {
      await pump(tester, const PrivilegeScreen());

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('Pick a card'), findsOneWidget);

      await tester.tap(find.text('Gold Shield'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(find.text('You pay ₹20,000'), findsOneWidget);
      expect(find.text('₹22,000'), findsWidgets);
    });

    testWidgets('a custom multiple is accepted and priced', (tester) async {
      await pump(tester, const PrivilegeScreen());

      await tester.enterText(find.byType(TextField), '70000');
      await tester.pumpAndSettle();

      expect(find.text('You pay ₹70,000'), findsOneWidget);
      expect(find.text('₹77,000'), findsWidgets);
    });

    testWidgets('an amount off the step is refused', (tester) async {
      await pump(tester, const PrivilegeScreen());

      await tester.enterText(find.byType(TextField), '15000');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Enter a multiple of ₹10,000'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('activating credits the amount and the bonus', (tester) async {
      signIn();
      await pump(tester, const PrivilegeScreen());

      await tester.tap(find.text('Silver Shield'));
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

      await tester.tap(find.text('Silver Shield'));
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
    testWidgets('shows the live balance and the bonus line', (tester) async {
      WalletService.instance.topUp(
        amount: 30000,
        bonus: 3000,
        label: 'Platinum Shield activation',
        bonusLabel: 'Platinum Shield bonus · 10%',
      );

      await pump(tester, const WalletScreen());

      // 3,472 + 33,000
      expect(find.text('₹36,472.00'), findsOneWidget);
      expect(find.text('Platinum Shield bonus · 10%'), findsOneWidget);
      expect(find.text('+₹3,000'), findsOneWidget);
      expect(find.text('+₹30,000'), findsOneWidget);
    });

    testWidgets('a quick top-up updates the balance in place', (tester) async {
      await pump(tester, const WalletScreen());

      expect(find.text('₹3,472.00'), findsOneWidget);

      await tester.tap(find.text('₹2,000'));
      await tester.pumpAndSettle();

      expect(find.text('₹5,472.00'), findsOneWidget);
    });

    testWidgets('points at the programme', (tester) async {
      await pump(tester, const WalletScreen());

      expect(find.text('Privilege Programme'), findsOneWidget);
      await tester.tap(find.text('Privilege Programme'));
      await tester.pumpAndSettle();

      expect(find.byType(PrivilegeScreen), findsOneWidget);
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
      expect(firstRings, hasLength(PrivilegeProgramme.tiers.length));

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

    testWidgets('swiping to a card picks it', (tester) async {
      await pump(tester, const PrivilegeScreen());

      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await tester.pumpAndSettle();

      expect(pageController(tester).page, 1);
      // The bar and the card agree on what is about to be activated.
      expect(find.text('You pay ₹20,000'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('picking a row below brings its card to the front', (
      tester,
    ) async {
      await pump(tester, const PrivilegeScreen());

      await tester.tap(find.text('Platinum Shield'));
      await tester.pumpAndSettle();

      expect(pageController(tester).page, 2);
      expect(find.text('You pay ₹30,000'), findsOneWidget);
    });

    testWidgets('a pip switches to its own card', (tester) async {
      await pump(tester, const PrivilegeScreen());

      // The pips carry the tier name for a screen reader, which is also how
      // they are found without depending on their shape.
      await tester.tap(find.bySemanticsLabel('Diamond Shield').last);
      await tester.pumpAndSettle();

      expect(pageController(tester).page, 4);
      expect(find.text('You pay ₹50,000'), findsOneWidget);
    });

    testWidgets('a custom amount is drawn on the card it is issued as', (
      tester,
    ) async {
      await pump(tester, const PrivilegeScreen());

      await tester.enterText(find.byType(TextField), '70000');
      await tester.pumpAndSettle();

      expect(pageController(tester).page, 4);
      expect(
        faces(tester).any((face) => face.tier.amount == 70000),
        isTrue,
        reason: 'the top card must show the amount that was typed',
      );
      // Switching the carousel must not have thrown the typed amount away.
      expect(find.text('You pay ₹70,000'), findsOneWidget);
    });

    testWidgets('the card face is the same card the home strip shows', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(body: HomeScreen()),
        size: const Size(400, 4200),
      );

      final onHome = tester.widget<PrivilegeCardFace>(
        find.descendant(
          of: find.byType(PrivilegeCard),
          matching: find.byType(PrivilegeCardFace),
        ),
      );
      expect(onHome.compact, isTrue);
      expect(onHome.tier.amount, PrivilegeProgramme.tiers.first.amount);
    });

    testWidgets('the strip still lays out where it is narrowest', (
      tester,
    ) async {
      // The five pips and the card face share one row here; an overflow
      // anywhere in the strip throws, so reaching the assertion is it.
      await pump(
        tester,
        const Scaffold(body: HomeScreen()),
        size: const Size(320, 5200),
      );

      expect(find.byType(PrivilegeCard), findsOneWidget);
      expect(find.text('Activate your Privilege Programme'), findsOneWidget);
    });
  });
}
