import '../../module/location/address_book.dart';
import '../backend/backend_address_repository.dart';
import 'neon_http.dart';

/// Reads and writes saved delivery addresses.
///
/// Tries `backend/api` first (`BackendAddressRepository`) and falls back to
/// the direct-Neon path below only when the backend is unavailable, there
/// is no session yet, or the call fails — both write the identical table
/// (`app.member_address`), this is a resilience fallback during the
/// migration off the compiled-in Neon credential, not two independently
/// maintained copies.
///
/// Every method is best-effort: with no `DATABASE_URL` compiled in (tests) or
/// the network down, writes no-op and reads return null. Saving an address
/// must never fail because the database is unreachable — [AddressBook] stays
/// the source of truth for the running app, and this table is the durable
/// copy that is read back on the next launch.
///
/// `app.member_address.member_id` is `NOT NULL`, so [upsert]'s own
/// direct-Neon path resolves the owning `app.users` row from the signed-in
/// mobile number first, inserting a minimal user if sign-in has not already
/// written one — the same convention as [PatientRepository].
class AddressRepository {
  const AddressRepository._();

  static const AddressRepository instance = AddressRepository._();

  /// Whether a write or read would actually reach a database — the backend
  /// or Neon.
  bool get isAvailable =>
      BackendAddressRepository.instance.isAvailable || NeonHttp.isConfigured;

  /// Inserts a new address, or updates the existing row when [uuid] is given
  /// (the value a previous call returned, held on [Address.remoteId] — the
  /// backend's own numeric id once this writes through it, still a Neon row
  /// uuid on the fallback path; either way opaque to every caller).
  ///
  /// [address] carries the fields to write, [Address.patientId] included —
  /// the `'remote-<uuid>'` form [PatientRepository] hands out, unwrapped back
  /// to a bare uuid here to resolve `app.patient.id`; null for an address
  /// saved on its own or one that only ever named a patient added on this
  /// device (a local `'p3'`-style id can't resolve to anything on the
  /// backend, so it is treated the same as no patient). Returns the row's
  /// id so the caller can pin it onto the in-memory record with
  /// [AddressBook.attachRemoteId]. Null when nothing was written.
  Future<String?> upsert({
    String? uuid,
    required String memberPhone,
    required String memberName,
    required Address address,
  }) async {
    final labelToken = address.label.name.toUpperCase();

    final backend = BackendAddressRepository.instance;
    if (backend.isAvailable) {
      final id = await backend.upsert(
        id: uuid,
        label: labelToken,
        house: address.house,
        area: address.area,
        landmark: address.landmark,
        pincode: address.pincode,
        firstName: address.firstName,
        lastName: address.lastName,
        phone: address.phone,
        patientId: address.patientId,
      );
      if (id != null) {
        return id;
      }
      // Falls through to Neon — see PatientRepository.upsert's own doc on
      // why a second, independent attempt is worth it here.
    }

    if (!NeonHttp.isConfigured) {
      return null;
    }
    final house = address.house;
    final area = address.area;
    final landmark = address.landmark;
    final pincode = address.pincode;
    final firstName = address.firstName;
    final lastName = address.lastName;
    final phone = address.phone;
    final patientUuid = _bareUuid(address.patientId);
    // Neither the standalone address form nor the patient form captures
    // these — [Address] carries no city/state fields to draw them from — so
    // every write leaves the columns null. They exist on the table for a
    // future form to fill in without a migration.
    const String? cityValue = null;
    const String? stateValue = null;

    try {
      if (uuid != null) {
        final updated = await NeonHttp.instance.query(
          r'''
            UPDATE app.member_address SET
              label      = $1::app.address_label,
              house      = $2,
              area       = $3,
              landmark   = $4,
              pincode    = $5,
              city       = $6,
              state      = $7,
              first_name = $8,
              last_name  = $9,
              phone      = $10,
              patient_id = COALESCE(
                (SELECT id FROM app.patient WHERE uuid = $11::uuid),
                patient_id
              ),
              updated_at = now()
            WHERE uuid = $12::uuid AND deleted_at IS NULL
            RETURNING uuid
          ''',
          [
            labelToken,
            house,
            area,
            landmark,
            pincode,
            cityValue,
            stateValue,
            firstName,
            lastName,
            phone,
            patientUuid,
            uuid,
          ],
        );
        if (updated.isNotEmpty) {
          return updated.first['uuid']?.toString();
        }
        // Row is gone (database wiped, or a stale id) — fall through and
        // write a fresh one rather than silently losing the address.
      }

      final inserted = await NeonHttp.instance.query(
        r'''
          WITH owner AS (
            INSERT INTO app.users (phone, name)
            VALUES ($1, $2)
            ON CONFLICT (phone) DO UPDATE SET updated_at = now()
            RETURNING id
          )
          INSERT INTO app.member_address (
            member_id, label, house, area, landmark, pincode, city, state,
            first_name, last_name, phone, patient_id
          )
          SELECT owner.id, $3::app.address_label, $4, $5, $6, $7, $8, $9,
                 $10, $11, $12,
                 (SELECT id FROM app.patient WHERE uuid = $13::uuid)
          FROM owner
          RETURNING uuid
        ''',
        [
          memberPhone,
          memberName,
          labelToken,
          house,
          area,
          landmark,
          pincode,
          cityValue,
          stateValue,
          firstName,
          lastName,
          phone,
          patientUuid,
        ],
      );
      final id = inserted.isEmpty ? null : inserted.first['uuid']?.toString();
      NeonHttp.log('AddressRepository.upsert: saved $house, $area ($id)');
      return id;
    } catch (error) {
      NeonHttp.log('AddressRepository.upsert failed', error: error);
      return null;
    }
  }

