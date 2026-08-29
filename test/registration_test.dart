import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/account/account_screen.dart';
import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/cart/cart_screen.dart';
import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/registration/register_bar.dart';
import 'package:shield/module/registration/registration_screen.dart';
import 'package:shield/module/registration/registration_service.dart';
import 'package:shield/module/registration/shield_store.dart';
import 'package:shield/dates.dart';
import 'package:shield/screens/app_shell.dart';
import 'package:shield/widgets/age_badge.dart';
import 'package:shield/widgets/bottom_nav.dart';
import 'package:shield/widgets/labelled_field.dart';

void main() {
  setUp(() {
    AuthService.instance.reset();
    AuthService.instance.signInAs(name: 'Asha Nair', phone: '9000012345');
    RegistrationService.instance.reset();
    CartService.instance.reset();
  });
  tearDown(() {
    AuthService.instance.reset();
    RegistrationService.instance.reset();
    CartService.instance.reset();
  });

  // Tall enough to lay the whole form out in one pass, so an overflow
  // anywhere in it fails the test rather than hiding below the fold.
  const formSize = Size(420, 2600);

  Future<void> pumpForm(
    WidgetTester tester, {
    bool isEditing = false,
    Size size = formSize,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: RegistrationScreen(isEditing: isEditing)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String hint, String value) async {
    await tester.enterText(find.widgetWithText(TextFormField, hint), value);
    await tester.pumpAndSettle();
  }

  Future<void> pickDob(WidgetTester tester) async {
    await tester.tap(
      find.widgetWithText(TextFormField, 'Select your date of birth'),
    );
    await tester.pumpAndSettle();
    // Accepts the date the picker opens on — 25 years back.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> pickState(WidgetTester tester, String state) async {
    await tester.tap(find.text('Select your state'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(state));
    await tester.pumpAndSettle();
  }

  Future<void> completeForm(
    WidgetTester tester, {
    String pincode = '679326',
  }) async {
    await fill(tester, 'you@example.com', 'asha@example.com');
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    await pickDob(tester);
    await fill(tester, 'House / flat, street', '12/A Palm Grove');
    await fill(tester, 'Town or locality', 'Melattur');
    await fill(tester, '6-digit pincode', pincode);
    await pickState(tester, 'Kerala');
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.textContaining('Register & earn'));
    await tester.pumpAndSettle();
  }

  group('the store directory', () {
    test('every published branch is a SHIELD branch', () {
      expect(
        StoreDirectory.all.map((store) => store.area),
        [
          'Melattur',
          'Makkaraparamba',
          'Tirur',
          'Karinkallathani',
          'Manjery',
          'Alanallur',
          'Tirurangadi',
          'Kunnumpuram',
          'Kondotty',
          'Areekode',
        ],
        reason:
            'the list is the shops that exist, in the order SHIELD lists '
            'them',
      );
      // No two members can be assigned the same branch under two codes.
      expect(
        StoreDirectory.all.map((store) => store.id).toSet(),
        hasLength(StoreDirectory.all.length),
      );
      // Every branch is in Kerala, and all but Alanallur in Malappuram.
      expect(
        StoreDirectory.all.map((store) => store.state),
        everyElement('Kerala'),
      );
      expect(StoreDirectory.byId('SHD-ALN')?.city, 'Palakkad');
    });

    test('the nearest branch comes off the pincode region', () {
      // A branch's own pincode picks that branch.
      expect(StoreDirectory.suggestFor('679326')?.id, 'SHD-MEL');
      expect(StoreDirectory.suggestFor('676121')?.id, 'SHD-MJR');
      expect(StoreDirectory.suggestFor('673639')?.id, 'SHD-ARK');
      // And a code near one, but not on it, picks the closest.
      expect(StoreDirectory.suggestFor('679322')?.id, 'SHD-KKT');
    });

    test(
      'the branches nearest a code rank above the ones across the district',
      () {
        final ranked = StoreDirectory.nearest('679326');

        expect(ranked.first.id, 'SHD-MEL');
        // Melattur and Karinkallathani share five leading digits; everything
        // else in Malappuram shares two, and so comes after both.
        expect(ranked[1].id, 'SHD-KKT');
        expect(
          ranked.take(2).map((store) => store.pincode),
          everyElement(startsWith('67932')),
        );
        expect(
          ranked.skip(2).map((store) => store.pincode),
          everyElement(isNot(startsWith('67932'))),
        );
        expect(ranked.length, StoreDirectory.all.length);
      },
    );

    test('an incomplete pincode assigns nothing', () {
      expect(StoreDirectory.suggestFor(''), isNull);
      expect(StoreDirectory.suggestFor('6793'), isNull);
      expect(StoreDirectory.suggestFor('abcdef'), isNull);
      // The list is still offered, just unranked.
      expect(StoreDirectory.nearest('6793').length, StoreDirectory.all.length);
    });

    test('stores are looked up by id', () {
      expect(StoreDirectory.byId('SHD-TIR')?.area, 'Tirur');
      expect(StoreDirectory.byId('SHD-NOPE'), isNull);
      expect(StoreDirectory.byId(null), isNull);
    });
  });

  group('the registration service', () {
    Registration sample({String storeId = 'SHD-MEL'}) => Registration(
      name: 'Asha Nair',
      phone: '9000012345',
      email: 'asha@example.com',
      gender: Gender.female,
      dob: DateTime(1994, 9, 4),
      address: '12/A Palm Grove',
      place: 'Perinthalmanna',
      pincode: '679322',
      state: 'Kerala',
      storeId: storeId,
    );

    test('registering credits the reward once, and only once', () {
      final service = RegistrationService.instance;
      expect(service.points, RegistrationService.openingPoints);

      service.save(sample());
      expect(service.isRegistered, isTrue);
      expect(
        service.points,
        RegistrationService.openingPoints + RegistrationService.rewardPoints,
      );

      // Editing is not a second reward.
      service.save(sample(storeId: 'SHD-MJR'));
      expect(
        service.points,
        RegistrationService.openingPoints + RegistrationService.rewardPoints,
      );
      expect(service.profile?.storeId, 'SHD-MJR');
    });

    test('skipping stands the prompt down without registering', () {
      final service = RegistrationService.instance;
      expect(service.shouldPrompt, isTrue);

      service.dismissPrompt();
      expect(service.shouldPrompt, isFalse);
      expect(service.isRegistered, isFalse);
      expect(
        service.points,
        RegistrationService.openingPoints,
        reason: 'nothing was earned',
      );
    });

    test('a profile names its store and reads back as an address', () {
      final registration = sample();

      expect(registration.store?.name, 'SHIELD Pharmacy Melattur');
      expect(registration.dobLabel, '04 Sep 1994');
      expect(registration.age, ageInYears(DateTime(1994, 9, 4)));
      expect(registration.ageLabel, ageLabel(DateTime(1994, 9, 4)));
      expect(
        registration.addressLine,
        '12/A Palm Grove, Perinthalmanna, Kerala - 679322',
      );
    });
  });

  group('the registration form', () {
    testWidgets('asks for everything an order needs', (tester) async {
      await pumpForm(tester);

      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Mobile number'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Date of birth'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      expect(find.text('Place'), findsOneWidget);
      expect(find.text('Pincode'), findsOneWidget);
      expect(find.text('State'), findsOneWidget);
      expect(find.text('Your SHIELD store'), findsOneWidget);
    });

    testWidgets(
      'the date field works the age out as soon as a date is picked',
      (tester) async {
        await pumpForm(tester);

        // Nothing to derive an age from yet.
        expect(find.byType(AgeBadge), findsNothing);

        await pickDob(tester);

        // The picker opens 25 years back, so that is what the field reports.
        expect(find.byType(AgeBadge), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AgeBadge),
            matching: find.text('25 yrs'),
          ),
          findsOneWidget,
        );
        // In the date field itself, not somewhere else on the form.
        expect(
          find.descendant(
            of: find.widgetWithText(LabelledField, 'Date of birth'),
            matching: find.byType(AgeBadge),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('editing opens with the age already worked out', (
      tester,
    ) async {
      RegistrationService.instance.save(
        Registration(
          name: 'Asha Nair',
          phone: '9000012345',
          email: 'asha@example.com',
          gender: Gender.female,
          dob: DateTime(1994, 9, 4),
          address: '12/A Palm Grove',
          place: 'Perinthalmanna',
          pincode: '679322',
          state: 'Kerala',
          storeId: 'SHD-MEL',
        ),
      );
      await pumpForm(tester, isEditing: true);

      expect(
        find.descendant(
          of: find.byType(AgeBadge),
          matching: find.text(ageLabel(DateTime(1994, 9, 4))),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the verified number is carried over and locked', (
      tester,
    ) async {
      await pumpForm(tester);

      final phoneField = find.widgetWithText(
        TextFormField,
        '10-digit mobile number',
      );
      expect(
        tester.widget<TextFormField>(phoneField).controller?.text,
        '9000012345',
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: phoneField, matching: find.byType(TextField)),
            )
            .readOnly,
        isTrue,
        reason: 'the number was verified by OTP and is not editable here',
      );
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

      // The name arrives from the session too, rather than being asked twice.
      final name = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Enter your name'),
      );
      expect(name.controller?.text, 'Asha Nair');
    });

    testWidgets('an empty form names everything it is missing', (tester) async {
      await pumpForm(tester);

      await submit(tester);

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Pick one'), findsOneWidget);
      expect(find.text('Date of birth is required'), findsOneWidget);
      expect(find.text('Address is required'), findsOneWidget);
      expect(find.text('Place is required'), findsOneWidget);
      expect(find.text('Enter a valid 6-digit pincode'), findsOneWidget);
      expect(find.text('State is required'), findsOneWidget);
      expect(
        find.text('Choose the store you want to be served by'),
        findsOneWidget,
      );
      expect(RegistrationService.instance.isRegistered, isFalse);
    });

    testWidgets('a malformed email is refused', (tester) async {
      await pumpForm(tester);

      await fill(tester, 'you@example.com', 'asha-at-example');
      await submit(tester);

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(RegistrationService.instance.isRegistered, isFalse);
    });

    testWidgets('the pincode picks the nearest branch and says so', (
      tester,
    ) async {
      await pumpForm(tester);

      expect(
        find.text('Nearest'),
        findsNothing,
        reason: 'an incomplete pincode must not assign a branch',
      );

      await fill(tester, '6-digit pincode', '679326');

      expect(find.text('SHIELD Pharmacy Melattur'), findsOneWidget);
      expect(find.text('Nearest'), findsOneWidget);
      expect(find.textContaining('Nearest to 679326'), findsOneWidget);
    });

    testWidgets('every branch is reachable behind the short list', (
      tester,
    ) async {
      await pumpForm(tester);
      await fill(tester, '6-digit pincode', '679326');

      // Areekode is the far end of the district, and so off the short list.
      expect(find.text('SHIELD Pharmacy Areekode'), findsNothing);

      await tester.tap(
        find.text('Show all ${StoreDirectory.all.length} stores'),
      );
      await tester.pumpAndSettle();

      expect(find.text('SHIELD Pharmacy Areekode'), findsOneWidget);
    });

    testWidgets('a completed form registers and assigns the store', (
      tester,
    ) async {
      await pumpForm(tester);
      await completeForm(tester);
      await submit(tester);

      final service = RegistrationService.instance;
      expect(service.isRegistered, isTrue);

      final profile = service.profile!;
      expect(profile.name, 'Asha Nair');
      expect(profile.phone, '9000012345');
      expect(profile.email, 'asha@example.com');
      expect(profile.gender, Gender.female);
      expect(profile.place, 'Melattur');
      expect(profile.pincode, '679326');
      expect(profile.state, 'Kerala');
      expect(profile.storeId, 'SHD-MEL');
      expect(
        service.points,
        RegistrationService.openingPoints + RegistrationService.rewardPoints,
      );
    });

    testWidgets('a branch chosen by hand survives a pincode change', (
      tester,
    ) async {
      await pumpForm(tester);
      await completeForm(tester);

      await tester.tap(find.text('SHIELD Pharmacy Alanallur'));
      await tester.pumpAndSettle();

      // Re-ranking the list must not move a choice the member made.
      await fill(tester, '6-digit pincode', '676101');
      await submit(tester);

      final profile = RegistrationService.instance.profile!;
      expect(profile.storeId, 'SHD-ALN');
      expect(profile.pincode, '676101');
    });

    testWidgets('close leaves without registering and stands the prompt down', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(RegistrationService.instance.isRegistered, isFalse);
      expect(RegistrationService.instance.shouldPrompt, isFalse);
    });

    testWidgets('skip does the same as close', (tester) async {
      await pumpForm(tester);

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(RegistrationService.instance.isRegistered, isFalse);
      expect(RegistrationService.instance.shouldPrompt, isFalse);
    });

    testWidgets('editing prefills, drops the reward copy, and drops skip', (
      tester,
    ) async {
      await pumpForm(tester);
      await completeForm(tester);
      await submit(tester);

      await pumpForm(tester, isEditing: true);

      expect(find.text('Registration details'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Skip for now'), findsNothing);
      expect(find.textContaining('Register once and'), findsNothing);

      final email = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'you@example.com'),
      );
      expect(email.controller?.text, 'asha@example.com');
      expect(find.text('SHIELD Pharmacy Melattur'), findsWidgets);
    });
  });

  group('the sticky prompt', () {
    Future<void> pumpBar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(bottomNavigationBar: RegisterBar())),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pumpShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();
    }

    testWidgets('offers the reward in so many words', (tester) async {
      await pumpBar(tester);

      expect(
        find.text(
          'Register now & get '
          '${RegistrationService.rewardPoints} reward points',
        ),
        findsOneWidget,
      );
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('its close dismisses it and gives the height back', (
      tester,
    ) async {
      await pumpBar(tester);
      expect(tester.getSize(find.byType(RegisterBar)).height, greaterThan(0));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Register'), findsNothing);
      expect(find.byType(RegistrationScreen), findsNothing);
      expect(
        tester.getSize(find.byType(RegisterBar)).height,
        0,
        reason: 'a refused strip must not hold a band of the screen',
      );
      expect(RegistrationService.instance.shouldPrompt, isFalse);
    });

    testWidgets('a registered member is not asked again', (tester) async {
      RegistrationService.instance.save(
        Registration(
          name: 'Asha Nair',
          phone: '9000012345',
          email: 'asha@example.com',
          gender: Gender.female,
          dob: DateTime(1994, 9, 4),
          address: '12/A Palm Grove',
          place: 'Perinthalmanna',
          pincode: '679322',
          state: 'Kerala',
          storeId: 'SHD-MEL',
        ),
      );
      await pumpBar(tester);

      expect(find.text('Register'), findsNothing);
    });

    testWidgets('it sits above the bottom navigation', (tester) async {
      await pumpShell(tester);

      final bar = find.byType(RegisterBar);
      expect(bar, findsOneWidget);
      expect(
        tester.getBottomLeft(bar).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(ShieldBottomNav)).dy),
      );
    });

    testWidgets('the coupon promo it replaced is gone', (tester) async {
      await pumpShell(tester);

      expect(find.textContaining('FLAT 26%'), findsNothing);
      expect(find.text('Apply'), findsNothing);
    });
  });

  group('the account prompt', () {
    Future<void> pumpAccount(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('offers registration and a way into the details', (
      tester,
    ) async {
      await pumpAccount(tester);

      expect(find.text('Complete your registration'), findsOneWidget);
      expect(find.text('Registration details'), findsOneWidget);
    });

    testWidgets('survives a skip, unlike the home card', (tester) async {
      RegistrationService.instance.dismissPrompt();
      await pumpAccount(tester);

      expect(
        find.text('Complete your registration'),
        findsOneWidget,
        reason: 'the account page is where someone goes looking for it',
      );
    });

    testWidgets('the banner gives way to the assigned store', (tester) async {
      await pumpAccount(tester);

      await tester.tap(find.text('Complete your registration'));
      await tester.pumpAndSettle();
      await completeForm(tester);
      await submit(tester);

      expect(find.text('Complete your registration'), findsNothing);
      expect(find.text('SHIELD Pharmacy Melattur'), findsOneWidget);
    });
  });

  group('the checkout prompt', () {
    Future<void> pumpCart(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      CartService.instance.add(
        name: 'Dolo 650mg Tablet',
        pack: 'Strip of 15 tablets',
        price: 32.5,
      );

      await tester.pumpWidget(const MaterialApp(home: CartScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('payment offers registration first', (tester) async {
      await pumpCart(tester);

      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      expect(find.byType(RegistrationScreen), findsOneWidget);
      expect(find.text('Payment checkout'), findsNothing);
    });

    testWidgets('skipping still reaches checkout', (tester) async {
      await pumpCart(tester);
      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.byType(RegistrationScreen), findsNothing);
      expect(RegistrationService.instance.isRegistered, isFalse);
      expect(
        find.text('Payment checkout'),
        findsOneWidget,
        reason: 'declining to register is not a reason to refuse the money',
      );
    });

    testWidgets('registering there also reaches checkout', (tester) async {
      await pumpCart(tester);
      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      await completeForm(tester);
      await submit(tester);

      expect(RegistrationService.instance.isRegistered, isTrue);
      expect(find.textContaining('Registered ·'), findsOneWidget);

      expect(find.text('Payment checkout'), findsOneWidget);
    });

    testWidgets('a registered member is taken straight to payment', (
      tester,
    ) async {
      RegistrationService.instance.save(
        Registration(
          name: 'Asha Nair',
          phone: '9000012345',
          email: 'asha@example.com',
          gender: Gender.female,
          dob: DateTime(1994, 9, 4),
          address: '12/A Palm Grove',
          place: 'Perinthalmanna',
          pincode: '679322',
          state: 'Kerala',
          storeId: 'SHD-MEL',
        ),
      );
      await pumpCart(tester);

      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      expect(find.byType(RegistrationScreen), findsNothing);
      expect(find.text('Payment checkout'), findsOneWidget);
    });
  });
}
