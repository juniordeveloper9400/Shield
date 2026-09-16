import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/account/account_screen.dart';
import 'package:shield/module/auth/auth_service.dart';

import 'support/fake_auth_gateway.dart';

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

  testWidgets('the account menu offers Delete Account, below Log out', (
    tester,
  ) async {
    AuthService.instance.signInAs();

    await pump(tester, const AccountScreen());

    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
  });

  testWidgets('the confirm button stays off until DELETE is typed', (
    tester,
  ) async {
    AuthService.instance.signInAs();
    await pump(tester, const AccountScreen());

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsOneWidget);

    Finder confirmButton() => find.widgetWithText(TextButton, 'Delete Account');

    expect(tester.widget<TextButton>(confirmButton()).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(
      tester.widget<TextButton>(confirmButton()).onPressed,
      isNotNull,
      reason: 'the check is case-insensitive',
    );

    await tester.enterText(find.byType(TextField), 'depete');
    await tester.pump();
    expect(tester.widget<TextButton>(confirmButton()).onPressed, isNull);
  });

  testWidgets('cancel closes the dialog and leaves the account untouched', (
    tester,
  ) async {
    AuthService.instance.signInAs();
    await pump(tester, const AccountScreen());

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsNothing);
    expect(AuthService.instance.isSignedIn, isTrue);
  });

  testWidgets('confirming deletes the account and the gate returns to login', (
    tester,
  ) async {
    AuthService.instance.useGateway(FakeAuthGateway());
    AuthService.instance.signInAs();
    await pump(tester, const AccountScreen());

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
    await tester.pumpAndSettle();

    expect(
      find.text('Delete your account?'),
      findsNothing,
      reason: 'the dialog closes itself once deletion finishes',
    );
    expect(AuthService.instance.isSignedIn, isFalse);
  });
}
