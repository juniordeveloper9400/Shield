import '../../module/location/address_book.dart';
import '../backend/backend_address_repository.dart';

/// Reads and writes saved delivery addresses through `backend/api`
/// (`BackendAddressRepository`), never a direct Neon connection. This used
/// to also hold a direct-Neon fallback for when the backend call failed;
/// that path is gone now, along with the compiled-in database credential
/// it depended on (see `docs/security.md` and
/// `backend/docs/migration-plan.md`'s Phase 5).
///
/// Every method is best-effort: an unconfigured backend or no live
/// session makes writes no-op and reads return null. Saving an address
/// must never fail because the backend is unreachable — [AddressBook]
/// stays the source of truth for the running app, and this table is the
/// durable copy that is read back on the next launch.
class AddressRepository {
  const AddressRepository._();

  static const AddressRepository instance = AddressRepository._();

  /// Whether a write or read would actually reach the backend.
  bool get isAvailable => BackendAddressRepository.instance.isAvailable;

  /// Inserts a new address, or updates the existing row when [uuid] is
  /// given (the value a previous call returned, held on
  /// [Address.remoteId] — the backend's own numeric id, opaque to every
  /// caller).
  ///
  /// [address] carries the fields to write, [Address.patientId] included —
  /// the `'remote-<id>'` form [BackendPatientRepository] hands out,
  /// unwrapped back to a bare id by [BackendAddressRepository]; null for an
  /// address saved on its own or one that only ever named a patient added
  /// on this device. Returns the row's id so the caller can pin it onto
  /// the in-memory record with [AddressBook.attachRemoteId]. Null when
  /// nothing was written.
  Future<String?> upsert({String? uuid, required Address address}) {
    final labelToken = address.label.name.toUpperCase();
    return BackendAddressRepository.instance.upsert(
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
  }

  /// Every non-deleted address for the signed-in member, oldest first.
  ///
  /// Returns `null` (not an empty list) when the backend could not
  /// answer, so the caller can tell "this account has no saved addresses"
  /// from "could not load them" and avoid wiping the in-memory list on a
  /// transient failure. [memberPhone] is accepted for parity with the old
  /// direct-Neon signature; the lookup itself is scoped to the signed-in
  /// session, not this value.
  Future<List<Address>?> listForMember(String memberPhone) =>
      BackendAddressRepository.instance.listForMember();

  /// Marks an address row soft-deleted.
  Future<void> softDelete(String uuid) =>
      BackendAddressRepository.instance.softDelete(uuid);
}
