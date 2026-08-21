import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/approvals/approval.dart';
import 'package:shield/module/approvals/approvals_screen.dart';

void main() {
  setUp(ApprovalService.instance.reset);
  tearDown(ApprovalService.instance.reset);

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(400, 3000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: ApprovalsScreen()));
    await tester.pumpAndSettle();
  }

  group('the approval', () {
    test('the total is the sum of its lines', () {
      final approval = ApprovalService.instance.byId('a1')!;

      expect(approval.itemCount, 2);
      expect(approval.total, 58 + 104);
    });

    test('a changed line is flagged, an unchanged one is not', () {
      final approval = ApprovalService.instance.byId('a1')!;

      expect(approval.hasChanges, isTrue);
      expect(approval.items.first.isChanged, isTrue);
      expect(approval.items.last.isChanged, isFalse);

      // A straight fill has nothing to read.
      expect(ApprovalService.instance.byId('a3')!.hasChanges, isFalse);
    });
  });

  group('the service', () {
    test('splits what is waiting from what is settled', () {
      final service = ApprovalService.instance;

      expect(service.pendingCount, 2);
      expect(service.awaiting.every((a) => a.isAwaiting), isTrue);
      expect(service.settled.every((a) => !a.isAwaiting), isTrue);
      expect(
        service.awaiting.length + service.settled.length,
        service.approvals.length,
      );
    });

    test('approving moves it out of the queue', () {
      final service = ApprovalService.instance;

      service.approve('a1');

      expect(service.byId('a1')?.status, ApprovalStatus.approved);
      expect(service.pendingCount, 1);
      expect(service.settled.any((a) => a.id == 'a1'), isTrue);
    });

    test('declining is recorded rather than discarded', () {
      final service = ApprovalService.instance;

      service.decline('a2');

      expect(service.byId('a2')?.status, ApprovalStatus.declined);
      expect(service.pendingCount, 1);
      expect(service.approvals.length, 3, reason: 'nothing is deleted');
    });

    test('a settled request cannot be answered twice', () {
      final service = ApprovalService.instance;

      service.approve('a1');
      service.decline('a1');

      expect(
        service.byId('a1')?.status,
        ApprovalStatus.approved,
        reason: 'a stale screen must not overwrite a decision already made',
      );
    });

    test('an unknown id does nothing', () {
      final service = ApprovalService.instance;
      service.approve('nope');

      expect(service.pendingCount, 2);
    });
  });

  group('the screen', () {
    testWidgets('counts what is waiting and says nothing is charged yet', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('2 orders need your approval'), findsOneWidget);
      expect(
        find.text('Nothing is dispensed or charged until you say yes.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the lines, the substitution and the total', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('SHD-100517'), findsOneWidget);
      expect(find.text('Calpol 650mg Tablet'), findsOneWidget);
      expect(
        find.text('Substituted for Dolo 650mg — same salt'),
        findsOneWidget,
      );
      expect(find.textContaining('out of stock at your store'), findsOneWidget);
      expect(find.text('₹162'), findsOneWidget);
    });

    testWidgets('keeps the answered ones below, as a record', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Already answered'), findsOneWidget);
      expect(find.text('SHD-100482'), findsOneWidget);
      expect(find.text(ApprovalStatus.approved.shortLabel), findsOneWidget);
    });

    testWidgets('approving answers it and drops the buttons', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Approve & dispense').first);
      await tester.pumpAndSettle();

      expect(
        ApprovalService.instance.byId('a1')?.status,
        ApprovalStatus.approved,
      );
      expect(find.textContaining('SHD-100517 approved'), findsOneWidget);
      expect(find.text('1 order needs your approval'), findsOneWidget);
      expect(find.text('Approve & dispense'), findsOneWidget);
    });

    testWidgets('declining says a pharmacist will call', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Decline').first);
      await tester.pumpAndSettle();

      expect(
        ApprovalService.instance.byId('a1')?.status,
        ApprovalStatus.declined,
      );
      expect(find.textContaining('the pharmacist will call'), findsOneWidget);
    });

    testWidgets('an empty queue reads as all clear, not as an error', (
      tester,
    ) async {
      ApprovalService.instance
        ..approve('a1')
        ..approve('a2');
      await pumpScreen(tester);

      expect(find.text('Nothing waiting on you'), findsOneWidget);
      expect(find.text('All caught up'), findsOneWidget);
      expect(find.text('Approve & dispense'), findsNothing);
    });

    testWidgets('lays out on a narrow phone', (tester) async {
      await pumpScreen(tester, size: const Size(320, 3800));

      expect(find.text('SHD-100517'), findsOneWidget);
      expect(find.text('Decline'), findsNWidgets(2));
    });
  });
}
