import 'package:flutter/foundation.dart';

import '../../module/location/address_book.dart';
import 'backend_http.dart';

/// Reads and writes saved delivery addresses through `backend/api`'s
/// `/v1/member/addresses` routes — see `identity.service.ts`.
///
/// `PATCH`/`DELETE /v1/member/addresses/:id` are new routes added alongside
/// this class (mirroring the pre-existing `patients/:id` ones exactly) —
/// unlike `POST`/`GET`, which `shield agent_invester`'s own simpler
/// `AddressRepository` already proved out, this app's own [AddressRepository]
/// (the class `AddressBook` actually calls) needs full CRUD to keep its
/// existing edit/soft-delete behavior, not just create-and-list.
///
/// `lib/data/neon/address_repository.dart` tries this first and falls back
/// to its own direct-Neon path when the backend is unavailable, there is no
/// session yet, or the call fails.
///
/// Every method is best-effort: with an unconfigured or unsigned-in
/// backend, writes no-op and reads return null. Saving an address must
/// never fail because the backend is unreachable — [AddressBook] stays the
/// source of truth for the running app.
class BackendAddressRepository {
  BackendAddressRepository._({BackendHttp? http}) : _http = http ?? BackendHttp.instance;

  static final BackendAddressRepository instance = BackendAddressRepository._();

  /// Test-only: an instance wired to an injected [BackendHttp].
  @visibleForTesting
  factory BackendAddressRepository.test({required BackendHttp http}) =>
      BackendAddressRepository._(http: http);

  final BackendHttp _http;

  /// Whether a write or read would actually reach the backend — needs a
  /// live member session on top of being configured, since every route
  /// here is member-authenticated.
  bool get isAvailable => _http.isEnabled && _http.isSignedIn;

  /// Inserts a new address, or updates the existing row when [id] is given
  /// (the backend's numeric address id, as a string — the value a previous
  /// call returned). [patientId] carries the `'remote-<id>'` form
  /// [BackendPatientRepository] hands out, unwrapped back to a bare
  /// numeric id here — null for an address saved on its own, or one that
  /// only ever named a patient never written to the backend (a device-local
  /// id can't resolve there, so it is treated the same as no patient).
  /// Returns the row's id, or null when nothing was written.
  Future<String?> upsert({
    String? id,
    required String label,
    required String house,
    required String area,
    required String landmark,
    required String pincode,
    required String firstName,
    required String lastName,
    required String phone,
    String? patientId,
  }) async {
    if (!isAvailable) {
      return null;
    }

    final barePatientId = _barePatientId(patientId);
    final body = {
      'label': label,
      'house': house,
      'area': area,
      'landmark': landmark,
      'pincode': pincode,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      if (barePatientId != null) 'patientId': barePatientId,
    };

    try {
      if (id != null) {
        final updated = await _http.request('PATCH', '/v1/member/addresses/$id', body: body) as Map<String, dynamic>;
        return updated['id']?.toString();
      }
      final created = await _http.request('POST', '/v1/member/addresses', body: body) as Map<String, dynamic>;
      final newId = created['id']?.toString();
      BackendHttp.log('BackendAddressRepository.upsert: saved $house, $area ($newId)');
      return newId;
    } on BackendHttpException catch (error) {
      if (error.isNotFound) {
        // The row is gone (a stale id from a prior run) — fall through to a
        // fresh insert rather than silently losing the address.
        return upsert(
          label: label,
          house: house,
          area: area,
          landmark: landmark,
          pincode: pincode,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          patientId: patientId,
        );
      }
      BackendHttp.log('BackendAddressRepository.upsert failed', error: error);
      return null;
    } catch (error) {
      BackendHttp.log('BackendAddressRepository.upsert failed', error: error);
      return null;
    }
  }

  /// Soft-deletes an address row. A no-op when [id] no longer exists or
  /// belongs to someone else — same best-effort contract as every write
  /// here.
  Future<void> softDelete(String id) async {
    if (!isAvailable) {
      return;
    }
    try {
      await _http.request('DELETE', '/v1/member/addresses/$id');
    } catch (error) {
      BackendHttp.log('BackendAddressRepository.softDelete failed', error: error);
    }
  }

  /// Every non-deleted address for the signed-in member. Returns `null`
  /// (not an empty list) when there is no session yet or the read failed.
  Future<List<Address>?> listForMember() async {
    if (!isAvailable) {
      return null;
    }
    try {
      final rows = await _http.request('GET', '/v1/member/addresses') as List<dynamic>;
      return rows.cast<Map<String, dynamic>>().map(_toAddress).toList();
    } catch (error) {
      BackendHttp.log('BackendAddressRepository.listForMember failed', error: error);
      return null;
    }
  }

  /// One address row → an [Address]. The id is derived from the row's
  /// numeric id so a reload lands on the same in-memory record, and
  /// `remoteId` is set so [AddressBook] knows this one is already backed
  /// by the backend. [patientId] is carried in the same `'remote-<id>'`
  /// form [BackendPatientRepository] hands out, so [AddressBook.forPatient]
  /// matches it.
  static Address _toAddress(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final patientId = row['patientId'];
    return Address(
      id: id.isEmpty ? '' : 'remote-$id',
      remoteId: id.isEmpty ? null : id,
      pincode: (row['pincode'] ?? '').toString(),
      house: (row['house'] ?? '').toString(),
      area: (row['area'] ?? '').toString(),
      landmark: (row['landmark'] ?? '').toString(),
      firstName: (row['firstName'] ?? '').toString(),
      lastName: (row['lastName'] ?? '').toString(),
      phone: (row['phone'] ?? '').toString(),
      label: _labelFrom((row['label'] ?? '').toString()),
      patientId: patientId == null ? null : 'remote-$patientId',
    );
  }

  static AddressLabel _labelFrom(String token) => switch (token.toUpperCase()) {
    'WORK' => AddressLabel.work,
    'OTHER' => AddressLabel.other,
    _ => AddressLabel.home,
  };

  /// Strips the `'remote-'` prefix [BackendPatientRepository]/[_toAddress]
  /// hand out for a synced row's local id, returning the bare numeric id a
  /// JSON body needs — or null for a patient never written to the backend
  /// (no id, or a device-local `'p3'`-style one).
  static int? _barePatientId(String? patientId) {
    if (patientId == null || !patientId.startsWith('remote-')) {
      return null;
    }
    return int.tryParse(patientId.substring('remote-'.length));
  }
}
