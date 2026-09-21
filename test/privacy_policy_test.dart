import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/account/account_screen.dart';
import 'package:shield/module/account/privacy_policy_screen.dart';
import 'package:shield/module/account/terms_and_conditions_screen.dart';
import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/auth/legal_note.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  setUp(() => AuthService.instance.reset());
  tearDown(() => AuthService.instance.reset());

  group('Account menu', () {
    testWidgets('offers a Privacy Policy, beside Terms & Conditions', (tester) async {
      AuthService.instance.signInAs();

      await pump(tester, const AccountScreen());

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
    });

    testWidgets('tapping it opens the policy inside the app', (tester) async {
      AuthService.instance.signInAs();
      await pump(tester, const AccountScreen());

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      expect(find.text('1. Information we collect'), findsOneWidget);
    });
  });

  group('the policy', () {
    testWidgets('shows every section, from the first to the contact details', (tester) async {
      await pump(tester, const PrivacyPolicyScreen());

      for (final heading in [
        '1. Information we collect',
        '2. How we use your information',
        '3. Who we share information with',
        '4. Data security',
        '5. Data retention',
        '6. Your choices and rights',
        '7. Children’s privacy',
        '8. Changes to this policy',
        '9. Contact us',
      ]) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      expect(find.text(privacyContactEmail), findsOneWidget);
    });

    testWidgets('shows a last-updated date and names the product', (tester) async {
      await pump(tester, const PrivacyPolicyScreen());

      expect(find.textContaining('Last updated:'), findsOneWidget);
      expect(find.textContaining('Sahakar 360'), findsWidgets);
      expect(find.textContaining('SHIELD'), findsNothing);
    });

    testWidgets('lays out on a narrow phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('the sign-in note', () {
    /// The tappable spans of the note, by their text — a widget test cannot
    /// tap into part of a paragraph, so this calls the tap handler directly.
    void tapSpan(WidgetTester tester, String text) {
      final rich = tester.widget<RichText>(
        find.descendant(
          of: find.byType(TermsAndPrivacyNote),
          matching: find.byType(RichText),
        ),
      );
      // Text.rich wraps the note in one more span, so walk them all.
      final spans = <TextSpan>[];
      rich.text.visitChildren((span) {
        if (span is TextSpan) spans.add(span);
        return true;
      });
      final span = spans.firstWhere((s) => s.text == text);
      (span.recognizer! as TapGestureRecognizer).onTap!();
    }

    testWidgets('reads the same, with both names underlined as links', (tester) async {
      await pump(tester, const Scaffold(body: Center(child: TermsAndPrivacyNote())));

      expect(
        find.textContaining(
          'By continuing you agree to the Terms of Use and Privacy Policy.',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('“Privacy Policy” opens the policy', (tester) async {
      await pump(tester, const Scaffold(body: Center(child: TermsAndPrivacyNote())));

      tapSpan(tester, 'Privacy Policy');
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    });

    testWidgets('“Terms of Use” opens the terms', (tester) async {
      await pump(tester, const Scaffold(body: Center(child: TermsAndPrivacyNote())));

      tapSpan(tester, 'Terms of Use');
      await tester.pumpAndSettle();

      expect(find.byType(TermsAndConditionsScreen), findsOneWidget);
    });
  });
}
