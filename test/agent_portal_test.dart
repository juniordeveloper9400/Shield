import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/dates.dart';
import 'package:shield/money.dart';
import 'package:shield/module/agent/agent_customer_detail_screen.dart';
import 'package:shield/module/agent/agent_detail_screen.dart';
import 'package:shield/module/agent/agent_direct_sale.dart';
import 'package:shield/module/agent/agent_directory.dart';
import 'package:shield/module/agent/agent_earnings_card.dart';
import 'package:shield/module/agent/agent_model.dart';
import 'package:shield/module/agent/agent_portal_card.dart';
import 'package:shield/module/agent/agent_portal_screen.dart';
import 'package:shield/module/agent/agent_registration_screen.dart';
import 'package:shield/module/agent/agent_service.dart';
import 'package:shield/module/agent/agent_team_tree_screen.dart';
import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/home/refer_earn_card.dart';
import 'package:shield/screens/home_screen.dart';

void main() {
  final national = AgentDirectory.national;
  final service = AgentService.instance;

  setUp(() {
    AuthService.instance.reset();
    service.reset();
  });
  tearDown(() {
    AuthService.instance.reset();
    service.reset();
  });

  /// Registers a valid agent under [parent]. Returns the error string (null on
  /// success).
  String? register(
    Agent parent, {
    AgentLevel? level,
    String first = 'Sanju',
    String last = 'Pillai',
    String phone = '9812345670',
    String aadhaar = '123412341234',
    String pan = 'ABCDE1234F',
    String pincode = '682001',
    String account = '123456789012',
  }) {
    return service.registerAgent(
      parent: parent,
      level: level ?? service.allowedChildLevels(parent).first,
      firstName: first,
      lastName: last,
      phone: phone,
      dob: DateTime(1990, 5, 4),
      aadhaar: aadhaar,
      pan: pan,
      address: '12 MG Road',
      pincode: pincode,
      place: 'Wayanad',
      accountNumber: account,
    );
  }

  /// Drives the registration form all the way through from wherever it has
  /// just been pushed — every KYC field, the date-of-birth picker, and the
  /// OTP step — the same path a real submission takes.
  Future<void> submitRegistrationForm(
    WidgetTester tester, {
    required String first,
    required String last,
  }) async {
    Future<void> fill(String hint, String value) async {
      final field = find.widgetWithText(TextFormField, hint);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await fill('First name', first);
    await fill('Last name', last);
    await fill('10-digit mobile number', '9812345670');
    await fill('12-digit Aadhaar', '123412341234');
    await fill('ABCDE1234F', 'ABCDE1234F');
    await fill('House / street / locality', '4 Fort Road');
    await fill('6 digits', '682001');
    await fill('Town / village', 'Fort Kochi');
    await fill('Account the commission is paid into', '123456789012');
    await tester.ensureVisible(find.byIcon(Icons.event_rounded));
    await tester.tap(find.byIcon(Icons.event_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Send OTP'));
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), AuthService.demoOtp);
    await tester.pumpAndSettle();
  }

  group('the roster', () {
    test('the seed number resolves to a national agent, others do not', () {
      final agent = service.agentForPhone('9539810000');
      expect(agent, isNotNull);
      expect(agent!.level, AgentLevel.national);
      expect(agent.agentCode, 'SHD-NAT-001');

      expect(service.agentForPhone('9000000002'), isNull);
      expect(service.agentForPhone(null), isNull);
    });

    test('a fresh roster holds only the national agent', () {
      expect(service.roster, [national]);
      expect(service.childrenOf(national.id), isEmpty);
      expect(service.descendantsOf(national.id), isEmpty);
    });

    test('seed agents are not marked as registered', () {
      expect(national.isRegistered, isFalse);
    });
  });

  group('the org shape', () {
    test('childCapacity doubles every tier down to lsgd, and closes off at ward', () {
      expect(AgentLevel.national.childCapacity, 2);
      expect(AgentLevel.region.childCapacity, 2);
      expect(AgentLevel.state.childCapacity, 2);
      expect(AgentLevel.district.childCapacity, 2);
      expect(AgentLevel.assembly.childCapacity, 2);
      expect(AgentLevel.lsgd.childCapacity, 2);
      expect(AgentLevel.ward.childCapacity, 0);
    });

    test('openPositionsUnder counts down as positions fill, never below zero', () {
      expect(service.openPositionsUnder(national), 2);
      register(national);
      expect(service.openPositionsUnder(national), 1);
      register(national);
      expect(service.openPositionsUnder(national), 0);
    });

    test('allowed child levels are every tier below the parent, not just the next one', () {
      expect(service.allowedChildLevels(national), [
        AgentLevel.region,
        AgentLevel.state,
        AgentLevel.district,
        AgentLevel.assembly,
        AgentLevel.lsgd,
        AgentLevel.ward,
      ]);

      var parent = national;
      for (var i = 0; i < 6; i++) {
        register(parent);
        parent = service.childrenOf(parent.id).first;
      }
      expect(parent.level, AgentLevel.ward);
      expect(service.allowedChildLevels(parent), isEmpty);
    });

    test('a level can be skipped straight to, without seeding the tiers between', () {
      // No region, no state — national recruits a district agent directly.
      final error = register(national, level: AgentLevel.district);
      expect(error, isNull);

      final added = service
          .childrenOf(national.id)
          .firstWhere((a) => a.level == AgentLevel.district);
      expect(added.parentId, national.id);
      // The skipped tiers really were skipped, not silently seeded.
      expect(service.descendantsOf(national.id), [added]);

      // The district agent's own downline still runs off its true tier —
      // assembly next, not region or state.
      expect(service.allowedChildLevels(added), [
        AgentLevel.assembly,
        AgentLevel.lsgd,
        AgentLevel.ward,
      ]);
    });

    test('descendantsOf gathers every generation below, not just the next tier', () {
      register(national);
      final region = service.childrenOf(national.id).first;
      register(region);
      final state = service.childrenOf(region.id).first;

      final all = service.descendantsOf(national.id);
      expect(all, containsAll([region, state]));
      expect(all.length, 2);
    });

    test('a chain can be built from national all the way down to ward', () {
      var parent = national;
      for (final level in [
        AgentLevel.region,
        AgentLevel.state,
        AgentLevel.district,
        AgentLevel.assembly,
        AgentLevel.lsgd,
        AgentLevel.ward,
      ]) {
        final error = register(parent);
        expect(error, isNull, reason: parent.level.label);
        parent = service.childrenOf(parent.id).first;
        expect(parent.level, level);
      }
      expect(service.allowedChildLevels(parent), isEmpty);
      expect(service.openPositionsUnder(parent), 0);
    });
  });

  group('registration field checks', () {
    test('names must be letters and at least two of them', () {
      expect(AgentService.validateName(''), isNotNull);
      expect(AgentService.validateName('A'), isNotNull);
      expect(AgentService.validateName('R2'), isNotNull);
      expect(AgentService.validateName('Ravi'), isNull);
      // Middle name is the one that may be blank.
      expect(AgentService.validateMiddleName(''), isNull);
      expect(AgentService.validateMiddleName('7'), isNotNull);
    });

    test('aadhaar is exactly twelve digits', () {
      expect(AgentService.validateAadhaar('12345678901'), isNotNull);
      expect(AgentService.validateAadhaar('1234abcd5678'), isNotNull);
      expect(AgentService.validateAadhaar('1234 5678 9012'), isNull);
      expect(AgentService.validateAadhaar('123456789012'), isNull);
    });

    test('PAN follows the five-letter, four-digit, one-letter shape', () {
      expect(AgentService.validatePan('ABCDE1234'), isNotNull);
      expect(AgentService.validatePan('ABCD12345F'), isNotNull);
      expect(AgentService.validatePan('abcde1234f'), isNull); // upper-cased
      expect(AgentService.validatePan('ABCDE1234F'), isNull);
    });

    test('PIN code is six digits and the account is 9–18', () {
      expect(AgentService.validatePincode('68200'), isNotNull);
      expect(AgentService.validatePincode('682001'), isNull);
      expect(AgentService.validateAccountNumber('12345678'), isNotNull);
      expect(AgentService.validateAccountNumber('123456789'), isNull);
      expect(AgentService.validateAccountNumber('1234567890123456789'), isNotNull);
    });
  });

  group('registering an agent', () {
    test('a valid submission lands under its parent, KYC and all', () {
      register(national); // seeds a region to register under
      final region = service.childrenOf(national.id).first;

      final error = register(region, first: 'Sanju', last: 'Pillai');
      expect(error, isNull);

      final added = service
          .childrenOf(region.id)
          .firstWhere((a) => a.name == 'Sanju Pillai');
      expect(added.level, AgentLevel.state);
      expect(added.parentId, region.id);
      expect(added.isRegistered, isTrue);
      expect(added.firstName, 'Sanju');
      expect(added.lastName, 'Pillai');
      expect(added.pan, 'ABCDE1234F');
      expect(added.maskedAadhaar, '•••• •••• 1234');
      expect(added.maskedAccount, '••••9012');
      // The first state ever minted on a fresh roster.
      expect(added.agentCode, 'SHD-STE-001');
      expect(added.earned, 0);
      // Registered, not yet vouched for.
      expect(added.approvalStatus, AgentApprovalStatus.pending);
    });

    test('the level must sit below the parent', () {
      final error = register(national, level: AgentLevel.national);
      expect(error, contains('not below'));
      expect(service.childrenOf(national.id), isEmpty);
    });

    test('a bad PAN is refused even if the screen let it through', () {
      final error = register(national, pan: 'NOTAPAN');
      expect(error, isNotNull);
      expect(service.roster.length, AgentDirectory.seed.length);
    });

    test('every position under a parent can be filled, and no more', () {
      expect(register(national), isNull);
      expect(register(national), isNull);
      final error = register(national);
      expect(error, 'Every position under ${national.name} is already filled');
      expect(service.childrenOf(national.id).length, 2);
    });

    test('reset drops registered agents', () {
      register(national);
      expect(service.roster.length, AgentDirectory.seed.length + 1);
      service.reset();
      expect(service.roster.length, AgentDirectory.seed.length);
    });
  });

  group('approval', () {
    test('every figure reads zero while an agent is pending', () {
      // The national persona carries real money, so there is something to
      // zero out — a fresh registration would already read zero either way.
      expect(national.earned, greaterThan(0));

      final pending = national.withApprovalStatus(AgentApprovalStatus.pending);
      expect(pending.displayEarned, 0);
      expect(pending.displayRedeemed, 0);
      expect(pending.displayPersonalSales, 0);
      // The underlying figures are untouched — approving later restores them
      // rather than having thrown them away.
      expect(pending.earned, national.earned);
    });

    test('setApproval moves a pending agent onto the roster as approved', () {
      register(national, first: 'Priya', last: 'Menon');
      final added = service
          .childrenOf(national.id)
          .firstWhere((a) => a.name == 'Priya Menon');
      expect(added.approvalStatus, AgentApprovalStatus.pending);
      expect(service.earnedFor(added), 0);

      service.setApproval(added, AgentApprovalStatus.approved);

      final approved = service.byId(added.id)!;
      expect(approved.approvalStatus, AgentApprovalStatus.approved);
      // Same identity, same KYC — approval changes nothing else about them.
      expect(approved.id, added.id);
      expect(approved.firstName, 'Priya');
    });

    test('a rejected agent can still be approved after all', () {
      register(national, first: 'Priya', last: 'Menon');
      final added = service
          .childrenOf(national.id)
          .firstWhere((a) => a.name == 'Priya Menon');

      service.setApproval(added, AgentApprovalStatus.rejected);
      expect(
        service.byId(added.id)!.approvalStatus,
        AgentApprovalStatus.rejected,
      );

      service.setApproval(added, AgentApprovalStatus.approved);
      expect(
        service.byId(added.id)!.approvalStatus,
        AgentApprovalStatus.approved,
      );
    });
  });

  group('withdrawals', () {
    test('the withdrawable balance is earned less redeemed', () {
      expect(
        service.withdrawableFor(national),
        national.earned - national.redeemed,
      );
    });

    test('a request under the minimum is refused', () {
      final error = service.requestWithdrawal(national, 100);
      expect(error, 'Minimum withdrawal is ₹500');
      expect(service.requestsFor(national), isEmpty);
    });

    test('a request over the withdrawable balance is refused', () {
      final error = service.requestWithdrawal(national, national.earned);
      expect(error, 'Amount exceeds your withdrawable balance');
      expect(service.requestsFor(national), isEmpty);
    });

    test('a valid request is held pending and reserves the amount', () {
      final before = service.withdrawableFor(national);

      final error = service.requestWithdrawal(national, 1000);
      expect(error, isNull);

      final requests = service.requestsFor(national);
      expect(requests, hasLength(1));
      expect(requests.first.amount, 1000);
      expect(requests.first.status, WithdrawalStatus.pending);
      expect(service.pendingFor(national), 1000);
      expect(service.withdrawableFor(national), before - 1000);
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

    testWidgets('an agent number swaps Refer & Earn for the Agent Portal', (
      tester,
    ) async {
      AuthService.instance.signInAs(phone: '9539810000');
      await pumpHome(tester);

      expect(find.byType(AgentPortalCard), findsOneWidget);
      expect(find.text('Agent Portal'), findsOneWidget);
      expect(find.byType(ReferEarnCard), findsNothing);
    });

    testWidgets('a member number keeps Refer & Earn', (tester) async {
      AuthService.instance.signInAs(phone: '9000000002');
      await pumpHome(tester);

      expect(find.byType(ReferEarnCard), findsOneWidget);
      expect(find.byType(AgentPortalCard), findsNothing);
    });

    testWidgets('the card opens the portal screen', (tester) async {
      AuthService.instance.signInAs(phone: '9539810000');
      await pumpHome(tester);

      await tester.tap(find.text('Agent Portal'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentPortalScreen), findsOneWidget);
    });
  });

  group('the portal screen', () {
    Future<void> pumpPortal(
      WidgetTester tester, {
      Size size = const Size(400, 3000),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: AgentPortalScreen(agent: national)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('leads with the earnings figures', (tester) async {
      await pumpPortal(tester);

      Finder onCard(String text) => find.descendant(
        of: find.byType(AgentEarningsCard),
        matching: find.text(text),
      );

      expect(find.text('Your earnings'), findsOneWidget);
      expect(onCard('EARNED'), findsOneWidget);
      expect(onCard('REDEEMED'), findsOneWidget);
      expect(onCard('MIN WITHDRAWAL'), findsOneWidget);
      expect(onCard('₹2,85,000'), findsOneWidget);
      expect(onCard('₹1,20,000'), findsOneWidget);
      expect(onCard('₹1,65,000'), findsOneWidget);
    });

    testWidgets('the earnings card turns over to the requests list', (
      tester,
    ) async {
      await pumpPortal(tester);

      expect(find.text('Withdrawal requests'), findsNothing);

      await tester.tap(find.text('Your earnings'));
      await tester.pumpAndSettle();

      expect(find.text('Withdrawal requests'), findsOneWidget);
      expect(find.textContaining('No withdrawal requests yet'), findsOneWidget);
    });

    testWidgets('a submitted withdrawal shows on the back of the card', (
      tester,
    ) async {
      await pumpPortal(tester);

      await tester.tap(find.text('Request withdrawal'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1000');
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();

      expect(find.text('Withdrawal request submitted'), findsOneWidget);
      expect(find.text('Withdrawal requests'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AgentEarningsCard),
          matching: find.text('₹1,000'),
        ),
        findsOneWidget,
      );
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('a below-minimum withdrawal is refused in the sheet', (
      tester,
    ) async {
      await pumpPortal(tester);

      await tester.tap(find.text('Request withdrawal'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '100');
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();

      expect(find.text('Minimum withdrawal is ₹500'), findsOneWidget);
      expect(service.requestsFor(national), isEmpty);
    });

    testWidgets('each customer is a two-section card: totals, then cards', (
      tester,
    ) async {
      await pumpPortal(tester);

      expect(find.text('Direct sale'), findsOneWidget);

      final customers = service.customersOf(national);
      expect(customers, isNotEmpty);
      final totalPlans = customers.fold<int>(0, (n, c) => n + c.planCount);

      Finder inSale(Finder m) => find.descendant(
        of: find.byType(AgentDirectSaleSection),
        matching: m,
      );

      // Section 1 on every customer card: NAME · TOTAL AMOUNT · TOTAL EARNED
      // as headed columns across one tinted band — no rules between them.
      expect(inSale(find.text('NAME')), findsNWidgets(customers.length));
      expect(inSale(find.text('TOTAL AMOUNT')), findsNWidgets(customers.length));
      expect(
        inSale(find.text('TOTAL EARNED')),
        findsNWidgets(customers.length),
      );
      expect(inSale(find.byType(VerticalDivider)), findsNothing);
      for (final c in customers) {
        expect(inSale(find.text(c.name)), findsOneWidget);
        expect(
          inSale(find.text('₹${formatRupees(c.totalAmount)}')),
          findsWidgets,
        );
        expect(
          inSale(
            find.text('₹${formatRupees(service.commissionOnSale(c))}'),
          ),
          findsWidgets,
        );
      }

      // A customer holding more than one card says so, as a tagged chip.
      final multi = customers.firstWhere((c) => c.hasMultiplePlans);
      expect(
        inSale(
          find.text(
            'Total ${multi.planCount} · Active ${multi.activePlans.length}',
          ),
        ),
        findsOneWidget,
      );

      // Section 2 opens on its own subhead: what it lists, and how many are
      // actually still active — never a blanket "active" label.
      expect(
        inSale(find.text('PLAN')),
        findsNWidgets(customers.where((c) => !c.hasMultiplePlans).length),
      );
      expect(
        inSale(find.text('PLANS')),
        findsNWidgets(customers.where((c) => c.hasMultiplePlans).length),
      );
      for (final c in customers) {
        expect(
          inSale(find.text('${c.activePlans.length} of ${c.planCount} active')),
          findsOneWidget,
          reason: c.name,
        );
      }

      // Section 2: one block per card — dates and a month graph.
      expect(inSale(find.text('ACTIVATED')), findsNWidgets(totalPlans));
      expect(
        find.byType(PlanTimeline),
        findsNWidgets(totalPlans),
      );
      expect(find.textContaining('RENEWS ON'), findsWidgets);
      expect(find.textContaining('EXPIRED ON'), findsWidgets);
      expect(find.textContaining('months left'), findsWidgets);
      expect(find.textContaining('unused'), findsWidgets);
    });

    testWidgets('a customer card opens the customer detail', (
      tester,
    ) async {
      await pumpPortal(tester);

      final customer = service.customersOf(national).first;
      await tester.tap(find.text(customer.name));
      await tester.pumpAndSettle();

      expect(find.byType(AgentCustomerDetailScreen), findsOneWidget);
      expect(find.text(customer.tier.name), findsWidgets);
      expect(
        find.text(formatDate(customer.plansByNewest.first.activatedOn)),
        findsWidgets,
      );
    });

    testWidgets('the team sales card folds open to a per-tier sales breakdown', (
      tester,
    ) async {
      register(national);
      final region = service.childrenOf(national.id).first;
      register(region, level: AgentLevel.state);
      await pumpPortal(tester, size: const Size(400, 6000));

      expect(find.textContaining('Team sales ₹'), findsOneWidget);
      expect(find.textContaining('Override commission'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('team-sales-card')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Override commission'), findsOneWidget);
      expect(find.text('Region'), findsOneWidget);
      expect(find.text('State'), findsOneWidget);
    });

    testWidgets('the team roster lists every member, and never folds away', (
      tester,
    ) async {
      register(national, first: 'Priya', last: 'Menon');
      await pumpPortal(tester, size: const Size(400, 6000));

      expect(find.text('All team members'), findsOneWidget);
      final team = service.teamOf(national);
      expect(team, isNotEmpty);
      for (final member in team) {
        expect(find.text(member.name), findsOneWidget, reason: member.name);
        expect(
          find.text('${member.level.label} · ${member.agentCode}'),
          findsOneWidget,
          reason: member.name,
        );
      }
    });

    testWidgets("each tier's roster is a table, footed with its totals", (
      tester,
    ) async {
      register(national);
      await pumpPortal(tester, size: const Size(400, 6000));

      // One header, and one totals row, per tier that has members.
      expect(find.text('AGENT'), findsWidgets);
      expect(find.text('PLANS'), findsWidgets);
      expect(find.text('AMOUNT'), findsWidgets);
      expect(find.text('EARNING'), findsWidgets);
      expect(find.text('Total'), findsWidgets);

      // The region tier's totals row adds up what its own agent earns — the
      // figure the table exists to answer.
      final region = service.childrenOf(national.id);
      final regionEarning = region.fold<int>(
        0,
        (sum, agent) => sum + service.commissionFrom(agent),
      );
      expect(find.text('₹${formatRupees(regionEarning)}'), findsWidgets);
    });

    testWidgets('tapping a team member in the roster opens their detail', (
      tester,
    ) async {
      register(national);
      await pumpPortal(tester, size: const Size(400, 6000));

      final member = service.teamOf(national).first;
      await tester.ensureVisible(find.text(member.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text(member.name));
      await tester.pumpAndSettle();

      expect(find.byType(AgentDetailScreen), findsOneWidget);
      expect(find.text(member.agentCode), findsOneWidget);
    });
  });

  group('customers', () {
    test('a card is active for a year from activation, then expires', () {
      final plan = service
          .customersOf(national)
          .expand((c) => c.plans)
          .firstWhere((p) => p.tier.name == 'Silver Shield');
      final justBefore = plan.expiresOn.subtract(const Duration(days: 1));
      final justAfter = plan.expiresOn.add(const Duration(days: 1));

      expect(plan.isActiveOn(plan.activatedOn), isTrue);
      expect(plan.isActiveOn(justBefore), isTrue);
      expect(plan.isActiveOn(justAfter), isFalse);
    });

    test('a customer can hold more than one card', () {
      final meera = service
          .customersOf(national)
          .firstWhere((c) => c.name == 'Meera Krishnan');
      expect(meera.planCount, 2);
      expect(meera.hasMultiplePlans, isTrue);
      expect(
        meera.totalAmount,
        meera.plans.fold<int>(0, (s, p) => s + p.amount),
      );
      expect(
        service.commissionOnSale(meera),
        meera.plans.fold<int>(0, (s, p) => s + service.commissionOnPlan(p)),
      );
    });

    test('customersOf sorts newest activation first', () {
      final customers = service.customersOf(national);
      for (var i = 1; i < customers.length; i++) {
        expect(
          !customers[i - 1].lastActivatedOn.isBefore(
            customers[i].lastActivatedOn,
          ),
          isTrue,
        );
      }
    });

    test('an agent with no sales has an empty customer list', () {
      register(national);
      final region = service.childrenOf(national.id).first;
      // Only the national persona carries seeded sales; a freshly registered
      // agent starts with none.
      expect(service.customersOf(region), isEmpty);
    });
  });

  group('my team', () {
    Future<void> pumpTree(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: AgentTeamTreeScreen(root: national)),
      );
      await tester.pumpAndSettle();
    }

    /// The default "opens on root" view spreads the full, fixed shape out
    /// far wider than any test viewport — most positions sit off past its
    /// edges, reachable by panning rather than by a direct tap. Shrinking to
    /// the whole-team overview first brings every position back within the
    /// viewport, so a targeted tap can still find it precisely.
    Future<void> fitWhole(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Fit whole team'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on a fresh roster showing the root and its open positions', (
      tester,
    ) async {
      await pumpTree(tester);

      expect(find.text(national.name), findsOneWidget);
      // Nobody has been registered yet — both region positions under the
      // root show as open slots, not names.
      expect(find.text('Region'), findsNWidgets(2));
      expect(find.byTooltip('Add a region agent here'), findsNWidgets(2));
    });

    testWidgets('opening on just the root, the mark renders at full size', (
      tester,
    ) async {
      await pumpTree(tester);

      // Regression guard for the chart opening shrunk to a speck in a sea of
      // empty space: the mark should render close to its natural size.
      final circle = tester.getSize(
        find.byKey(const ValueKey('node-circle-nat-001')),
      );
      expect(circle.width, greaterThan(30));
    });

    testWidgets('the whole fixed shape is visible from the start, all the way to ward', (
      tester,
    ) async {
      await pumpTree(tester);

      // Every tier the org shape holds is already drawn as open positions —
      // none of it waits behind a tap to be revealed.
      expect(find.text('Region'), findsNWidgets(2));
      expect(find.text('State'), findsNWidgets(4));
      expect(find.text('District'), findsNWidgets(8));
      expect(find.text('Assembly'), findsNWidgets(16));
      expect(find.text('LSGD'), findsNWidgets(32));
      expect(find.text('Ward'), findsNWidgets(64));
    });

    testWidgets('only the positions directly under a real agent can be tapped to fill', (
      tester,
    ) async {
      await pumpTree(tester);

      // The two region slots sit directly under the root — open right away.
      expect(find.byTooltip('Add a region agent here'), findsNWidgets(2));
      // Everything deeper is a preview of the shape, not yet actionable —
      // there is no real state, or ward, agent anywhere above it yet.
      expect(find.byTooltip('State position — not open yet'), findsNWidgets(4));
      expect(find.byTooltip('Ward position — not open yet'), findsNWidgets(64));
    });

    testWidgets('tapping an unfillable position explains what has to happen first', (
      tester,
    ) async {
      await pumpTree(tester);
      await fitWhole(tester);

      await tester.tap(
        find.byTooltip('State position — not open yet').first,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Register the Region above this position first'),
        findsOneWidget,
      );
      // Nothing was added.
      expect(service.roster.length, AgentDirectory.seed.length);
    });

    testWidgets('a card is led by a round profile head, not a squared badge', (
      tester,
    ) async {
      register(national, first: 'Priya', last: 'Menon');
      await pumpTree(tester);

      // Initials in a circle, the same mark the portal strip and an agent's
      // own detail card use — not the square lettered tag the roster lists
      // still carry.
      expect(find.text(national.initials), findsOneWidget);
      expect(find.text(national.level.code), findsNothing);
      final region = service.childrenOf(national.id).first;
      expect(find.text(region.initials), findsOneWidget);
      expect(find.text(region.level.code), findsNothing);
    });

    testWidgets('the corner button is offered to fit the whole team again', (
      tester,
    ) async {
      await pumpTree(tester);

      expect(find.byTooltip('Fit whole team'), findsOneWidget);
      await tester.tap(find.byTooltip('Fit whole team'));
      await tester.pumpAndSettle();

      expect(find.text(national.name), findsOneWidget);
    });

    testWidgets('a card folds its branch away and back', (tester) async {
      await pumpTree(tester);
      await fitWhole(tester);

      expect(find.text('Region'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Collapse ${national.name}'));
      await tester.pumpAndSettle();
      expect(find.text('Region'), findsNothing);

      await tester.tap(find.byTooltip('Expand ${national.name}'));
      await tester.pumpAndSettle();
      expect(find.text('Region'), findsNWidgets(2));
    });

    testWidgets('tapping a filled node opens that agent detail', (tester) async {
      register(national, first: 'Priya', last: 'Menon');
      await pumpTree(tester);
      await fitWhole(tester);

      await tester.tap(find.text('Priya Menon'));
      await tester.pumpAndSettle();

      final region = service
          .childrenOf(national.id)
          .firstWhere((a) => a.name == 'Priya Menon');
      expect(find.byType(AgentDetailScreen), findsOneWidget);
      expect(find.text(region.agentCode), findsOneWidget);
      expect(find.text('Team sales'), findsOneWidget);
    });

    testWidgets('tapping an open position opens registration pointed at the right parent', (
      tester,
    ) async {
      await pumpTree(tester);
      await fitWhole(tester);

      await tester.tap(find.byTooltip('Add a region agent here').first);
      await tester.pumpAndSettle();

      expect(find.byType(AgentRegistrationScreen), findsOneWidget);
      expect(find.text('Register an agent'), findsOneWidget);
      // The "Reports to" field opens already on the root — the slot's real
      // parent — not on a blank choice the recruiter has to make themselves.
      expect(
        find.textContaining('${national.name} · ${national.level.label}'),
        findsOneWidget,
      );
    });

    testWidgets('registering into a slot turns it into a card, and its own children open up', (
      tester,
    ) async {
      await pumpTree(tester);
      await fitWhole(tester);

      await tester.tap(find.byTooltip('Add a region agent here').first);
      await tester.pumpAndSettle();
      await submitRegistrationForm(tester, first: 'Priya', last: 'Menon');

      // Back on the tree: the slot is now a filled card…
      expect(find.text('Priya Menon'), findsOneWidget);
      // …the other region slot is still open…
      expect(find.byTooltip('Add a region agent here'), findsOneWidget);
      // …and the new agent's own two state positions are fillable in turn.
      expect(find.byTooltip('Add a state agent here'), findsNWidgets(2));
    });

    testWidgets('the toolbar add button also opens registration for the root', (
      tester,
    ) async {
      await pumpTree(tester);

      await tester.tap(find.byTooltip('Add agent'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentRegistrationScreen), findsOneWidget);
      expect(find.text('Register an agent'), findsOneWidget);
      // The KYC fields the flow captures.
      expect(find.text('Aadhaar number'), findsOneWidget);
      expect(find.text('PAN'), findsOneWidget);
      expect(find.text('Date of birth'), findsOneWidget);
      expect(find.text('Bank account number'), findsOneWidget);
    });
  });

  group('the registration screen', () {
    Future<void> pumpForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(460, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: AgentRegistrationScreen(
            scopeRoot: national,
            initialParent: national,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> fillField(
      WidgetTester tester,
      String hint,
      String value,
    ) async {
      final field = find.widgetWithText(TextFormField, hint);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    testWidgets('captures every field, verifies the OTP, and registers', (
      tester,
    ) async {
      await pumpForm(tester);

      await fillField(tester, 'First name', 'Priya');
      await fillField(tester, 'Last name', 'Menon');
      await fillField(tester, '10-digit mobile number', '9812345670');
      await fillField(tester, '12-digit Aadhaar', '123412341234');
      await fillField(tester, 'ABCDE1234F', 'ABCDE1234F');
      await fillField(tester, 'House / street / locality', '4 Fort Road');
      await fillField(tester, '6 digits', '682001');
      await fillField(tester, 'Town / village', 'Fort Kochi');
      await fillField(
        tester,
        'Account the commission is paid into',
        '123456789012',
      );

      // Date of birth through the picker, reached from the field's icon.
      await tester.ensureVisible(find.byIcon(Icons.event_rounded));
      await tester.tap(find.byIcon(Icons.event_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Send OTP'));
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();

      // On the verify step now.
      expect(find.text('Verify the mobile number'), findsOneWidget);

      await tester.enterText(find.byType(TextField), AuthService.demoOtp);
      await tester.pumpAndSettle();

      // Screen has popped and the agent is on the roster, fully registered.
      expect(find.byType(AgentRegistrationScreen), findsNothing);
      final added = service.childrenOf(national.id).firstWhere(
        (a) => a.name == 'Priya Menon',
      );
      expect(added.level, AgentLevel.region);
      expect(added.isRegistered, isTrue);
      expect(added.place, 'Fort Kochi');
      expect(added.pincode, '682001');
    });

    testWidgets('the level field offers every tier below the parent, not just the next one', (
      tester,
    ) async {
      await pumpForm(tester);

      // Defaults to the immediate next tier…
      expect(find.text('Region'), findsOneWidget);

      // …but every deeper tier is offered too, so national can recruit
      // straight into one of them without first seeding the tiers between.
      await tester.tap(find.byType(DropdownButtonFormField<AgentLevel>));
      await tester.pumpAndSettle();
      expect(find.text('District'), findsOneWidget);
      expect(find.text('Ward'), findsOneWidget);

      await tester.tap(find.text('District'));
      await tester.pumpAndSettle();

      await fillField(tester, 'First name', 'Priya');
      await fillField(tester, 'Last name', 'Menon');
      await fillField(tester, '10-digit mobile number', '9812345670');
      await fillField(tester, '12-digit Aadhaar', '123412341234');
      await fillField(tester, 'ABCDE1234F', 'ABCDE1234F');
      await fillField(tester, 'House / street / locality', '4 Fort Road');
      await fillField(tester, '6 digits', '682001');
      await fillField(tester, 'Town / village', 'Fort Kochi');
      await fillField(
        tester,
        'Account the commission is paid into',
        '123456789012',
      );
      await tester.ensureVisible(find.byIcon(Icons.event_rounded));
      await tester.tap(find.byIcon(Icons.event_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send OTP'));
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), AuthService.demoOtp);
      await tester.pumpAndSettle();

      final added = service
          .childrenOf(national.id)
          .firstWhere((a) => a.name == 'Priya Menon');
      expect(added.level, AgentLevel.district);
      // No region or state was seeded along the way.
      expect(service.descendantsOf(national.id), [added]);
    });

    testWidgets('the wrong OTP is rejected and nothing is registered', (
      tester,
    ) async {
      await pumpForm(tester);

      await fillField(tester, 'First name', 'Priya');
      await fillField(tester, 'Last name', 'Menon');
      await fillField(tester, '10-digit mobile number', '9812345670');
      await fillField(tester, '12-digit Aadhaar', '123412341234');
      await fillField(tester, 'ABCDE1234F', 'ABCDE1234F');
      await fillField(tester, 'House / street / locality', '4 Fort Road');
      await fillField(tester, '6 digits', '682001');
      await fillField(tester, 'Town / village', 'Fort Kochi');
      await fillField(
        tester,
        'Account the commission is paid into',
        '123456789012',
      );
      await tester.ensureVisible(find.byIcon(Icons.event_rounded));
      await tester.tap(find.byIcon(Icons.event_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send OTP'));
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '000000');
      await tester.pumpAndSettle();

      expect(find.textContaining('code is incorrect'), findsOneWidget);
      expect(find.byType(AgentRegistrationScreen), findsOneWidget);
      expect(service.roster.length, AgentDirectory.seed.length);
    });

    testWidgets('incomplete details never reach the OTP step', (tester) async {
      await pumpForm(tester);

      await tester.ensureVisible(find.text('Send OTP'));
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();

      expect(find.text('Verify the mobile number'), findsNothing);
      expect(find.text('Enter the first name'), findsOneWidget);
    });

    testWidgets('offers an optional profile photo, and registers without one', (
      tester,
    ) async {
      await pumpForm(tester);

      // The photo affordance is on the form, marked optional.
      expect(find.text('Add profile photo'), findsOneWidget);
      expect(find.text('Optional'), findsOneWidget);

      // Nothing forces a photo — a full submission with none still goes
      // through, and the agent simply carries no photo bytes.
      await fillField(tester, 'First name', 'Priya');
      await fillField(tester, 'Last name', 'Menon');
      await fillField(tester, '10-digit mobile number', '9812345670');
      await fillField(tester, '12-digit Aadhaar', '123412341234');
      await fillField(tester, 'ABCDE1234F', 'ABCDE1234F');
      await fillField(tester, 'House / street / locality', '4 Fort Road');
      await fillField(tester, '6 digits', '682001');
      await fillField(tester, 'Town / village', 'Fort Kochi');
      await fillField(
        tester,
        'Account the commission is paid into',
        '123456789012',
      );
      await tester.ensureVisible(find.byIcon(Icons.event_rounded));
      await tester.tap(find.byIcon(Icons.event_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send OTP'));
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), AuthService.demoOtp);
      await tester.pumpAndSettle();

      final added = service
          .childrenOf(national.id)
          .firstWhere((a) => a.name == 'Priya Menon');
      expect(added.photoBytes, isNull);
    });
  });

  group('the detail screen', () {
    testWidgets('shows KYC for a registered agent and offers to add one', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(460, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      register(national, level: AgentLevel.region, first: 'Priya', last: 'Menon');
      final added = service
          .childrenOf(national.id)
          .firstWhere((a) => a.name == 'Priya Menon');
      // A fresh registration is pending — recruiting under them opens up
      // once national approves, the same as it would from national's own
      // detail screen.
      service.setApproval(added, AgentApprovalStatus.approved);

      await tester.pumpWidget(
        MaterialApp(home: AgentDetailScreen(agent: added)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Registration'), findsOneWidget);
      expect(find.text('•••• •••• 1234'), findsOneWidget);
      expect(find.text('ABCDE1234F'), findsOneWidget);
      expect(find.text('Add an agent under Priya Menon'), findsOneWidget);
    });

    testWidgets('a seed agent has no registration card', (tester) async {
      tester.view.physicalSize = const Size(460, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: AgentDetailScreen(agent: national)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Registration'), findsNothing);
    });

    testWidgets('a ward agent is not offered a sub-agent', (tester) async {
      tester.view.physicalSize = const Size(460, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var parent = national;
      for (var i = 0; i < 6; i++) {
        register(parent);
        parent = service.childrenOf(parent.id).first;
      }
      final ward = parent;
      expect(ward.level, AgentLevel.ward);

      await tester.pumpWidget(
        MaterialApp(home: AgentDetailScreen(agent: ward)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Add an agent under'), findsNothing);
    });

    testWidgets(
      'a pending agent shows the approval banner and reads zero',
      (tester) async {
        tester.view.physicalSize = const Size(460, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        register(national, first: 'Priya', last: 'Menon');
        final added = service
            .childrenOf(national.id)
            .firstWhere((a) => a.name == 'Priya Menon');

        await tester.pumpWidget(
          MaterialApp(home: AgentDetailScreen(agent: added)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Awaiting your approval'), findsOneWidget);
        expect(find.text('Pending approval'), findsOneWidget);
        expect(find.text('Approve'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);
        expect(find.textContaining('Add an agent under'), findsNothing);
      },
    );

    testWidgets('tapping Approve unlocks recruiting under the agent', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(460, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      register(national, first: 'Priya', last: 'Menon');
      final added = service
          .childrenOf(national.id)
          .firstWhere((a) => a.name == 'Priya Menon');

      await tester.pumpWidget(
        MaterialApp(home: AgentDetailScreen(agent: added)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(service.byId(added.id)!.approvalStatus, AgentApprovalStatus.approved);
      expect(find.text('Priya Menon approved'), findsOneWidget);
      expect(find.text('Awaiting your approval'), findsNothing);
      expect(find.text('Add an agent under Priya Menon'), findsOneWidget);
    });

    testWidgets('the profile photo is read-only here — no picker affordance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(460, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: AgentDetailScreen(agent: national)),
      );
      await tester.pumpAndSettle();

      // The header avatar shows, but nothing on this screen opens a picker or
      // clears the photo — that lives only on the registration screen.
      expect(find.byIcon(Icons.camera_alt_rounded), findsNothing);
      expect(find.bySemanticsLabel(RegExp('profile photo')), findsNothing);
    });
  });

  group('the earnings card in isolation', () {
    testWidgets('the request button is enabled with a balance to draw', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AgentEarningsCard(agent: national))),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Request withdrawal'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });
  });
}
