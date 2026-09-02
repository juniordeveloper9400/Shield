import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/dates.dart';
import 'package:shield/module/account/account_screen.dart';
import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/location/address_book.dart';
import 'package:shield/module/patients/manage_patients_screen.dart';
import 'package:shield/module/patients/patient_book.dart';
import 'package:shield/module/patients/patient_form_sheet.dart';
import 'package:shield/module/patients/patient_picker.dart';
import 'package:shield/module/prescription/upload_prescription_screen.dart';
import 'package:shield/widgets/age_badge.dart';

void main() {
  setUp(() {
    PatientBook.instance.reset();
    AddressBook.instance.reset();
  });
  tearDown(() {
    PatientBook.instance.reset();
    AddressBook.instance.reset();
  });

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

  /// Fills the "Address details" section at the foot of the patient form —
  /// the address lines and the receiver details underneath them.
  Future<void> fillAddress(
    WidgetTester tester, {
    String pincode = '682001',
    String house = '12 Lake View Road',
    String area = 'Kochi',
    String receiverFirst = 'Asha',
    String receiverLast = '',
    String receiverPhone = '9000012345',
  }) async {
    await fill(tester, 'Pincode', pincode);
    await fill(tester, 'House no / Floor / Building', house);
    await fill(tester, 'Area / Locality', area);
    await fill(tester, 'First name', receiverFirst);
    if (receiverLast.isNotEmpty) {
      await fill(tester, 'Last name', receiverLast);
    }
    await fill(tester, 'Mobile Number', receiverPhone);
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
      address: '12 Lake View Road, Kochi',
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
        address: '  45 Market Road, Kochi  ',
        dob: dobFor(8),
        gender: PatientGender.male,
        relation: PatientRelation.child,
      );
      expect(saved.name, 'Ravi');
      expect(saved.phone, '9000012345');
      expect(saved.address, '45 Market Road, Kochi');
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

      // The wording the form and the row both use, singular for an infant.
      expect(ageLabel(born, asOf: DateTime(2024, 9, 4)), '30 yrs');
      expect(ageLabel(born, asOf: DateTime(1995, 9, 4)), '1 yr');
      expect(ageLabel(born, asOf: DateTime(1995, 9, 3)), '0 yrs');
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

    test('replaceRemote loads the account\'s saved patients', () {
      Patient remote(String uuid, String name) => Patient(
        id: 'remote-$uuid',
        remoteId: uuid,
        name: name,
        phone: '9000012345',
        address: '',
        dob: dobFor(30),
        gender: PatientGender.male,
        relation: PatientRelation.self,
      );

      PatientBook.instance.replaceRemote([remote('a', 'Muz'), remote('b', 'Ravi')]);

      final names = PatientBook.instance.patients.map((p) => p.name).toList();
      expect(names, ['Muz', 'Ravi']);
      expect(
        PatientBook.instance.patients.every((p) => p.remoteId != null),
        isTrue,
      );
    });

    test('replaceRemote collapses exact-duplicate remote rows', () {
      Patient dup(String uuid) => Patient(
        id: 'remote-$uuid',
        remoteId: uuid,
        name: 'Muza',
        phone: '9484040484',
        address: '',
        dob: dobFor(24),
        gender: PatientGender.male,
        relation: PatientRelation.self,
      );

      PatientBook.instance.replaceRemote([dup('x'), dup('y')]);

      expect(PatientBook.instance.length, 1);
    });

    test('replaceRemote keeps an unsynced local patient, drops a synced dupe',
        () {
      final local = seed(name: 'Local Only'); // no remoteId
      expect(local.remoteId, isNull);

      PatientBook.instance.replaceRemote([
        Patient(
          id: 'remote-1',
          remoteId: '1',
          name: 'From DB',
          phone: '9111111111',
          address: '',
          dob: dobFor(40),
          gender: PatientGender.female,
          relation: PatientRelation.parent,
        ),
      ]);

      final names = PatientBook.instance.patients.map((p) => p.name).toSet();
      expect(names, {'From DB', 'Local Only'});
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
      await fillAddress(
        tester,
        pincode: '682001',
        house: '12 Lake View Road',
        area: 'Kochi',
        receiverFirst: 'Asha',
        receiverLast: 'Nair',
        receiverPhone: '9000012345',
      );
      await tester.tap(find.text('Save patient'));
      await tester.pumpAndSettle();

      final saved = PatientBook.instance.patients.single;
      expect(saved.name, 'Asha Nair');
      expect(saved.phone, '9000012345');
      // The one-line summary the address section rolled up on save.
      expect(saved.address, '12 Lake View Road, Kochi, 682001');
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
      expect(find.text('12 Lake View Road, Kochi, 682001'), findsOneWidget);

      // The address just entered is also on file for this patient, ready to
      // show up on "Select address" — not a plain string with nowhere else
      // to live.
      final linked = AddressBook.instance.forPatient(saved.id);
      expect(linked, isNotNull);
      expect(linked!.house, '12 Lake View Road');
      expect(linked.area, 'Kochi');
      expect(linked.pincode, '682001');
      expect(linked.receiver, 'Asha Nair');
    });

    testWidgets(
      'the date field works the age out as soon as a date is picked',
      (tester) async {
        await pump(tester, const ManagePatientsScreen());

        await tester.tap(find.text('Add patient'));
        await tester.pumpAndSettle();

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
        // In the date field itself, not somewhere else on the sheet.
        expect(
          find.descendant(
            of: find.widgetWithText(TextFormField, 'Date of birth'),
            matching: find.byType(AgeBadge),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('editing opens with the age already worked out', (
      tester,
    ) async {
      final saved = seed(name: 'Asha', age: 32);
      await pump(tester, const ManagePatientsScreen());

      await tester.tap(find.byTooltip('Edit Asha'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AgeBadge),
          matching: find.text(ageLabel(saved.dob)),
        ),
        findsOneWidget,
      );
      expect(ageLabel(saved.dob), '32 yrs');
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
        // The address details section sits at the foot of the form, after
        // everything about the patient themselves — the address lines, then
        // who actually receives the delivery.
        'Pincode',
        'House no / Floor / Building',
        'Area / Locality',
        'Receiver details',
        'First name',
        'Mobile Number',
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

    testWidgets(
      'the address section offers Current Location beside the pincode',
      (tester) async {
        await pump(tester, const ManagePatientsScreen());

        await tester.tap(find.text('Add patient'));
        await tester.pumpAndSettle();

        // The same pincode + Current Location row the standalone address form
        // opens with.
        expect(find.text('Current Location'), findsOneWidget);
        final pincode = tester.getTopLeft(
          find.widgetWithText(TextFormField, 'Pincode'),
        );
        final locate = tester.getTopLeft(find.text('Current Location'));
        expect((pincode.dy - locate.dy).abs(), lessThan(40));
        expect(locate.dx, greaterThan(pincode.dx));

        // Device location is a stub for now, and says so.
        await tester.tap(find.text('Current Location'));
        await tester.pumpAndSettle();
        expect(
          find.text('Device location is not connected yet'),
          findsOneWidget,
        );
      },
    );

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
      await fillAddress(tester);
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

      // The patient's own name, the house and area fields, and the
      // receiver's first name.
      expect(find.text('Required'), findsNWidgets(4));
      expect(find.text('Mobile number is required'), findsOneWidget);
      expect(find.text('Select a date of birth'), findsOneWidget);
      expect(find.text('Enter a 6-digit pincode'), findsOneWidget);
      // The receiver's own number is checked separately from the patient's.
      expect(find.text('Enter a valid 10-digit number'), findsOneWidget);
      expect(PatientBook.instance.isEmpty, isTrue);
    });

    testWidgets('a bad mobile number is refused', (tester) async {
      await pump(tester, const ManagePatientsScreen());

      await tester.tap(find.text('Add patient'));
      await tester.pumpAndSettle();
      await fill(tester, 'Full name', 'Asha');
      await fill(tester, 'Mobile number', '12345');
      await fillAddress(tester);
      await tester.tap(find.text('Save patient'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid 10-digit number'), findsOneWidget);
      expect(PatientBook.instance.isEmpty, isTrue);
    });

    testWidgets('editing opens filled in and updates in place', (tester) async {
      final saved = seed(name: 'Asha', age: 32);
      // The address the patient form itself would have put on file — seed()
      // calls PatientBook directly and skips that step, so it is added here.
      AddressBook.instance.upsertForPatient(
        saved.id,
        Address(
          pincode: '682001',
          house: '12 Lake View Road',
          area: 'Kochi',
          firstName: saved.name,
          phone: saved.phone,
          label: AddressLabel.home,
          patientId: saved.id,
        ),
      );
      await pump(tester, const ManagePatientsScreen());

      await tester.tap(find.byTooltip('Edit Asha'));
      await tester.pumpAndSettle();

      expect(find.text('Edit patient'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
      // Opens filled in, the date, the number and the address on file.
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
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'House no / Floor / Building'),
            )
            .controller
            ?.text,
        '12 Lake View Road',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Area / Locality'),
            )
            .controller
            ?.text,
        'Kochi',
      );

      await fill(tester, 'Full name', 'Asha Nair');
      await fill(tester, 'House no / Floor / Building', '34 New Street');
      await tester.tap(find.text('Save patient'));
      await tester.pumpAndSettle();

      // Still one record, not a duplicate, and the date rode through the edit.
      expect(PatientBook.instance.length, 1);
      expect(PatientBook.instance.byId(saved.id)?.name, 'Asha Nair');
      expect(
        PatientBook.instance.byId(saved.id)?.address,
        '34 New Street, Kochi, 682001',
      );
      expect(PatientBook.instance.byId(saved.id)?.age, 32);
      // The address on file for this patient was updated in place, not
      // duplicated into a second entry.
      expect(
        AddressBook.instance.addresses
            .where((a) => a.patientId == saved.id)
            .length,
        1,
      );
      expect(AddressBook.instance.forPatient(saved.id)?.house, '34 New Street');
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
      await fillAddress(
        tester,
        pincode: '682003',
        house: '7 Temple Road',
        area: 'Kochi',
      );
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
