import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/investment/investment_plan_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: InvestmentPlanScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the headline, figures and plan points', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Investment Plan'), findsOneWidget); // app bar
    expect(find.text('The Investment Plan'), findsOneWidget); // header card
    expect(find.text('100% ASSURED ROI'), findsOneWidget);
    expect(find.text('₹1.5L'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    await scrollTo(tester, find.text('Assured and Secure Investment'));
    await scrollTo(tester, find.text('Exclusive Healthcare Benefits'));
    await scrollTo(tester, find.text('Minimum Investment'));
    await scrollTo(tester, find.text('Additional Medical Benefits'));
  });

  testWidgets('Get Equity confirms interest', (tester) async {
    await pumpScreen(tester);

    await scrollTo(tester, find.text('Get Equity'));
    await tester.tap(find.text('Get Equity'));
    await tester.pump(); // schedule the snack bar
    await tester.pump(const Duration(milliseconds: 300)); // let it animate in

    expect(find.textContaining('our team will reach out'), findsOneWidget);
  });
}
