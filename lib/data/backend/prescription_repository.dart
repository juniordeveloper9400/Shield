import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../module/orders/purchase_service.dart' show LinkedOrder;
import '../../module/patients/patient_book.dart';
import '../../module/prescription/medicine_duration.dart';
import 'backend_http.dart';
import 'backend_patient_repository.dart';

/// One prescription's pharmacist-built intake card, as read back from
/// `backend/api`.
class RemotePrescriptionCard {
  final String code;
  final String? uuid;

  /// `AWAITING_REVIEW` / `READ` / `IN_CART` / `ORDERED` — the console's own
  /// status trail.
  final String status;
  final String doctor;
  final List<RemotePrescriptionMedicine> medicines;

  /// The uploaded script, as the `data:` URI stored in `app.prescription
  /// _image` (sort 0) — null when none was attached at upload.
  final String? image;

  /// The order this prescription was most recently placed into — null for one
  /// that was only uploaded. What the card's order-tracking status reads.
  final LinkedOrder? order;

  RemotePrescriptionCard({
    required this.code,
    required this.uuid,
    required this.status,
    required this.doctor,
    required this.medicines,
    this.image,
    this.order,
  });

  /// The pharmacist has entered the lines — the app card can expand.
  bool get hasIntakeCard => medicines.isNotEmpty;
}

/// One line on a [RemotePrescriptionCard].
class RemotePrescriptionMedicine {
  final String name;
  final String pack;
  final int morning;
  final int afternoon;
  final int night;

  /// Units the pharmacist wrote for this line — entered in the console, not
  /// derived.
  final int totalUnits;

  /// How and when to take it — `app.prescription_medicine.route_time`.
  final String routeTime;

  const RemotePrescriptionMedicine({
    required this.name,
    required this.pack,
    required this.morning,
    required this.afternoon,
    required this.night,
    required this.totalUnits,
    this.routeTime = '',
  });
}

/// Uploads and reads back prescriptions through `backend/api`'s
/// `/v1/member/prescriptions` routes — see `prescription.service.ts`, never
/// a direct Neon connection.
///
/// Best-effort: an unconfigured backend (tests) or the network down makes
/// the call no-op and return null rather than throw. Uploading a
/// prescription must never fail because the backend is unreachable —
/// [PrescriptionBook] stays the source of truth for the running app, and
/// this row is the durable copy.
///
/// Placing the fulfilment order (the old direct-Neon
/// `OrderRepository.savePrescriptionOrder` + this class's own `markOrdered`)
/// moved to [BackendOrderRepository.submitPrescriptionOrder] — the backend's
/// `POST /v1/member/prescription-orders` already moves each prescription's
/// own status to `ORDERED` in the same transaction as the order, so there is
/// no separate "mark ordered" call to make afterwards any more.
class PrescriptionRepository {
  const PrescriptionRepository._();

  static const PrescriptionRepository instance = PrescriptionRepository._();

  bool get isAvailable => BackendHttp.isConfigured;

  /// Records a freshly uploaded prescription against [patient] — resolved to
  /// the backend's numeric patient id first ([Patient.remoteId] when
  /// already synced, else a fresh [BackendPatientRepository.upsert]), since
  /// the backend has no inline "create the patient as part of this upload"
  /// path the way the old direct-Neon write did.
  ///
  /// Medicine lines are not accepted here: the backend only ever lets
  /// *staff* add them (`POST /v1/staff/prescriptions/:id/medicines`) — a
  /// member-submitted line at upload time was already always empty in
  /// practice (the counter fills them in), so nothing is lost.
  ///
  /// Returns the created prescription's id, or null when nothing was
  /// written.
  Future<String?> insertUpload({
    required Patient patient,
    required String fileName,
    String? image,
    String doctor = '',
    MedicineDuration? duration,
    int? customDays,
    DateTime? recurringFrom,
    DateTime? recurringUntil,
  }) async {
    if (!BackendHttp.isConfigured) {
      return null;
    }
    final patientId = await _patientIdFor(patient);
    if (patientId == null) {
      BackendHttp.log(
        'PrescriptionRepository.insertUpload: could not resolve a patient id for ${patient.name}',
      );
      return null;
    }
    try {
      final images = (image == null || image.isEmpty) ? const <String>[] : [image];
      final created = await BackendHttp.instance.request(
        'POST',
        '/v1/member/prescriptions',
        body: {
          'patientId': patientId,
          if (images.isNotEmpty) 'images': images,
          'fileName': fileName,
          'doctor': doctor,
          if (_durationName(duration) != null) 'duration': _durationName(duration),
          if (customDays != null) 'customDays': customDays,
          if (recurringFrom != null) 'recurringFrom': _isoDate(recurringFrom),
          if (recurringUntil != null) 'recurringUntil': _isoDate(recurringUntil),
        },
      ) as Map<String, dynamic>;
      final id = created['id']?.toString();
      if (id == null) {
        return null;
      }
      // The server's own account of what it stored — a mismatch against
      // what was sent is worth knowing about even though this call still
      // succeeds on the row alone (the image is a nice-to-have on the
      // card, not something to fail the whole upload over).
      final storedCount = (created['images'] as List?)?.length ?? 0;
      if (images.isNotEmpty && storedCount < images.length) {
        BackendHttp.log(
          'PrescriptionRepository.insertUpload: sent ${images.length} image(s), '
          'server stored $storedCount — id=$id',
        );
      }
      return id;
    } catch (error) {
      BackendHttp.log('PrescriptionRepository.insertUpload failed', error: error);
      return null;
    }
  }

