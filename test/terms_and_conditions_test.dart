import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/account/account_screen.dart';
import 'package:shield/module/account/terms_and_conditions_screen.dart';
import 'package:shield/module/auth/auth_service.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  setUp(() {
    AuthService.instance.reset();
  });
  tearDown(() {
    AuthService.instance.reset();
  });

  testWidgets('the account menu offers Terms & Conditions', (tester) async {
    AuthService.instance.signInAs();

    await pump(tester, const AccountScreen());

    expect(find.text('Terms & Conditions'), findsOneWidget);
  });

  testWidgets('tapping it opens the Terms & Conditions document', (
    tester,
  ) async {
    AuthService.instance.signInAs();
    await pump(tester, const AccountScreen());

    await tester.tap(find.text('Terms & Conditions'));
    await tester.pumpAndSettle();

    expect(find.byType(TermsAndConditionsScreen), findsOneWidget);
    // First and last clause headings, confirming the whole numbered
    // document rendered rather than an empty page.
    expect(find.text('1. Acceptance of these terms'), findsOneWidget);
    expect(find.text('16. Contact us'), findsOneWidget);
  });

  testWidgets('the document shows a last-updated date', (tester) async {
    AuthService.instance.signInAs();
    await pump(tester, const TermsAndConditionsScreen());

    expect(find.textContaining('Last updated:'), findsOneWidget);
  });
}
