import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/dates.dart';
import 'package:shield/money.dart';
import 'package:shield/module/account/account_screen.dart';
import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/investor/investor_access_card.dart';
import 'package:shield/module/investor/investor_directory.dart';
import 'package:shield/module/investor/investor_model.dart';
import 'package:shield/module/investor/investor_portal_screen.dart';
import 'package:shield/module/investor/investor_service.dart';
import 'package:shield/module/investor/investor_sparkline.dart';
import 'package:shield/module/wallet/wallet_service.dart';
import 'package:shield/screens/home_screen.dart';

void main() {
  final investor = InvestorDirectory.demo;
  final service = InvestorService.instance;

  void resetAll() {
    AuthService.instance.reset();
    InvestorService.instance.reset();
    WalletService.instance.reset();
  }

  setUp(resetAll);
  tearDown(resetAll);

  group('the investor model', () {
    test('the seed number resolves to the demo investor, others do not', () {
      expect(service.investorForPhone('9876543210'), investor);
      expect(service.investorForPhone('9000000002'), isNull);
      expect(service.investorForPhone(null), isNull);
    });

    test('a unit is priced at ₹1,50,000, and total invested follows from it', () {
      expect(investor.unitPrice, 150000);
      expect(
        investor.totalInvested,
        investor.totalUnits * investor.unitPrice,
      );
    });

    test('current value carries the ROI forward, and returns is the gap', () {
      final expectedCurrent =
          (investor.totalInvested * (1 + investor.roiPercent / 100)).round();
      expect(investor.currentValue, expectedCurrent);
      expect(
        investor.totalReturns,
        investor.currentValue - investor.totalInvested,
      );
      expect(investor.totalReturns, greaterThan(0));
    });

    test('the stake is in one specific store, not the whole directory', () {
      expect(investor.investedStore, InvestorDirectory.featuredStore);
    });

    test('the demo opens on the yearly plan, and the other side is monthly', () {
      expect(investor.planType, InvestorPlanType.yearly);
      expect(InvestorPlanType.yearly.other, InvestorPlanType.monthly);
      expect(InvestorPlanType.monthly.other, InvestorPlanType.yearly);
    });

    test('the yearly pace is the monthly one annualised, not a separate figure', () {
      expect(investor.monthsInvested, greaterThanOrEqualTo(1));
      expect(
        investor.monthlyReturnPace,
        (investor.totalReturns / investor.monthsInvested).round(),
      );
      expect(investor.yearlyReturnPace, investor.monthlyReturnPace * 12);
    });

    test('the purchase credit is 10% of what was invested, plus ₹250', () {
      expect(
        investor.purchaseCredit,
        (investor.totalInvested * 0.10).round() + 250,
      );
    });

    test('the return history runs six periods, oldest first, labels included', () {
      final yearlyValues = investor.returnHistory(yearly: true);
      final yearlyLabels = investor.returnHistoryLabels(yearly: true);
      expect(yearlyValues, hasLength(6));
      expect(yearlyLabels, hasLength(6));
      // Labels are calendar years, ending on the current one.
      expect(yearlyLabels.last, '${DateTime.now().year}');

      final monthlyValues = investor.returnHistory(yearly: false);
      final monthlyLabels = investor.returnHistoryLabels(yearly: false);
      expect(monthlyValues, hasLength(6));
      expect(monthlyLabels, hasLength(6));
      // A month abbreviation and a two-digit year, not a bare number.
      expect(monthlyLabels.last, matches(RegExp(r"^[A-Z][a-z]{2} '\d{2}$")));

      // Every point is a real amount, never negative — a stake never shows
      // a loss it has not actually made in this demo.
      expect(yearlyValues.every((v) => v >= 0), isTrue);
      expect(monthlyValues.every((v) => v >= 0), isTrue);
    });
  });

  group('the home card', () {
    Future<void> pumpHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the one recognised investor number shows the card', (
      tester,
    ) async {
      AuthService.instance.signInAs(phone: '9876543210');
      await pumpHome(tester);

      expect(find.byType(InvestorAccessCard), findsOneWidget);
      expect(find.text('My Investment'), findsOneWidget);
      // Not the invested store's name — the card is shared across every
      // store an investor might hold a stake in.
      expect(
        find.text('Track your investment return'),
        findsOneWidget,
      );
      expect(find.text('${investor.totalUnits} units'), findsOneWidget);
      // No printed code on the home card — a trend line stands in for it.
      expect(find.text(investor.investorCode), findsNothing);
      expect(
        find.descendant(
          of: find.byType(InvestorAccessCard),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
    });

    testWidgets(
      'no other number shows anything — not even an invitation to invest',
      (tester) async {
        AuthService.instance.signInAs(phone: '9000000002');
        await pumpHome(tester);

        expect(find.byType(InvestorAccessCard), findsNothing);
        expect(find.text('My Investment'), findsNothing);
      },
    );

    testWidgets('a guest, signed out, sees nothing from this section either', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.byType(InvestorAccessCard), findsNothing);
      expect(find.text('My Investment'), findsNothing);
    });

    testWidgets('the access card opens the investor portal', (tester) async {
      AuthService.instance.signInAs(phone: '9876543210');
      await pumpHome(tester);

      await tester.tap(find.text('My Investment'));
      await tester.pumpAndSettle();

      expect(find.byType(InvestorPortalScreen), findsOneWidget);
    });
  });

  group('the portal screen', () {
    Future<void> pumpPortal(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: InvestorPortalScreen(investor: investor)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'leads with who the stake belongs to, without the printed code',
      (tester) async {
        await pumpPortal(tester);

        expect(find.text(investor.name), findsOneWidget);
        expect(
          find.text('Investor since ${formatDate(investor.investedSince)}'),
          findsOneWidget,
        );
        expect(find.textContaining(investor.investorCode), findsNothing);
      },
    );

    testWidgets('the headline figures cover units and amount, not current value', (
      tester,
    ) async {
      await pumpPortal(tester);

      expect(find.text('Total units invested'), findsOneWidget);
      expect(find.text('${investor.totalUnits}'), findsOneWidget);
      expect(find.text('Total amount invested'), findsOneWidget);
      expect(find.text('Current value'), findsNothing);
      expect(find.text('₹${formatRupees(investor.currentValue)}'), findsNothing);
    });

    testWidgets(
      'return on investment leads with the rupee figure, never a percentage, '
      'a round gauge, or a graph of its own',
      (tester) async {
        await pumpPortal(tester);

        expect(find.text('Return on Investment'), findsOneWidget);
        expect(
          find.text('₹${formatRupees(investor.totalReturns)}'),
          findsOneWidget,
        );
        expect(find.text('Total returns'), findsOneWidget);
        expect(
          find.text('${investor.roiPercent.toStringAsFixed(1)}%'),
          findsNothing,
        );
        // No round gauge, and no graph of its own either — the one trend
        // line on the whole screen lives on the return plan card, backed
        // by its history table.
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(TrendSparkline), findsOneWidget);
      },
    );

    testWidgets('shows only the one store the stake is actually in', (
      tester,
    ) async {
      await pumpPortal(tester);

      expect(find.text('Invested store'), findsOneWidget);
      expect(find.text(investor.investedStore.name), findsOneWidget);
      expect(find.text(investor.investedStore.addressLine), findsOneWidget);
    });

    testWidgets('never shows the customer book', (tester) async {
      await pumpPortal(tester);

      expect(find.text('All customers'), findsNothing);
      expect(find.text('CUSTOMER'), findsNothing);
    });

    testWidgets(
      'the return plan is fixed to the yearly plan, with its own graph and '
      'history — no toggle to switch it here',
      (tester) async {
        await pumpPortal(tester);

        expect(find.text('Return Plan'), findsOneWidget);
        expect(find.text('Yearly Plan'), findsOneWidget);
        expect(
          find.text('₹${formatRupees(investor.yearlyReturnPace)}'),
          findsOneWidget,
        );
        expect(find.text('Per year'), findsOneWidget);
        // Nothing left to tap into a monthly view — no toggle on this card.
        expect(find.text('Monthly'), findsNothing);
        expect(find.text('Per month'), findsNothing);

        // The graph — a continuous line, not a bare number — and the
        // history underneath it, six calendar years, oldest reading at
        // the bottom of the list and the current year at the top.
        expect(find.text('Return History'), findsOneWidget);
        final yearlyLabels = investor.returnHistoryLabels(yearly: true);
        final yearlyValues = investor.returnHistory(yearly: true);
        for (var i = 0; i < yearlyLabels.length; i++) {
          expect(find.text(yearlyLabels[i]), findsOneWidget);
          expect(
            find.text('₹${formatRupees(yearlyValues[i])}'),
            findsWidgets,
          );
        }
      },
    );

    testWidgets(
      'the plan is a fixed label; the only control is a request to switch it',
      (tester) async {
        await pumpPortal(tester);

        expect(find.text('Yearly Plan'), findsOneWidget);
        expect(investor.planType, InvestorPlanType.yearly);
        // A request to admin, named for the cadence it would move to — not a
        // toggle that flips the plan on the spot.
        expect(find.text('Request the Monthly plan'), findsOneWidget);
      },
    );

    testWidgets(
      'requesting a switch confirms, marks the session, and reads back pending',
      (tester) async {
        await pumpPortal(tester);

        await tester.tap(find.text('Request the Monthly plan'));
        await tester.pumpAndSettle();

        // The confirm dialog, then send it.
        expect(find.text('Switch to the Monthly plan?'), findsOneWidget);
        await tester.tap(find.text('Send request'));
        await tester.pumpAndSettle();

        expect(InvestorService.instance.planChangeRequested, isTrue);
        expect(
          find.text('Request sent — our team will confirm the switch.'),
          findsOneWidget,
        );
        // The button is gone; the pending line has taken its place.
        expect(find.text('Request the Monthly plan'), findsNothing);
        expect(
          find.text('Change requested — pending admin review'),
          findsOneWidget,
        );
      },
    );

    testWidgets('dismissing the request dialog leaves the plan untouched', (
      tester,
    ) async {
      await pumpPortal(tester);

      await tester.tap(find.text('Request the Monthly plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(InvestorService.instance.planChangeRequested, isFalse);
      expect(find.text('Request the Monthly plan'), findsOneWidget);
    });

    testWidgets('there is no Purchase Benefit section on the portal', (
      tester,
    ) async {
      await pumpPortal(tester);

      expect(find.text('Purchase Benefit'), findsNothing);
      expect(find.text('Already credited to your wallet'), findsNothing);
      expect(
        find.text('10% of ₹${formatRupees(investor.totalInvested)} + ₹250'),
        findsNothing,
      );
    });
  });

  group('the account screen', () {
    Future<void> pumpAccount(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: AccountScreen()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers the investor portal only to an investor number', (
      tester,
    ) async {
      AuthService.instance.signInAs(phone: '9876543210');
      addTearDown(AuthService.instance.reset);
      await pumpAccount(tester);

      expect(find.text('Portfolio'), findsOneWidget);

      await tester.tap(find.text('Portfolio'));
      await tester.pumpAndSettle();

      expect(find.byType(InvestorPortalScreen), findsOneWidget);
    });

    testWidgets('says nothing about it for a member number', (tester) async {
      AuthService.instance.signInAs(phone: '9000000002');
      addTearDown(AuthService.instance.reset);
      await pumpAccount(tester);

      expect(find.text('Portfolio'), findsNothing);
    });
  });
}
