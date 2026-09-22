import 'package:flutter/foundation.dart';

import '../../module/patients/patient_book.dart';
import 'backend_http.dart';

/// Reads and writes the people on an account through `backend/api`'s
/// `/v1/member/patients` routes — see `identity.service.ts`.
///
/// Ported from `shield agent_invester/lib/data/backend/patient_repository.dart`.
/// `lib/data/neon/patient_repository.dart` (the class `PatientBook` actually
/// calls, whose own `uuid`-named parameters and return values this class
/// leaves untouched) tries this first and falls back to its own direct-Neon
/// path when the backend is unavailable, there is no session yet, or the
/// call fails.
///
/// Every method is best-effort: with an unconfigured or unsigned-in backend,
/// writes no-op and reads return null. Adding a patient must never fail
/// because the backend is unreachable — [PatientBook] stays the source of
/// truth for the running app.
class BackendPatientRepository {
  BackendPatientRepository._({BackendHttp? http}) : _http = http ?? BackendHttp.instance;

  static final BackendPatientRepository instance = BackendPatientRepository._();

  /// Test-only: an instance wired to an injected [BackendHttp].
  @visibleForTesting
  factory BackendPatientRepository.test({required BackendHttp http}) =>
      BackendPatientRepository._(http: http);

  final BackendHttp _http;

  /// Whether a write or read would actually reach the backend — needs a
  /// live member session on top of being configured, since every route here
  /// is member-authenticated.
  bool get isAvailable => _http.isEnabled && _http.isSignedIn;

  /// Inserts a new patient, or updates the existing row when [id] is given
  /// (the backend's numeric patient id, as a string — the value a previous
  /// call returned). Returns the row's id, or null when nothing was
  /// written.
  Future<String?> upsert({
    String? id,
    required String name,
    required String phone,
    required String address,
    required DateTime dob,
    required PatientGender gender,
    required PatientRelation relation,
    required String abhaId,
  }) async {
    if (!isAvailable) {
      return null;
    }

    final body = {
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'dob': _isoDate(dob),
      'gender': gender.name.toUpperCase(),
      'relation': relation.name.toUpperCase(),
      'abhaId': abhaId.replaceAll(RegExp(r'\D'), ''),
    };

    try {
      if (id != null) {
        final updated = await _http.request('PATCH', '/v1/member/patients/$id', body: body) as Map<String, dynamic>;
        return updated['id']?.toString();
      }

      final created = await _http.request('POST', '/v1/member/patients', body: body) as Map<String, dynamic>;
      final newId = created['id']?.toString();
      BackendHttp.log('BackendPatientRepository.upsert: saved ${body['name']} ($newId)');
      return newId;
    } on BackendHttpException catch (error) {
      if (error.isNotFound) {
        // The row is gone (a stale id from a prior run) — fall through to a
        // fresh insert rather than silently losing the patient.
        return upsert(
          name: name,
          phone: phone,
          address: address,
          dob: dob,
          gender: gender,
          relation: relation,
          abhaId: abhaId,
        );
      }
      BackendHttp.log('BackendPatientRepository.upsert failed', error: error);
      return null;
    } catch (error) {
      BackendHttp.log('BackendPatientRepository.upsert failed', error: error);
      return null;
    }
  }

  /// Soft-deletes a patient row. A no-op when [id] no longer exists or
  /// belongs to someone else — same best-effort contract as every write here.
  Future<void> softDelete(String id) async {
    if (!isAvailable) {
      return;
    }
    try {
      await _http.request('DELETE', '/v1/member/patients/$id');
    } catch (error) {
      BackendHttp.log('BackendPatientRepository.softDelete failed', error: error);
    }
  }

  /// Every non-deleted patient for the signed-in member. Returns `null`
  /// (not an empty list) when there is no session yet or the read failed,
  /// so the caller can tell "no saved patients" from "could not load them".
  Future<List<Patient>?> listForMember() async {
    if (!isAvailable) {
      return null;
    }
    try {
      final rows = await _http.request('GET', '/v1/member/patients') as List<dynamic>;
      return rows.cast<Map<String, dynamic>>().map(_toPatient).toList();
    } catch (error) {
      BackendHttp.log('BackendPatientRepository.listForMember failed', error: error);
      return null;
    }
  }

  /// One patient row → a [Patient]. The id is derived from the row's
  /// numeric id so a reload lands on the same in-memory record, and
  /// `remoteId` is set so [PatientBook] knows this one is already backed
  /// by the backend.
  static Patient _toPatient(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    return Patient(
      id: 'remote-$id',
      remoteId: id.isEmpty ? null : id,
      name: (row['name'] ?? '').toString(),
      phone: (row['phone'] ?? '').toString(),
      address: (row['address'] ?? '').toString(),
      dob: DateTime.tryParse((row['dob'] ?? '').toString()) ?? DateTime(2000),
      gender: _genderFrom(row['gender']?.toString()),
      relation: _relationFrom(row['relation']?.toString()),
      abhaId: (row['abhaId'] ?? '').toString(),
    );
  }

  static PatientGender _genderFrom(String? label) => PatientGender.values
      .firstWhere((g) => g.name.toUpperCase() == label, orElse: () => PatientGender.other);

  static PatientRelation _relationFrom(String? label) => PatientRelation.values
      .firstWhere((r) => r.name.toUpperCase() == label, orElse: () => PatientRelation.other);

  /// `1994-09-04` — an unambiguous value for the backend's `dob` field.
  static String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
