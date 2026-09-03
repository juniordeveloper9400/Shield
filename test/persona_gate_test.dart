import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/auth/persona_gate.dart';
import 'package:shield/screens/app_shell.dart';
import 'package:shield/screens/persona_web_only_screen.dart';
import 'package:shield/screens/root_screen.dart';
import 'package:shield/screens/splash_screen.dart';

import 'support/fake_catalogue.dart';

void main() {
  setUp(() {
    seedFakeCatalogue();
    AuthService.instance.reset();
    PersonaGate.instance.debugReset();
  });
  tearDown(() {
    resetFakeCatalogue();
    AuthService.instance.reset();
    PersonaGate.instance.debugReset();
    PersonaWebOnlyScreen.resetOpenerForTest();
  });

  Future<void> pumpRoot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: RootScreen(splashDuration: Duration(milliseconds: 20)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();
  }

  testWidgets('a plain member lands in the app shell', (tester) async {
    AuthService.instance.signInAs();
    PersonaGate.instance.debugSet(PersonaStatus.member);

    await pumpRoot(tester);

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(PersonaWebOnlyScreen), findsNothing);
  });

  testWidgets('an agent is sent to the web-only screen, not the shell', (
    tester,
  ) async {
    AuthService.instance.signInAs();
    PersonaGate.instance.debugSet(PersonaStatus.agent);

    await pumpRoot(tester);

    expect(find.byType(AppShell), findsNothing);
    expect(find.byType(PersonaWebOnlyScreen), findsOneWidget);
    expect(find.text("You're now a SHIELD Agent"), findsOneWidget);
    expect(
      find.text('https://shield-webapp-xq85.vercel.app/'),
      findsOneWidget,
    );
  });

  testWidgets('an investor sees the investor wording', (tester) async {
    AuthService.instance.signInAs();
    PersonaGate.instance.debugSet(PersonaStatus.investor);

    await pumpRoot(tester);

    expect(find.byType(PersonaWebOnlyScreen), findsOneWidget);
    expect(find.text("You're now a SHIELD Investor"), findsOneWidget);
  });

  testWidgets('"Open the web app" launches the portal URL', (tester) async {
    final opened = <Uri>[];
    PersonaWebOnlyScreen.opener = (uri) async {
      opened.add(uri);
      return true;
    };

    AuthService.instance.signInAs();
    PersonaGate.instance.debugSet(PersonaStatus.agent);
    await pumpRoot(tester);

    await tester.tap(find.text('Open the web app'));
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse('https://shield-webapp-xq85.vercel.app/')]);
  });

  testWidgets('the copy button puts the link on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    AuthService.instance.signInAs();
    PersonaGate.instance.debugSet(PersonaStatus.agent);
    await pumpRoot(tester);

    await tester.tap(find.byTooltip('Copy link'));
    await tester.pumpAndSettle();

    expect(copied, 'https://shield-webapp-xq85.vercel.app/');
  });

  testWidgets('logging out from the web-only screen returns to sign-in', (
    tester,
  ) async {
    AuthService.instance.signInAs();
    PersonaGate.instance.debugSet(PersonaStatus.agent);
    await pumpRoot(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.byType(PersonaWebOnlyScreen), findsNothing);
    expect(AuthService.instance.isSignedIn, isFalse);
  });

  testWidgets('the check has to settle before the shell shows', (tester) async {
    AuthService.instance.signInAs();
    // Left in the "checking" state — no debugSet to member/agent.
    PersonaGate.instance.debugSet(PersonaStatus.checking);

    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: RootScreen(splashDuration: Duration(milliseconds: 20)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));

    // Splash is held while the persona is unknown — the shell is not built.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    PersonaGate.instance.debugSet(PersonaStatus.member);
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
  });

  test('PersonaGate fails open when the look-up is unavailable', () async {
    // No DATABASE_URL is compiled into the test binary, so the repository read
    // resolves to "no persona" rather than throwing.
    AuthService.instance.signInAs(phone: '9000000123');
    await PersonaGate.instance.ensureChecked();

    expect(PersonaGate.instance.status, PersonaStatus.member);
    expect(PersonaGate.instance.isBlocked, isFalse);
  });
}
