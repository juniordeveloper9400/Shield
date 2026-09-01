import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/neon/prescription_repository.dart';
import '../auth/auth_service.dart';
import 'prescription_record.dart';

/// Stands in for the pharmacy counter until a backend takes over.
///
/// The medicines on a prescription are keyed in by a pharmacist from the
/// uploaded image — the app only shows them back. This class is the seam
/// where that arrives: it waits the way a real review waits, then writes the
/// lines through [PrescriptionBook.fillFromPharmacy]. Replacing it with a
/// server push means replacing this file and nothing else, because the screen
/// is already written against a record that fills in later rather than one
/// that was complete all along.
class PharmacyDesk {
  const PharmacyDesk._();

  /// How long the counter takes to come back.
  ///
  /// Adjustable so a widget test can have the answer land at once instead of
  /// pumping a timer that is only there to imitate a person reading.
  static Duration reviewDelay = const Duration(milliseconds: 1500);

  /// Reads [record] and files what is on it.
  static Future<void> review(PrescriptionRecord record) async {
    if (reviewDelay > Duration.zero) {
      await Future<void>.delayed(reviewDelay);
    }
    // Gone by the time the counter answered — deleted, or undone and deleted
    // again. Writing to it would resurrect a record the member removed.
    if (PrescriptionBook.instance.indexOf(record.id) == -1) {
      return;
    }
    final doctor = prescriberFor(record.id);
    final medicines = medicinesFor(record.id);
    PrescriptionBook.instance.fillFromPharmacy(
      record.id,
      doctor: doctor,
      medicines: medicines,
    );

    // Mirror the counter's read onto the durable row so the admin console
    // shows the medicines and the AWAITING_REVIEW → READ move. Best-effort;
    // [record] is the live book object, so its remoteId is current if the
    // upload write has returned.
    final phone = AuthService.instance.currentUser.value?.phone;
    if (phone != null) {
      unawaited(
        PrescriptionRepository.instance.syncPharmacyRead(
          memberPhone: phone,
          prescriptionUuid: record.remoteId,
          fileName: record.fileName,
          doctor: doctor,
          medicines: medicines,
        ),
      );
    }
  }

  /// Two or three lines, chosen from the counter's shelf by the record's own
  /// id so the same prescription always reads back the same way.
  @visibleForTesting
  static List<PrescriptionMedicine> medicinesFor(String id) {
    final seed = _seed(id);
    final count = 2 + seed % 2;
    return [
      for (var offset = 0; offset < count; offset++)
        _shelf[(seed + offset) % _shelf.length],
    ];
  }

  @visibleForTesting
  static String prescriberFor(String id) =>
      _prescribers[_seed(id) % _prescribers.length];

  @visibleForTesting
  static void resetForTest() {
    reviewDelay = const Duration(milliseconds: 1500);
  }

  /// Digits out of `rx7`, so ids run through the shelf in order rather than
  /// landing on the same line every time.
  static int _seed(String id) {
    final digits = id.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? 0 : int.parse(digits);
  }

  static const List<String> _prescribers = [
    'Dr. Anitha Menon',
    'Dr. Rajeev Nair',
    'Dr. Suresh Kumar',
  ];

  static const List<PrescriptionMedicine> _shelf = [
    PrescriptionMedicine(
      name: 'Dolo 650mg Tablet',
      pack: 'Strip of 15 tablets',
      intake: IntakePattern(morning: 1, night: 1),
    ),
    PrescriptionMedicine(
      name: 'Pan 40mg Tablet',
      pack: 'Strip of 15 tablets',
      intake: IntakePattern(morning: 1),
    ),
    PrescriptionMedicine(
      name: 'Shelcal 500 Calcium',
      pack: 'Strip of 15 tablets',
      intake: IntakePattern(night: 1),
    ),
    PrescriptionMedicine(
      name: 'Metformin 500mg Tablet',
      pack: 'Strip of 20 tablets',
      intake: IntakePattern(morning: 1, night: 1),
    ),
    PrescriptionMedicine(
      name: 'Telmisartan 40mg Tablet',
      pack: 'Strip of 15 tablets',
      intake: IntakePattern(morning: 1, afternoon: 1),
    ),
    PrescriptionMedicine(
      name: 'Atorvastatin 10mg Tablet',
      pack: 'Strip of 10 tablets',
      intake: IntakePattern(night: 1),
    ),
  ];
}