  /// [Patient.remoteId] when the patient has already been synced, else a
  /// fresh [BackendPatientRepository.upsert] to get one.
  Future<int?> _patientIdFor(Patient patient) async {
    final existing = patient.remoteId;
    if (existing != null) {
      return int.tryParse(existing);
    }
    final created = await BackendPatientRepository.instance.upsert(
      name: patient.name,
      phone: patient.phone,
      address: patient.address,
      dob: patient.dob,
      gender: patient.gender,
      relation: patient.relation,
      abhaId: patient.abhaId,
    );
    return created == null ? null : int.tryParse(created);
  }

  /// Marks a [softDelete] refusal because the store has already started on
  /// the order this script was placed into — the rest of the string is the
  /// message to show the member.
  static const String lockedPrefix = 'LOCKED:';

  /// Soft-deletes a prescription row. Returns null on success, or the
  /// failure's own detail otherwise, so the caller can tell a store-side
  /// lock (409 `ORDER_LOCKED`) from a plain network failure rather than
  /// showing one blanket "try again" for both.
  Future<String?> softDelete(String id) async {
    if (!BackendHttp.isConfigured) {
      return 'backend not configured';
    }
    try {
      await BackendHttp.instance.request('DELETE', '/v1/member/prescriptions/$id');
      return null;
    } on BackendHttpException catch (error) {
      if (error.isConflict) return '$lockedPrefix${error.message}';
      BackendHttp.log('PrescriptionRepository.softDelete failed', error: error);
      return error.toString();
    } catch (error) {
      BackendHttp.log('PrescriptionRepository.softDelete failed', error: error);
      return error.toString();
    }
  }

  /// The pharmacist-built intake cards for every prescription on the
  /// account — `GET /v1/member/prescriptions`, which already carries each
  /// one's images, medicines and linked order in a single call (unlike the
  /// old direct-Neon read, there is no per-prescription second request).
  ///
  /// Returns null when the backend is off or unreachable (so "not loaded"
  /// reads differently from "nothing sent yet"). [memberPhone] is accepted
  /// for parity with the old direct-Neon signature; unused.
  Future<List<RemotePrescriptionCard>?> fetchForMember([
    String memberPhone = '',
  ]) async {
    if (!BackendHttp.isConfigured) {
      return null;
    }
    try {
      final rows = await BackendHttp.instance.request('GET', '/v1/member/prescriptions')
          as List<dynamic>;
      return [for (final row in rows.cast<Map<String, dynamic>>()) _toCard(row)];
    } catch (error) {
      BackendHttp.log('PrescriptionRepository.fetchForMember failed', error: error);
      return null;
    }
  }

  static RemotePrescriptionCard _toCard(Map<String, dynamic> row) {
    final medicines = (row['medicines'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((m) => (m['name'] ?? '').toString().trim().isNotEmpty)
        .map(
          (m) => RemotePrescriptionMedicine(
            name: (m['name'] ?? '').toString().trim(),
            pack: (m['pack'] ?? '').toString(),
            morning: _toInt(m['doseMorning']),
            afternoon: _toInt(m['doseAfternoon']),
            night: _toInt(m['doseNight']),
            totalUnits: _toInt(m['totalUnits']),
            routeTime: (m['routeTime'] ?? '').toString(),
          ),
        )
        .toList();
    final images = (row['images'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((img) => (img['image'] as String?)?.trim())
        .where((img) => (img ?? '').isNotEmpty)
        .toList();
    return RemotePrescriptionCard(
      code: (row['code'] ?? '').toString(),
      uuid: row['id']?.toString(),
      status: (row['status'] ?? '').toString().toUpperCase(),
      doctor: (row['doctor'] ?? '').toString(),
      medicines: medicines,
      image: images.isEmpty ? null : images.first,
      order: linkedOrderFromRow(row['order'] as Map<String, dynamic>?),
    );
  }

  /// Reads the `order` block a prescription row carries — the backend's own
  /// `{ id, code, status, storeContactedAt, reviewedAt, billed }`, already
  /// real JSON types (unlike the old direct-Neon read, which had to parse
  /// Postgres's text-only wire format) — into a [LinkedOrder]. Null for a
  /// prescription that was never ordered.
  @visibleForTesting
  static LinkedOrder? linkedOrderFromRow(Map<String, dynamic>? order) {
    if (order == null) {
      return null;
    }
    return LinkedOrder.fromTokens(
      code: order['code'],
      status: order['status'],
      storeContactedAt: order['storeContactedAt'],
      reviewedAt: order['reviewedAt'],
      billed: order['billed'],
    );
  }

  static int _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String? _durationName(MedicineDuration? d) => switch (d) {
        MedicineDuration.oneWeek => 'ONE_WEEK',
        MedicineDuration.fifteenDays => 'FIFTEEN_DAYS',
        MedicineDuration.oneMonth => 'ONE_MONTH',
        MedicineDuration.twoMonths => 'TWO_MONTHS',
        MedicineDuration.threeMonths => 'THREE_MONTHS',
        null => null,
      };

  /// `2026-08-31` — an unambiguous value for the backend's date fields.
  static String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
