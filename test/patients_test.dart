import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/dates.dart';
import 'package:shield/module/account/account_screen.dart';
import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/patients/manage_patients_screen.dart';
import 'package:shield/module/patients/patient_book.dart';
import 'package:shield/module/patients/patient_form_sheet.dart';
import 'package:shield/module/patients/patient_picker.dart';
import 'package:shield/module/prescription/upload_prescription_screen.dart';

void main() {
  setUp(PatientBook.instance.reset);
  tearDown(PatientBook.instance.reset);

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(400, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), value);
  }

  /// A date of birth [age] years back, so the derived age is stable whenever
  /// the suite runs.
  DateTime dobFor(int age) {
    final now = DateTime.now();
    return DateTime(now.year - age, now.month, now.day);
  }

  Patient seed({String name = 'Asha', int age = 32, String abhaId = ''}) {
    return PatientBook.instance.add(
      name: name,
      phone: '9000012345',
      dob: dobFor(age),
      gender: PatientGender.female,
      abhaId: abhaId,
      relation: PatientRelation.spouse,
    );
  }

  /// Drives the sheet's date picker, which accepts the date it opens on.
  Future<void> pickDob(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextFormField, 'Date of birth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  group('the patient book', () {
    test('starts empty and hands back what it stored', () {
      expect(PatientBook.instance.isEmpty, isTrue);

      final saved = seed();

      expect(PatientBook.instance.length, 1);
      expect(saved.name, 'Asha');
      expect(PatientBook.instance.byId(saved.id)?.name, 'Asha');
    });

    test('ids are unique across additions', () {
      final first = seed(name: 'Asha');
      final second = seed(name: 'Ravi');

      expect(first.id, isNot(second.id));
    });

    test('the summary is what every row shows', () {
      expect(seed().summary, '32 yrs · Female · Spouse');
    });

    test('names are trimmed on the way in', () {
      final saved = PatientBook.instance.add(
        name: '  Ravi  ',
        phone: ' 9000012345 ',
        dob: dobFor(8),
        gender: PatientGender.male,
        relation: PatientRelation.child,
      );
      expect(saved.name, 'Ravi');
      expect(saved.phone, '9000012345');
    });

    test('the age is derived from the date, not stored', () {
      final born = DateTime(1994, 9, 4);
      final patient = Patient(
        id: 'p1',
        name: 'Asha',
        phone: '9000012345',
        dob: born,
        gender: PatientGender.female,
        relation: PatientRelation.spouse,
      );

      expect(patient.dobLabel, '04 Sep 1994');
      expect(patient.age, ageInYears(born));
      // The birthday counts: still 29 the day before the thirtieth.
      expect(ageInYears(born, asOf: DateTime(2024, 9, 3)), 29);
      expect(ageInYears(born, asOf: DateTime(2024, 9, 4)), 30);
    });

    test('an ABHA number is stored as digits and shown in groups', () {
      final withAbha = seed(abhaId: '12-3456-7890-1234');
      expect(withAbha.abhaId, '12345678901234');
      expect(withAbha.abhaLabel, '12-3456-7890-1234');
      expect(withAbha.hasAbha, isTrue);

      // Optional: a patient without one is perfectly valid.
      expect(seed(name: 'Ravi').hasAbha, isFalse);
      expect(seed(name: 'Meera').abhaLabel, '');
    });

    test('update replaces in place', () {
      final saved = seed();
      PatientBook.instance.update(saved.copyWith(dob: dobFor(33)));

      expect(PatientBook.instance.length, 1);
      expect(PatientBook.instance.byId(saved.id)?.age, 33);
    });

    test('updating an unknown id does nothing rather than appending', () {
      seed();
      PatientBook.instance.update(
        Patient(
          id: 'nope',
          name: 'Ghost',
          phone: '9000099999',
          dob: dobFor(40),
          gender: PatientGender.other,
          relation: PatientRelation.other,
        ),
      );

      expect(PatientBook.instance.length, 1);
      expect(PatientBook.instance.byId('nope'), isNull);
    });

    test('remove takes the right one out', () {
      final asha = seed(name: 'Asha');
      seed(name: 'Ravi');

      PatientBook.instance.remove(asha.id);

      expect(PatientBook.instance.patients.single.name, 'Ravi');
    });
  });

  group('manage patients', () {
    testWidgets('empty until someone is added', (tester) async {
      await pump(tester, const ManagePatientsScreen());

      expect(find.text('No patients yet'), findsOneWidget);
    });

    testWidgets('adding through the sheet stores and lists them', (
      tester,
    ) async {
      await pump(tester, const ManagePatientsScreen());

      await tester.tap(find.text('Add patient'));
      await tester.pumpAndSettle();
      expect(find.byType(PatientFormSheet), findsOneWidget);

      await fill(tester, 'Full name', 'Asha Nair');
      await fill(tester, 'Mobile number', '9000012345');
      await pickDob(tester);
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();
      await fill(tester, 'ABHA ID', '12345678901234');
      await tester.tap(find.text('Spouse'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save patient'));
      await tester.pumpAndSettle();

      final saved = PatientBook.instance.patients.single;
      expect(saved.name, 'Asha Nair');
      expect(saved.phone, '9000012345');
      expect(saved.abhaId, '12345678901234');
      expect(saved.gender, PatientGender.female);
      expect(saved.relation, PatientRelation.spouse);
      // The picker opens 25 years back and the case accepts that date.
      expect(saved.age, 25);

      expect(find.text('Asha Nair'), findsOneWidget);
      expect(find.text('25 yrs · Female · Spouse'), findsOneWidget);
      expect(
        find.text('+91 9000012345 · ABHA 12-3456-7890-1234'),
        findsOneWidget,
      );
    });

    testWidgets('the form asks in the order it was specified', (tester) async {
      await pump(tester, const ManagePatientsScreen());

      await tester.tap(find.text('Add patient'));
      await tester.pumpAndSettle();

      const order = [
        'Full name',
        'Mobile number',
        'Date of birth',
        'Gender',
        'ABHA ID',
        'Relation',
      ];
      var previous = -1.0;
      for (final label in order) {
        final position = tester.getTopLeft(find.text(label).first).dy;
        expect(
          position,
          greaterThan(previous),
          reason: '$label is out of order',
        );
        previous = position;
      }
    });

    testWidgets('the ABHA number groups itself as it is typed', (tester) async {
      await pump(tester, const ManagePatientsScreen());

      await tester.tap(find.text('Add patient'));
      await tester.pumpAndSettle();

      await fill(tester, 'ABHA ID', '12345678901234');
      await tester.pumpAndSettle();

      // Read the controller, not the rendered text: the hint on this field is
      // a sample number in the same grouped form.
      final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'ABHA ID'),
      );
      expect(field.controller?.text, '12-3456-7890-1234');
    });

    testWidgets('a half-typed ABHA number is refused, a blank one is not', (
      tester,
    ) async {
      await pump(tester, const ManagePatientsScreen());

      await tester.tap(find.text('Add patient'));
      await tester.pumpAndSettle();
      await fill(tester, 'Full name', 'Asha');
      await fill(tester, 'Mobile number', '9000012345');
      await pickDob(tester);
      await fill(tester, 'ABHA ID', '1234');
      await tester.tap(find.text('Save patient'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter all 14 digits'), findsOneWidget);
      expect(PatientBook.instance.isEmpty, isTrue);

      await fill(tester, 'ABHA ID', '');
      await tester.tap(find.text('Save patient'));
      await tester.pumpAndSettle();

      expect(PatientBook.instance.patients.single.hasAbha, isFalse);
    });

    testWidgets('an empty form reports what is required', (tester) async {
      await pump(tester, const ManagePatientsScreen());

      await tester.tap(find.text('Add patient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save patient'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Mobile number is required'), findsOneWidget);
      expect(find.text('Select a date of birth'), findsOneWidget);
      expect(PatientBook.instance.isEmpty, isTrue);
    });

    testWidgets('a bad mobile number is refused', (tester) async {
      await pump(tester, const ManagePatientsScreen());

      await tester.tap(find.text('Add patient'));
      await tester.pumpAndSettle();
      await fill(tester, 'Full name', 'Asha');
      await fill(tester, 'Mobile number', '12345');
      await tester.tap(find.text('Save patient'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid 10-digit number'), findsOneWidget);
      expect(PatientBook.instance.isEmpty, isTrue);
    });

    testWidgets('editing opens filled in and updates in place', (tester) async {
      final saved = seed(name: 'Asha', age: 32);
      await pump(tester, const ManagePatientsScreen());

      await tester.tap(find.byTooltip('Edit Asha'));
      await tester.pumpAndSettle();

      expect(find.text('Edit patient'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
      // Opens filled in, the date and the number included.
      expect(find.text(formatDate(saved.dob)), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Mobile number'),
            )
            .controller
            ?.text,
        '9000012345',
      );

      await fill(tester, 'Full name', 'Asha Nair');
      await tester.tap(find.text('Save patient'));
      await tester.pumpAndSettle();

      // Still one record, not a duplicate, and the date rode through the edit.
      expect(PatientBook.instance.length, 1);
      expect(PatientBook.instance.byId(saved.id)?.name, 'Asha Nair');
      expect(PatientBook.instance.byId(saved.id)?.age, 32);
    });

    testWidgets('removing asks first', (tester) async {
      seed(name: 'Asha');
      await pump(tester, const ManagePatientsScreen());

      await tester.tap(find.byTooltip('Remove Asha'));
      await tester.pumpAndSettle();
      expect(find.text('Remove patient?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(PatientBook.instance.length, 1);

      await tester.tap(find.byTooltip('Remove Asha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(PatientBook.instance.isEmpty, isTrue);
    });

    testWidgets('reachable from the account menu', (tester) async {
      AuthService.instance.signInAs();
      addTearDown(AuthService.instance.reset);

      await pump(tester, const AccountScreen(), size: const Size(400, 1400));

      expect(find.text('Manage patients'), findsOneWidget);
      await tester.tap(find.text('Manage patients'));
      await tester.pumpAndSettle();

      expect(find.byType(ManagePatientsScreen), findsOneWidget);
    });
  });

  group('choosing a patient on upload', () {
    testWidgets('the picker is on the upload screen, unanswered', (
      tester,
    ) async {
      await pump(tester, const UploadPrescriptionScreen());

      expect(find.byType(PatientPicker), findsOneWidget);
      expect(find.text('Prescription is for'), findsOneWidget);
      expect(find.text('Select patient'), findsOneWidget);
    });

    testWidgets('picking one names it on the row', (tester) async {
      seed(name: 'Asha');
      await pump(tester, const UploadPrescriptionScreen());

      await tester.tap(find.text('Select patient'));
      await tester.pumpAndSettle();
      expect(find.byType(PatientSelectSheet), findsOneWidget);

      await tester.tap(find.text('Asha'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(PatientPicker),
          matching: find.text('Asha'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an empty book is not a dead end mid-flow', (tester) async {
      await pump(tester, const UploadPrescriptionScreen());

      await tester.tap(find.text('Select patient'));
      await tester.pumpAndSettle();
      expect(find.text('No patients on this account yet.'), findsOneWidget);

      await tester.tap(find.text('Add a new patient'));
      await tester.pumpAndSettle();

      await fill(tester, 'Full name', 'Ravi');
      await fill(tester, 'Mobile number', '9000012345');
      await pickDob(tester);
      await tester.tap(find.text('Child'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save patient'));
      await tester.pumpAndSettle();

      // Added and chosen in one pass, with no second selection needed.
      expect(PatientBook.instance.length, 1);
      expect(
        find.descendant(
          of: find.byType(PatientPicker),
          matching: find.text('Ravi'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a file alone does not unlock proceeding', (tester) async {
      seed(name: 'Asha');
      await pump(tester, const UploadPrescriptionScreen());

      // No file and no patient yet.
      final before = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(before.onPressed, isNull);

      // Choosing a patient is not enough on its own either: the file is still
      // missing, and image_picker cannot be driven from a widget test.
      await tester.tap(find.text('Select patient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asha'));
      await tester.pumpAndSettle();

      final after = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(after.onPressed, isNull);
    });
  });
}
