import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/auth/login_screen.dart';
import 'package:shield/module/auth/otp_field.dart';
import 'package:shield/module/cart/cart_screen.dart';
import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/registration/registration_service.dart';
import 'package:shield/screens/app_shell.dart';
import 'package:shield/screens/root_screen.dart';
import 'package:shield/screens/splash_screen.dart';

void main() {
  setUp(() {
    AuthService.instance.reset();
    CartService.instance.reset();
    RegistrationService.instance.reset();
  });
  tearDown(() {
    AuthService.instance.reset();
    CartService.instance.reset();
    RegistrationService.instance.reset();
  });

  const name = 'Asha Nair';
  const phone = '9000012345';

  Future<void> fill(WidgetTester tester, String hint, String value) async {
    await tester.enterText(find.widgetWithText(TextFormField, hint), value);
    await tester.pump();
  }

  Future<void> fillName(WidgetTester tester, [String value = name]) =>
      fill(tester, 'Enter your name', value);

  Future<void> fillPhone(WidgetTester tester, [String value = phone]) =>
      fill(tester, '10-digit mobile number', value);

  /// The stand-in round trips are plain delays rather than animations, so
  /// `pumpAndSettle` alone would return with them still in flight.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    // The code step has no other input, and OtpField hides one real field
    // behind the boxes.
    await tester.enterText(find.byType(TextField).last, code);
    await settle(tester);
  }

  Future<void> requestCode(WidgetTester tester) async {
    await fillName(tester);
    await fillPhone(tester);
    await tester.tap(find.text('Get OTP'));
    await settle(tester);
  }

  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> pumpRoot(
    WidgetTester tester, {
    Size size = const Size(400, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: RootScreen(splashDuration: const Duration(milliseconds: 20)),
      ),
    );
  }

  Future<void> pumpCart(
    WidgetTester tester, {
    Size size = const Size(400, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Checkout also offers registration; these cases are about the auth gate,
    // so the registration prompt is stood down to keep them to one subject.
    RegistrationService.instance.dismissPrompt();

    // An empty cart hides the checkout bar, so a line has to exist before the
    // guard can be exercised.
    CartService.instance.add(
      name: 'Dolo 650mg Tablet',
      pack: 'Strip of 15 tablets',
      price: 32.5,
    );

    await tester.pumpWidget(const MaterialApp(home: CartScreen()));
    await tester.pumpAndSettle();
  }

  group('auth service', () {
    test('a requested code signs the member in once verified', () {
      final auth = AuthService.instance;

      expect(auth.requestOtp(name: name, phone: phone), isNull);
      expect(auth.hasPendingOtp, isTrue);
      expect(auth.pendingName, name);
      expect(auth.pendingPhone, phone);
      expect(auth.isSignedIn, isFalse, reason: 'the code is not verified yet');

      expect(auth.verifyOtp(AuthService.demoOtp), isNull);
      expect(auth.isSignedIn, isTrue);
      expect(auth.currentUser.value?.name, name);
      expect(auth.currentUser.value?.phone, phone);
      expect(auth.hasPendingOtp, isFalse);
    });

    test('a wrong code keeps the member out and the request alive', () {
      final auth = AuthService.instance;
      auth.requestOtp(name: name, phone: phone);

      expect(auth.verifyOtp('000000'), OtpError.wrongOtp);
      expect(auth.isSignedIn, isFalse);
      expect(
        auth.hasPendingOtp,
        isTrue,
        reason: 'a mistyped code must not force the number to be re-entered',
      );

      expect(auth.verifyOtp(AuthService.demoOtp), isNull);
      expect(auth.isSignedIn, isTrue);
    });

    test('verifying without a request is refused', () {
      expect(
        AuthService.instance.verifyOtp(AuthService.demoOtp),
        OtpError.noPendingRequest,
      );
      expect(AuthService.instance.isSignedIn, isFalse);
    });

    test('a bad name or number never reaches the code step', () {
      final auth = AuthService.instance;

      expect(auth.requestOtp(name: 'A', phone: phone), OtpError.invalidName);
      expect(
        auth.requestOtp(name: name, phone: '12345'),
        OtpError.invalidPhone,
      );
      expect(
        auth.requestOtp(name: name, phone: '1234567890'),
        OtpError.invalidPhone,
        reason: 'mobile numbers start with 6-9',
      );
      expect(auth.hasPendingOtp, isFalse);
    });

    test('the name and number are trimmed on the way in', () {
      AuthService.instance.requestOtp(name: '  Asha Nair  ', phone: ' $phone ');
      AuthService.instance.verifyOtp(AuthService.demoOtp);

      expect(AuthService.instance.currentUser.value?.name, name);
      expect(AuthService.instance.currentUser.value?.phone, phone);
    });

    test('signing out clears the session and anything half-finished', () {
      final auth = AuthService.instance;
      auth.signInAs();
      expect(auth.isSignedIn, isTrue);

      auth.logOut();
      expect(auth.isSignedIn, isFalse);
      expect(auth.hasPendingOtp, isFalse);
    });

    test('going back from the code step drops the pending request', () {
      final auth = AuthService.instance;
      auth.requestOtp(name: name, phone: phone);
      auth.cancelOtp();

      expect(auth.hasPendingOtp, isFalse);
      expect(auth.verifyOtp(AuthService.demoOtp), OtpError.noPendingRequest);
    });

    test('a member is displayed by their initials and number', () {
      const user = AuthUser(name: 'asha priya nair', phone: phone);
      expect(user.initials, 'AP');
      expect(user.displayPhone, '+91 $phone');
      expect(const AuthUser(name: 'Asha', phone: phone).initials, 'A');
    });

    test('the validators name what is wrong', () {
      expect(AuthService.validateName(''), 'Name is required');
      expect(AuthService.validateName('A'), 'Enter at least 2 characters');
      expect(AuthService.validateName('Asha 9'), 'Use letters only');
      expect(AuthService.validateName("Asha O'Neil"), isNull);

      expect(AuthService.validatePhone(''), 'Mobile number is required');
      expect(
        AuthService.validatePhone('12345'),
        'Enter a valid 10-digit number',
      );
      expect(
        AuthService.validatePhone('1234567890'),
        'Mobile numbers start with 6-9',
      );
      expect(AuthService.validatePhone(phone), isNull);
    });
  });

  group('the launch gate', () {
    testWidgets('shows the logo alone, with no wordmark', (tester) async {
      await pumpRoot(tester);

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(
        find.text('SHIELD'),
        findsNothing,
        reason: 'the splash carries the mark only',
      );
    });

    testWidgets('the splash gives way to the login screen, not the app', (
      tester,
    ) async {
      await pumpRoot(tester);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.byType(AppShell),
        findsNothing,
        reason: 'nothing below the gate may be built before signing in',
      );
      expect(find.text('Sign in to SHIELD'), findsOneWidget);
    });

    testWidgets('the gate cannot be dismissed', (tester) async {
      await pumpRoot(tester);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();

      // No close affordance, and no way back to an app that was never built.
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.byType(AppShell), findsNothing);
      expect(AuthService.instance.isSignedIn, isFalse);
    });

    testWidgets('an existing session goes straight to the app', (tester) async {
      AuthService.instance.signInAs();

      await pumpRoot(tester);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('signing out drops back to the gate', (tester) async {
      AuthService.instance.signInAs();

      await pumpRoot(tester);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();

      AuthService.instance.logOut();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('signing in at the gate opens the app', (tester) async {
      await pumpRoot(tester);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();

      await requestCode(tester);
      await enterCode(tester, AuthService.demoOtp);

      expect(AuthService.instance.isSignedIn, isTrue);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });
  });

  group('the login screen', () {
    testWidgets('asks for the name first and hides the number', (tester) async {
      await pumpLogin(tester);

      expect(find.text('Full name'), findsOneWidget);
      expect(
        find.text('Mobile number'),
        findsNothing,
        reason: 'the number is a second question, not a second field',
      );
    });

    testWidgets('filling the name reveals the number field', (tester) async {
      await pumpLogin(tester);

      await fillName(tester);
      await tester.pumpAndSettle();

      expect(find.text('Mobile number'), findsOneWidget);
      expect(find.text('+91  '), findsOneWidget);
    });

    testWidgets('a name too short to use keeps the number hidden', (
      tester,
    ) async {
      await pumpLogin(tester);

      await fillName(tester, 'A');
      await tester.pumpAndSettle();

      expect(find.text('Mobile number'), findsNothing);
      expect(find.text('Enter at least 2 characters'), findsOneWidget);
    });

    testWidgets('Get OTP stays inert until both answers are valid', (
      tester,
    ) async {
      await pumpLogin(tester);
      await fillName(tester);
      await tester.pumpAndSettle();

      await fillPhone(tester, '12345');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get OTP'));
      await settle(tester);

      expect(
        find.text('Verify your number'),
        findsNothing,
        reason: 'a half-typed number must not send a code',
      );
      expect(AuthService.instance.hasPendingOtp, isFalse);
    });

    testWidgets('requesting a code moves on to the verification step', (
      tester,
    ) async {
      await pumpLogin(tester);
      await requestCode(tester);

      expect(find.text('Verify your number'), findsOneWidget);
      expect(
        find.text('Enter the 6-digit code sent to +91 $phone.'),
        findsOneWidget,
      );
      expect(find.byType(OtpField), findsOneWidget);
      expect(find.text('Full name'), findsNothing);
      expect(AuthService.instance.hasPendingOtp, isTrue);
    });

    testWidgets('a complete code verifies itself, with no button tap', (
      tester,
    ) async {
      await pumpLogin(tester);
      await requestCode(tester);

      await enterCode(tester, AuthService.demoOtp);

      expect(AuthService.instance.isSignedIn, isTrue);
      expect(AuthService.instance.currentUser.value?.name, name);
    });

    testWidgets('a wrong code is refused and the step stays put', (
      tester,
    ) async {
      await pumpLogin(tester);
      await requestCode(tester);

      await enterCode(tester, '000000');

      expect(find.textContaining('incorrect'), findsOneWidget);
      expect(find.byType(OtpField), findsOneWidget);
      expect(AuthService.instance.isSignedIn, isFalse);
      expect(
        AuthService.instance.hasPendingOtp,
        isTrue,
        reason: 'the member should be able to retype the code, not restart',
      );
    });

    testWidgets('the demo code is spelled out on screen', (tester) async {
      await pumpLogin(tester);
      await requestCode(tester);

      expect(
        find.textContaining(AuthService.demoOtp),
        findsWidgets,
        reason: 'there is no SMS behind this build',
      );
    });

    testWidgets('Change details goes back with the name kept', (tester) async {
      await pumpLogin(tester);
      await requestCode(tester);

      await tester.tap(find.text('Change details'));
      await tester.pumpAndSettle();

      expect(find.text('Verify your number'), findsNothing);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text(name), findsOneWidget);
      expect(
        AuthService.instance.hasPendingOtp,
        isFalse,
        reason: 'the abandoned code must not stay live',
      );
    });

    testWidgets('resend is withheld until the countdown runs out', (
      tester,
    ) async {
      await pumpLogin(tester);
      await requestCode(tester);

      expect(find.textContaining('Resend code in'), findsOneWidget);
      expect(find.text('Resend OTP'), findsNothing);

      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.text('Resend OTP'), findsOneWidget);

      await tester.tap(find.text('Resend OTP'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Resend code in'), findsOneWidget);
      expect(AuthService.instance.hasPendingOtp, isTrue);
    });
  });

  group('the checkout guard', () {
    testWidgets('a signed-out checkout opens the login screen', (tester) async {
      await pumpCart(tester);

      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.textContaining('Proceeding to checkout'), findsNothing);
    });

    testWidgets('signing in there continues the checkout', (tester) async {
      await pumpCart(tester);
      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      await requestCode(tester);
      await enterCode(tester, AuthService.demoOtp);

      expect(find.byType(LoginScreen), findsNothing);
      expect(AuthService.instance.isSignedIn, isTrue);
      expect(find.textContaining('Proceeding to checkout'), findsOneWidget);
    });

    testWidgets('a signed-in checkout never stops', (tester) async {
      AuthService.instance.signInAs();
      await pumpCart(tester);

      await tester.tap(find.text('Proceed to checkout'));
      await tester.pump();

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.textContaining('Proceeding to checkout'), findsOneWidget);
    });
  });
}
