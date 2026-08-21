import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/appointment/clinic.dart';
import 'package:shield/module/appointment/clinic_detail_screen.dart';
import 'package:shield/module/appointment/clinics_screen.dart';
import 'package:shield/screens/app_shell.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    Size size = const Size(400, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();
  }

  /// Clinics is no longer a tab. The way in is the menu drawer, and its row
  /// sits past the fold of that list.
  Future<void> openAppointment(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    final row = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Clinics & hospitals'),
    );
    await tester.scrollUntilVisible(
      row,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    Size size = const Size(400, 2000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: ClinicDetailScreen(clinic: ClinicDirectory.meiodia)),
    );
    await tester.pumpAndSettle();
  }

  test('the directory lists Meiodia only, staffed by Dr. Ansar', () {
    expect(ClinicDirectory.clinics, hasLength(1));

    final clinic = ClinicDirectory.clinics.single;
    expect(clinic.name, 'Meiodia Aesthetic Clinic');
    expect(clinic.doctors, hasLength(1));
    expect(clinic.doctors.single.name, 'Dr. Ansar');

    // Every chip must have at least one doctor behind it, or tapping it
    // would drop the list into an empty state with nothing to recover to.
    for (final speciality in clinic.specialities) {
      expect(
        clinic.doctors.any((d) => d.speciality == speciality),
        isTrue,
        reason: 'no doctor covers $speciality',
      );
    }
  });

  group('clinics list', () {
    testWidgets('the drawer reaches the directory', (tester) async {
      await pumpShell(tester);
      await openAppointment(tester);

      expect(find.byType(ClinicsScreen), findsOneWidget);
      expect(find.text('Clinics & Hospitals'), findsOneWidget);
      expect(find.text('Meiodia Aesthetic Clinic'), findsOneWidget);
      expect(find.text('9605558833'), findsOneWidget);
      expect(find.text('Perinthalmanna'), findsWidgets);
    });

    testWidgets('search matches the clinic and rejects anything else', (
      tester,
    ) async {
      await pumpShell(tester);
      await openAppointment(tester);

      await tester.enterText(find.byType(TextField).first, 'meiodia');
      await tester.pumpAndSettle();
      expect(find.text('Meiodia Aesthetic Clinic'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No clinics match your search'), findsOneWidget);
    });

    testWidgets('favourite toggles on and off', (tester) async {
      await pumpShell(tester);
      await openAppointment(tester);

      expect(find.byIcon(Icons.favorite_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    });

    testWidgets('tapping the clinic opens its detail screen', (tester) async {
      await pumpShell(tester);
      await openAppointment(tester);

      await tester.tap(find.text('Meiodia Aesthetic Clinic'));
      await tester.pumpAndSettle();

      expect(find.byType(ClinicDetailScreen), findsOneWidget);
      expect(find.text('Available Doctors'), findsOneWidget);
    });
  });

  group('clinic detail', () {
    testWidgets('shows identity, description, and Dr. Ansar', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Meiodia Aesthetic Clinic'), findsOneWidget);
      expect(find.text('Skin, Hair & Aesthetic Clinic'), findsOneWidget);
      expect(find.text('9605558833'), findsOneWidget);
      expect(find.text('read more'), findsOneWidget);
      expect(find.text('Available Doctors'), findsOneWidget);
      expect(find.text('Dr. Ansar'), findsOneWidget);
      expect(find.text('₹400'), findsOneWidget);
    });

    testWidgets('read more expands and collapses the description', (
      tester,
    ) async {
      await pumpDetail(tester);

      await tester.tap(find.text('read more'));
      await tester.pumpAndSettle();
      expect(find.text('read less'), findsOneWidget);

      await tester.tap(find.text('read less'));
      await tester.pumpAndSettle();
      expect(find.text('read more'), findsOneWidget);
    });

    testWidgets('the speciality chip keeps Dr. Ansar listed', (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.widgetWithText(InkWell, 'Dermatology').first);
      await tester.pumpAndSettle();

      expect(find.text('Dr. Ansar'), findsOneWidget);
    });

    testWidgets('doctor search narrows and empties correctly', (tester) async {
      await pumpDetail(tester);

      await tester.enterText(find.byType(TextField).first, 'ansar');
      await tester.pumpAndSettle();
      expect(find.text('Dr. Ansar'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No doctors match this filter'), findsOneWidget);
    });

    testWidgets('detail lays out on a narrow phone', (tester) async {
      await pumpDetail(tester, size: const Size(320, 2000));

      expect(find.text('Available Doctors'), findsOneWidget);
    });
  });
}
