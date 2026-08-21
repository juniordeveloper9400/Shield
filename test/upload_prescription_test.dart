import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/dates.dart';
import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/home/prescription_card.dart';
import 'package:shield/module/patients/patient_book.dart';
import 'package:shield/phone.dart';
import 'package:shield/module/prescription/medicine_duration.dart';
import 'package:shield/module/prescription/prescription_copy.dart';
import 'package:shield/module/prescription/prescription_form.dart';
import 'package:shield/module/prescription/prescription_form_sheet.dart';
import 'package:shield/module/prescription/prescription_record.dart';
import 'package:shield/module/prescription/upload_prescription_screen.dart';
import 'package:shield/theme/app_colors.dart';
import 'package:shield/screens/home_screen.dart';

void main() {
  Future<void> pumpUpload(
    WidgetTester tester, {
    // Tall enough for the lazy list to reach the pharmacist card at the very
    // bottom, which the five-step procedure and the recurring-order box now
    // sit above. Malayalam runs taller still, so this leaves room for it.
    Size size = const Size(400, 3400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: UploadPrescriptionScreen()),
    );
    await tester.pumpAndSettle();
  }

  group('upload prescription screen', () {
    testWidgets('renders the guidance, sources, and pharmacist card', (
      tester,
    ) async {
      await pumpUpload(tester);

      expect(find.text('Upload Prescription'), findsOneWidget);
      expect(
        find.text('Upload your prescription to start ordering'),
        findsOneWidget,
      );
      expect(find.text('Use\nCamera'), findsOneWidget);
      expect(find.text('Use\nGallery'), findsOneWidget);

      expect(find.text('Please keep in mind:'), findsOneWidget);
      expect(
        find.textContaining('Supported formats: JPG, JPEG, PNG, PDF'),
        findsOneWidget,
      );
      expect(
        find.textContaining('File size must be under 5 MB'),
        findsOneWidget,
      );

      expect(find.text('Pharmacist call'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Proceed'), findsOneWidget);
    });

    testWidgets('Proceed is disabled until a file is chosen', (tester) async {
      await pumpUpload(tester);

      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Proceed'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull, reason: 'nothing has been uploaded yet');
    });

    testWidgets('narrow viewport lays out without overflow', (tester) async {
      // Taller again than the other cases: the duration chips wrap to several
      // rows at this width, and so does every step of the procedure.
      await pumpUpload(tester, size: const Size(320, 4600));

      expect(find.text('Use\nCamera'), findsOneWidget);
      expect(find.text('Pharmacist call'), findsOneWidget);
    });

    testWidgets('source tiles hug their content and match each other', (
      tester,
    ) async {
      await pumpUpload(tester);

      final camera = find.ancestor(
        of: find.text('Use\nCamera'),
        matching: find.byType(InkWell),
      );
      final gallery = find.ancestor(
        of: find.text('Use\nGallery'),
        matching: find.byType(InkWell),
      );

      final cameraHeight = tester.getSize(camera.first).height;
      final galleryHeight = tester.getSize(gallery.first).height;

      // Equal to each other, and sized to icon + gap + two label lines plus
      // padding rather than the old fixed 152px box.
      expect(cameraHeight, galleryHeight);
      expect(
        cameraHeight,
        lessThan(130),
        reason: 'tile should hug its content, not reserve extra height',
      );
    });

    test('the size cap matches the stated 5 MB rule', () {
      expect(UploadPrescriptionScreen.maxBytes, 5 * 1024 * 1024);
    });
  });

  group('home prescription card', () {
    testWidgets('is a single card holding upload and the order number', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 5200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pumpAndSettle();

      final card = find.byType(PrescriptionCard);
      expect(card, findsOneWidget);

      // Both halves live inside the one card rather than in separate blocks.
      expect(
        find.descendant(of: card, matching: find.text('Add a prescription')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining(PrescriptionCard.orderPhone),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Upload')),
        findsOneWidget,
      );
    });

    testWidgets('card hugs its two rows rather than stretching', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 5200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pumpAndSettle();

      final height = tester.getSize(find.byType(PrescriptionCard)).height;

      // Two content rows, a divider, and 14px padding — nowhere near the
      // 5200 of the Stack it is aligned inside. The ceiling is generous
      // because the test font is far wider than Roboto, so the order copy
      // wraps to about twice the lines it takes on a device.
      expect(
        height,
        lessThan(320),
        reason: 'card must not stretch to fill the home Stack',
      );
    });

    /// The card alone rather than the whole feed: these cases are about the
    /// card's own behaviour, and the feed takes seconds to lay out.
    Future<void> pumpCard(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: PrescriptionCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('it names both other ways to order', (tester) async {
      await pumpCard(tester);

      final card = find.byType(PrescriptionCard);
      final copy = find.descendant(
        of: card,
        matching: find.textContaining('nearest store'),
      );
      expect(copy, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('call us to order on'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining(PrescriptionCard.orderPhone),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping the call row opens the dialer on the number', (
      tester,
    ) async {
      final opened = <Uri>[];
      Dialer.opener = (uri) async {
        opened.add(uri);
        return true;
      };
      addTearDown(Dialer.resetForTest);

      await pumpCard(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(PrescriptionCard),
          matching: find.byIcon(Icons.phone_in_talk_rounded),
        ),
      );
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
      expect(opened.single.scheme, 'tel');
      expect(opened.single.path, PrescriptionCard.orderPhone);
      // Dialling, not uploading: the row takes the tap from the card.
      expect(find.byType(UploadPrescriptionScreen), findsNothing);
    });

    testWidgets('the copy dials too, not just the chip', (tester) async {
      final opened = <Uri>[];
      Dialer.opener = (uri) async {
        opened.add(uri);
        return true;
      };
      addTearDown(Dialer.resetForTest);

      await pumpCard(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(PrescriptionCard),
          matching: find.textContaining('nearest store'),
        ),
      );
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
      expect(find.byType(UploadPrescriptionScreen), findsNothing);
    });

    testWidgets('a dialer that will not open says so', (tester) async {
      Dialer.opener = (uri) async => false;
      addTearDown(Dialer.resetForTest);

      await pumpCard(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(PrescriptionCard),
          matching: find.byIcon(Icons.phone_in_talk_rounded),
        ),
      );
      await tester.pumpAndSettle();

      // A silent no-op would read as a broken button.
      expect(find.textContaining('Could not open the dialer'), findsOneWidget);
    });

    testWidgets('the rest of the card still opens upload', (tester) async {
      await pumpCard(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(PrescriptionCard),
          matching: find.text('Add a prescription'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UploadPrescriptionScreen), findsOneWidget);
    });

    testWidgets('a number written for people still dials', (tester) async {
      expect(Dialer.uriFor('+91 94005-25063').toString(), 'tel:+919400525063');
      expect(Dialer.uriFor('9400525063').toString(), 'tel:9400525063');
    });

    testWidgets('tapping the card opens the upload screen', (tester) async {
      tester.view.physicalSize = const Size(400, 5200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a prescription'));
      await tester.pumpAndSettle();

      expect(find.byType(UploadPrescriptionScreen), findsOneWidget);
      expect(find.text('Use\nGallery'), findsOneWidget);
    });
  });

  group('the ordering procedure', () {
    testWidgets('numbers every step, in order', (tester) async {
      await pumpUpload(tester);

      const copy = PrescriptionCopy.english;
      expect(find.text(copy.howToOrder), findsOneWidget);
      expect(copy.steps, hasLength(5));

      var previous = -1.0;
      for (var index = 0; index < copy.steps.length; index++) {
        final step = copy.steps[index];
        expect(find.text('${index + 1}'), findsOneWidget, reason: step.title);

        final position = tester.getTopLeft(find.text(step.title)).dy;
        expect(position, greaterThan(previous), reason: step.title);
        previous = position;
      }
    });

    testWidgets('it sits below the form, not above it', (tester) async {
      await pumpUpload(tester);

      // Someone who knows the flow should not scroll past an explanation to
      // reach the buttons.
      expect(
        tester.getTopLeft(find.text('Use\nCamera')).dy,
        lessThan(
          tester.getTopLeft(find.text(PrescriptionCopy.english.howToOrder)).dy,
        ),
      );
    });
  });

  group('the language switch', () {
    testWidgets('opens in English, showing both codes at once', (
      tester,
    ) async {
      await pumpUpload(tester);

      // Codes, not full names: two buttons of names crowd the top of the
      // screen. Both are always shown, so the switch cannot be read as naming
      // only where you are.
      expect(find.text('ENG'), findsOneWidget);
      expect(find.text('മ'), findsOneWidget);
      expect(find.text('English'), findsNothing);
      expect(find.text('മലയാളം'), findsNothing);

      expect(find.text(PrescriptionCopy.english.heading), findsOneWidget);
      expect(find.text(PrescriptionCopy.malayalam.heading), findsNothing);
    });

    testWidgets('the full name still reaches a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUpload(tester);

      // "ENG" read out as three letters would be worse than useless.
      expect(find.bySemanticsLabel('English'), findsOneWidget);
      expect(find.bySemanticsLabel('മലയാളം'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('switching turns the whole screen over', (tester) async {
      await pumpUpload(tester);

      await tester.tap(find.text('മ'));
      await tester.pumpAndSettle();

      const ml = PrescriptionCopy.malayalam;
      expect(find.text(ml.heading), findsOneWidget);
      expect(find.text(ml.intro), findsOneWidget);
      expect(find.text(ml.useCamera), findsOneWidget);
      expect(find.text(ml.useGallery), findsOneWidget);
      expect(find.text(ml.patientLabel), findsOneWidget);
      expect(find.text(ml.patientHint), findsOneWidget);
      expect(find.text(ml.durationHeading), findsOneWidget);
      expect(find.text(ml.keepInMind), findsOneWidget);
      expect(find.text(ml.howToOrder), findsOneWidget);
      expect(find.text(ml.pharmacistTitle), findsOneWidget);
      expect(find.text(ml.free), findsOneWidget);
      expect(find.text(ml.proceed), findsOneWidget);

      // Nothing of the English is left behind.
      const en = PrescriptionCopy.english;
      expect(find.text(en.heading), findsNothing);
      expect(find.text(en.keepInMind), findsNothing);
      expect(find.text(en.proceed), findsNothing);
    });

    testWidgets('the procedure is translated too, step for step', (
      tester,
    ) async {
      await pumpUpload(tester);

      await tester.tap(find.text('മ'));
      await tester.pumpAndSettle();

      const ml = PrescriptionCopy.malayalam;
      const en = PrescriptionCopy.english;
      expect(ml.steps, hasLength(en.steps.length));
      expect(ml.rules, hasLength(en.rules.length));

      for (final step in ml.steps) {
        expect(find.text(step.title), findsOneWidget);
        expect(find.text(step.detail), findsOneWidget);
      }
      for (final rule in ml.rules) {
        expect(find.text(rule), findsOneWidget);
      }
    });

    testWidgets('switching back restores the English', (tester) async {
      await pumpUpload(tester);

      await tester.tap(find.text('മ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ENG'));
      await tester.pumpAndSettle();

      expect(find.text(PrescriptionCopy.english.heading), findsOneWidget);
      expect(find.text(PrescriptionCopy.malayalam.heading), findsNothing);
    });

    testWidgets('choosing a language does not disturb the form', (
      tester,
    ) async {
      await pumpUpload(tester);

      await tester.tap(find.text('1 month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('മ'));
      await tester.pumpAndSettle();

      // The duration survives the switch: this is a relabel, not a reset.
      final chosen = tester.widget<Text>(find.text('1 month'));
      expect(chosen, isNotNull);
      expect(
        find.text(PrescriptionCopy.malayalam.durationHeading),
        findsOneWidget,
      );
    });

    test('every language answers with a full table', () {
      for (final language in AppLanguage.values) {
        final copy = PrescriptionCopy.of(language);
        expect(copy.rules, hasLength(3));
        expect(copy.steps, hasLength(5));
        for (final step in copy.steps) {
          expect(step.title, isNotEmpty);
          expect(step.detail, isNotEmpty);
        }
      }
      expect(AppLanguage.english.other, AppLanguage.malayalam);
      expect(AppLanguage.malayalam.other, AppLanguage.english);
    });
  });

  group('how much medicine is needed', () {
    test('every option carries its own run of days', () {
      expect(MedicineDuration.oneWeek.days, 7);
      expect(MedicineDuration.fifteenDays.days, 15);
      expect(MedicineDuration.oneMonth.days, 30);
      expect(MedicineDuration.twoMonths.days, 60);
      expect(MedicineDuration.threeMonths.days, 90);
    });

    test('the supply label names both the run and the days', () {
      expect(
        MedicineDuration.oneMonth.supplyLabel,
        "1 month · 30 days' supply",
      );
    });

    testWidgets('the chooser offers every option, none picked to begin with', (
      tester,
    ) async {
      await pumpUpload(tester, size: const Size(400, 1800));

      expect(find.text('How much do you need?'), findsOneWidget);
      for (final duration in MedicineDuration.values) {
        expect(
          find.text(duration.label),
          findsOneWidget,
          reason: duration.label,
        );
      }
      expect(find.text('Custom days'), findsOneWidget);
    });

    testWidgets('picking one marks it and leaves the rest unmarked', (
      tester,
    ) async {
      await pumpUpload(tester, size: const Size(400, 1800));

      await tester.tap(find.text('1 month'));
      await tester.pumpAndSettle();

      // Exactly one chip is drawn in the selected style.
      final selected = find.byWidgetPredicate((widget) {
        if (widget is! Container) {
          return false;
        }
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.color == AppColors.offerTint &&
            decoration.borderRadius == BorderRadius.circular(20);
      });
      expect(selected, findsOneWidget);
    });

    testWidgets('picking custom days reveals the manual days input field', (
      tester,
    ) async {
      await pumpUpload(tester, size: const Size(400, 1800));

      expect(find.text('Enter number of days'), findsNothing);

      await tester.tap(find.text('Custom days'));
      await tester.pumpAndSettle();

      expect(find.text('Enter number of days'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('a duration alone does not unlock proceeding', (tester) async {
      await pumpUpload(tester, size: const Size(400, 1800));

      await tester.tap(find.text('1 month'));
      await tester.pumpAndSettle();

      // The file and the patient are both still missing.
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Proceed'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });
  group('intake codes', () {
    test('three digits are morning, afternoon and night in that order', () {
      final night = IntakePattern.tryParse('001')!;
      expect(night.morning, 0);
      expect(night.afternoon, 0);
      expect(night.night, 1);
      expect(night.perDay, 1);

      final twice = IntakePattern.tryParse('101')!;
      expect(twice.perDay, 2);
      expect(twice.code, '101');

      final day = IntakePattern.tryParse('110')!;
      expect(day.morning, 1);
      expect(day.afternoon, 1);
      expect(day.night, 0);
    });

    test('a code reads the same written with or without separators', () {
      expect(IntakePattern.tryParse('1-0-1'), IntakePattern.tryParse('101'));
      expect(IntakePattern.tryParse('1 0 1'), IntakePattern.tryParse('101'));
    });

    test('a half-typed code is not a dose', () {
      // "10" is someone mid-keystroke, not a zero night dose.
      expect(IntakePattern.tryParse('10'), isNull);
      expect(IntakePattern.tryParse(''), isNull);
      expect(IntakePattern.tryParse('1010'), isNull);
    });

    test('the total is the daily dose over the run', () {
      const copy = PrescriptionCopy.english;
      final pattern = IntakePattern.tryParse('101')!;
      expect(pattern.totalFor(30), 60);
      expect(pattern.totalFor(7), 14);
      expect(
        pattern.labelWith(copy.intakeSlots, copy.intakeNotSet),
        'Morning & night',
      );
    });

    test('the code spells itself out in whichever language is showing', () {
      const english = PrescriptionCopy.english;
      const malayalam = PrescriptionCopy.malayalam;

      final night = IntakePattern.tryParse('001')!;
      expect(
        night.labelWith(english.intakeSlots, english.intakeNotSet),
        'Night',
      );
      expect(
        night.labelWith(malayalam.intakeSlots, malayalam.intakeNotSet),
        malayalam.intakeSlots.last,
      );

      final day = IntakePattern.tryParse('110')!;
      expect(
        day.labelWith(english.intakeSlots, english.intakeNotSet),
        'Morning & afternoon',
      );

      // A dose above one is said, not swallowed by the label.
      final twice = IntakePattern.tryParse('202')!;
      expect(
        twice.labelWith(english.intakeSlots, english.intakeNotSet),
        'Morning x2 & night x2'.replaceAll('x', '×'),
      );

      expect(
        IntakePattern.none.labelWith(english.intakeSlots, english.intakeNotSet),
        'Not set',
      );
    });
  });

  group('recurring orders', () {
    testWidgets('the dates only appear once the repeat is switched on', (
      tester,
    ) async {
      await pumpUpload(tester);

      const copy = PrescriptionCopy.english;
      expect(find.text(copy.recurringHeading), findsOneWidget);
      expect(find.text(copy.fromDate), findsNothing);
      expect(find.text(copy.dueDate), findsNothing);
      expect(find.text(copy.neverExpires), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text(copy.fromDate), findsOneWidget);
      expect(find.text(copy.dueDate), findsOneWidget);
      expect(find.text(copy.neverExpires), findsOneWidget);
      // Today, filled in rather than left as another blank to answer.
      expect(find.text(formatDate(DateTime.now())), findsOneWidget);
      expect(find.text(copy.selectDate), findsOneWidget);
    });

    testWidgets('ticking never expires answers the due date', (tester) async {
      await pumpUpload(tester);

      const copy = PrescriptionCopy.english;
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
      // Once on the row as the answer, once as the tick's own label.
      expect(find.text(copy.neverExpires), findsNWidgets(2));
      expect(find.text(copy.selectDate), findsNothing);
    });

    test('a repeat with no end and no tick is not answered yet', () {
      final form = PrescriptionFormController();
      addTearDown(form.dispose);

      expect(form.hasSchedule, isTrue, reason: 'a one-off needs no dates');

      form.setRecurring(true);
      expect(form.hasSchedule, isFalse, reason: 'the due date is still blank');

      form.setNeverExpires(true);
      expect(form.hasSchedule, isTrue);
      expect(form.schedule!.neverExpires, isTrue);
      expect(form.schedule!.until, isNull);

      form.setNeverExpires(false);
      form.setUntil(form.from.subtract(const Duration(days: 1)));
      expect(form.hasSchedule, isFalse, reason: 'it would end before it began');
      expect(form.dueDateIsBackwards, isTrue);

      form.setUntil(form.from.add(const Duration(days: 60)));
      expect(form.hasSchedule, isTrue);
      expect(form.dueDateIsBackwards, isFalse);
    });

    test('an open-ended repeat covers every day from its start', () {
      final start = DateTime(2026, 9, 1);
      const day = Duration(days: 1);

      final open = RecurringSchedule(from: start);
      expect(open.covers(start), isTrue);
      expect(open.covers(start.subtract(day)), isFalse);
      expect(open.covers(DateTime(2030, 1, 1)), isTrue);

      final closed = RecurringSchedule(
        from: start,
        until: DateTime(2026, 12, 1),
      );
      expect(closed.covers(DateTime(2026, 12, 1)), isTrue);
      expect(closed.covers(DateTime(2026, 12, 2)), isFalse);
    });
  });

  group('the prescriptions already uploaded', () {
    late Patient asha;

    setUp(() {
      PatientBook.instance.reset();
      PrescriptionBook.instance.reset();
      CartService.instance.reset();
      asha = PatientBook.instance.add(
        name: 'Asha Menon',
        phone: '9000012345',
        dob: DateTime(1990, 4, 12),
        gender: PatientGender.female,
        relation: PatientRelation.spouse,
      );
    });

    tearDown(() {
      PatientBook.instance.reset();
      PrescriptionBook.instance.reset();
      CartService.instance.reset();
    });

    PrescriptionRecord seedRecord({
      List<PrescriptionMedicine>? medicines,
      RecurringSchedule? recurring,
    }) {
      return PrescriptionBook.instance.add(
        patient: asha,
        fileName: 'prescription.jpg',
        duration: MedicineDuration.oneMonth,
        recurring: recurring,
        medicines: medicines,
      );
    }

    testWidgets('one uploaded turns the screen into the list', (tester) async {
      seedRecord();
      await pumpUpload(tester);

      const copy = PrescriptionCopy.english;
      expect(find.text(copy.yourPrescriptions), findsOneWidget);
      expect(find.text('prescription.jpg'), findsOneWidget);
      expect(find.text('Asha Menon'), findsOneWidget);

      // The upload form has stood down; it is reached from the button now.
      expect(find.text('Use\nCamera'), findsNothing);
      expect(find.text(copy.proceed), findsNothing);
      expect(find.text(copy.addNewPrescription), findsOneWidget);
    });

    testWidgets('the card names its three columns', (tester) async {
      seedRecord(medicines: [PrescriptionMedicine(name: 'Dolo 650')]);
      await pumpUpload(tester);

      const copy = PrescriptionCopy.english;
      expect(find.text(copy.product), findsOneWidget);
      expect(find.text(copy.intake), findsOneWidget);
      expect(find.text(copy.total), findsOneWidget);
      expect(find.text(copy.patientRow), findsOneWidget);
      expect(find.text(copy.doctorRow), findsOneWidget);
    });

    testWidgets('typing a code fills in the total for the whole run', (
      tester,
    ) async {
      seedRecord(medicines: [PrescriptionMedicine(name: 'Dolo 650')]);
      await pumpUpload(tester);

      // Nothing to count until the code is there.
      expect(find.text('—'), findsOneWidget);

      await tester.enterText(
        find.ancestor(of: find.text('000'), matching: find.byType(TextField)),
        '101',
      );
      await tester.pumpAndSettle();

      // Two a day over the thirty days the prescription was uploaded for.
      expect(find.text('60'), findsOneWidget);
      expect(
        find.textContaining(
          'Morning & night · 2/day × 30 = 60 units',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a repeat says its dates on the card', (tester) async {
      seedRecord(recurring: RecurringSchedule(from: DateTime(2026, 9, 1)));
      await pumpUpload(tester);

      const copy = PrescriptionCopy.english;
      expect(find.text(copy.repeatsRow), findsOneWidget);
      expect(find.textContaining('01 Sep 2026'), findsOneWidget);
      expect(find.textContaining('never expires'), findsOneWidget);
    });

    testWidgets('the doctor is typed onto the card and stays there', (
      tester,
    ) async {
      final record = seedRecord();
      await pumpUpload(tester);

      await tester.enterText(
        find.ancestor(
          of: find.text("Doctor's name"),
          matching: find.byType(TextField),
        ),
        'Dr. Nair',
      );
      await tester.pumpAndSettle();

      expect(record.doctor, 'Dr. Nair');
    });

    testWidgets('nothing goes to the cart until a line is complete', (
      tester,
    ) async {
      seedRecord(medicines: [PrescriptionMedicine(name: 'Dolo 650')]);
      await pumpUpload(tester);

      const copy = PrescriptionCopy.english;
      // byWidgetPredicate, not byType: FilledButton.icon builds a private
      // subclass, which an exact runtime-type match walks straight past.
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(copy.addToCart),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );
      // A named medicine with no dose says nothing about what to dispense.
      expect(button.onPressed, isNull);
    });

    testWidgets('a complete line goes to the cart as the whole run', (
      tester,
    ) async {
      final record = seedRecord(
        medicines: [
          PrescriptionMedicine(
            name: 'Dolo 650',
            intake: IntakePattern(morning: 1, night: 1),
          ),
          // Incomplete, and so left behind rather than sent as a blank.
          PrescriptionMedicine(name: 'Shelcal'),
        ],
      );
      await pumpUpload(tester);

      const copy = PrescriptionCopy.english;
      await tester.tap(find.text(copy.addToCart));
      await tester.pumpAndSettle();

      final lines = CartService.instance.lines;
      expect(lines, hasLength(1));
      expect(lines.single.name, 'Dolo 650');
      expect(lines.single.qty, 60);
      // Priced by the pharmacist, not guessed at here.
      expect(lines.single.isPriced, isFalse);

      expect(record.inCart, isTrue);
      expect(find.text(copy.inCart), findsNWidgets(2));
    });

    testWidgets('a prescription in the cart is not sent twice', (tester) async {
      seedRecord(
        medicines: [
          PrescriptionMedicine(
            name: 'Dolo 650',
            intake: IntakePattern(night: 1),
          ),
        ],
      );
      await pumpUpload(tester);

      const copy = PrescriptionCopy.english;
      await tester.tap(find.text(copy.addToCart));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(copy.inCart).last,
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(CartService.instance.itemCount, 30);
    });

    testWidgets('deleting offers the way back', (tester) async {
      seedRecord();
      await pumpUpload(tester);

      const copy = PrescriptionCopy.english;
      await tester.tap(find.text(copy.delete));
      await tester.pumpAndSettle();

      expect(PrescriptionBook.instance.isEmpty, isTrue);
      // Empty again, so the screen is the upload form again.
      expect(find.text('Use\nCamera'), findsOneWidget);
      expect(find.text(copy.prescriptionRemoved), findsOneWidget);

      await tester.tap(find.text(copy.undo));
      await tester.pumpAndSettle();

      expect(PrescriptionBook.instance.length, 1);
      expect(find.text('prescription.jpg'), findsOneWidget);
    });

    testWidgets('a restored prescription goes back where it was', (
      tester,
    ) async {
      final first = seedRecord();
      PrescriptionBook.instance.add(
        patient: asha,
        fileName: 'second.jpg',
        duration: MedicineDuration.oneWeek,
      );
      await pumpUpload(tester, size: const Size(400, 4200));

      const copy = PrescriptionCopy.english;
      await tester.tap(find.text(copy.delete).first);
      await tester.pumpAndSettle();
      expect(PrescriptionBook.instance.records.single.fileName, 'second.jpg');

      await tester.tap(find.text(copy.undo));
      await tester.pumpAndSettle();

      expect(PrescriptionBook.instance.records.first.id, first.id);
      expect(PrescriptionBook.instance.records.last.fileName, 'second.jpg');
    });

    testWidgets('adding a medicine adds an empty line to fill in', (
      tester,
    ) async {
      final record = seedRecord();
      await pumpUpload(tester);

      const copy = PrescriptionCopy.english;
      expect(record.medicines, isEmpty);

      await tester.tap(find.text(copy.addMedicine));
      await tester.pumpAndSettle();

      expect(record.medicines, hasLength(1));
      expect(find.text(copy.medicineHint), findsOneWidget);
    });

    testWidgets('add new prescription opens the upload form over the list', (
      tester,
    ) async {
      seedRecord();
      await pumpUpload(tester);

      const copy = PrescriptionCopy.english;
      await tester.tap(find.text(copy.addNewPrescription));
      await tester.pumpAndSettle();

      expect(find.byType(PrescriptionFormSheet), findsOneWidget);
      expect(find.text(copy.newPrescription), findsOneWidget);
      // The same form, not a second one written for the sheet.
      expect(find.text('Use\nCamera'), findsOneWidget);
      expect(find.text('Use\nGallery'), findsOneWidget);
      expect(find.text(copy.patientHint), findsOneWidget);
      expect(find.text(copy.recurringHeading), findsOneWidget);

      // Nothing has been picked, so there is nothing to file yet.
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(copy.addPrescription),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('the card lays out on a narrow screen, in either language', (
      tester,
    ) async {
      seedRecord(
        medicines: [
          PrescriptionMedicine(
            name: 'Dolo 650mg Tablet',
            intake: IntakePattern(morning: 1, afternoon: 1, night: 1),
          ),
        ],
        recurring: RecurringSchedule(from: DateTime(2026, 9, 1)),
      );
      // An overflow anywhere on the card throws, so reaching the assertions
      // is the assertion.
      await pumpUpload(tester, size: const Size(320, 3200));

      expect(find.text('90'), findsOneWidget);

      await tester.tap(find.text('മ'));
      await tester.pumpAndSettle();

      expect(
        find.text(PrescriptionCopy.malayalam.yourPrescriptions),
        findsOneWidget,
      );
      expect(find.text('90'), findsOneWidget);
    });

    test('the totals across a card only count the lines that are ready', () {
      final record = seedRecord(
        medicines: [
          PrescriptionMedicine(
            name: 'Dolo 650',
            intake: IntakePattern(morning: 1, night: 1),
          ),
          PrescriptionMedicine(
            name: 'Shelcal',
            intake: IntakePattern(morning: 1),
          ),
          PrescriptionMedicine(name: 'Half-typed'),
        ],
      );

      expect(record.days, 30);
      expect(record.dispensable, hasLength(2));
      expect(record.totalUnits, 90);
      expect(record.canOrder, isTrue);
    });
  });
}