  /// Every non-deleted address for the member with [memberPhone], oldest
  /// first.
  ///
  /// Returns `null` (not an empty list) when neither the backend nor Neon
  /// could answer, so the caller can tell "this account has no saved
  /// addresses" from "could not load them" and avoid wiping the in-memory
  /// list on a transient failure.
  Future<List<Address>?> listForMember(String memberPhone) async {
    final backend = BackendAddressRepository.instance;
    if (backend.isAvailable) {
      final addresses = await backend.listForMember();
      if (addresses != null) {
        return addresses;
      }
    }

    if (!NeonHttp.isConfigured) {
      return null;
    }
    try {
      final rows = await NeonHttp.instance.query(
        r'''
          SELECT a.uuid, a.label::text AS label, a.house, a.area, a.landmark,
                 a.pincode, a.first_name, a.last_name, a.phone,
                 p.uuid AS patient_uuid
          FROM app.member_address a
          JOIN app.users u ON u.id = a.member_id
          LEFT JOIN app.patient p ON p.id = a.patient_id
          WHERE u.phone = $1 AND a.deleted_at IS NULL
          ORDER BY a.created_at
        ''',
        [memberPhone],
      );
      return rows.map(_toAddress).toList();
    } catch (error) {
      NeonHttp.log('AddressRepository.listForMember failed', error: error);
      return null;
    }
  }

  /// Marks an address row soft-deleted (`deleted_at = now()`). A no-op when
  /// [uuid] is unknown to a given path — both the backend and Neon are
  /// tried, since a delete's id could have come from either store, and
  /// each simply no-ops on an id it does not recognize rather than
  /// erroring — see [PatientRepository.softDelete]'s own doc.
  Future<void> softDelete(String uuid) async {
    final backend = BackendAddressRepository.instance;
    if (backend.isAvailable) {
      await backend.softDelete(uuid);
    }

    if (!NeonHttp.isConfigured) {
      return;
    }
    try {
      await NeonHttp.instance.query(
        r'UPDATE app.member_address SET deleted_at = now() '
        r'WHERE uuid = $1::uuid AND deleted_at IS NULL',
        [uuid],
      );
    } catch (error) {
      NeonHttp.log('AddressRepository.softDelete failed', error: error);
    }
  }

  /// One `app.member_address` row → an [Address]. The id is derived from the
  /// row `uuid` so a reload lands on the same in-memory record, and
  /// `remoteId` is set so [AddressBook] knows this one is already backed by
  /// the database. [patientId] is carried in the same `'remote-<uuid>'` form
  /// [PatientRepository] hands out, so [AddressBook.forPatient] matches it.
  static Address _toAddress(Map<String, dynamic> row) {
    final uuid = row['uuid']?.toString() ?? '';
    final patientUuid = row['patient_uuid']?.toString();
    return Address(
      id: uuid.isEmpty ? '' : 'remote-$uuid',
      remoteId: uuid.isEmpty ? null : uuid,
      pincode: (row['pincode'] ?? '').toString(),
      house: (row['house'] ?? '').toString(),
      area: (row['area'] ?? '').toString(),
      landmark: (row['landmark'] ?? '').toString(),
      firstName: (row['first_name'] ?? '').toString(),
      lastName: (row['last_name'] ?? '').toString(),
      phone: (row['phone'] ?? '').toString(),
      label: _labelFrom(row['label']?.toString()),
      patientId: (patientUuid == null || patientUuid.isEmpty)
          ? null
          : 'remote-$patientUuid',
    );
  }

  static AddressLabel _labelFrom(String? token) => AddressLabel.values
      .firstWhere(
        (l) => l.name.toUpperCase() == token,
        orElse: () => AddressLabel.home,
      );

  /// Strips the `'remote-'` prefix [PatientRepository]/[_toAddress] hand out
  /// for a synced row's local id, leaving the bare `app.patient.uuid` a SQL
  /// parameter needs — or null for a patient never written to the backend
  /// (no id, or a device-local `'p3'`-style one).
  static String? _bareUuid(String? patientId) {
    if (patientId == null || !patientId.startsWith('remote-')) {
      return null;
    }
    final uuid = patientId.substring('remote-'.length);
    return uuid.isEmpty ? null : uuid;
  }
}
