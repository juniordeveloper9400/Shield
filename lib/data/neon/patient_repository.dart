import '../../module/patients/patient_book.dart';
import '../backend/backend_patient_repository.dart';

/// Reads and writes the people on an account through `backend/api`
/// (`BackendPatientRepository`), never a direct Neon connection. This used
/// to also hold a direct-Neon fallback for when the backend call failed;
/// that path is gone now, along with the compiled-in database credential
/// it depended on (see `docs/security.md` and
/// `backend/docs/migration-plan.md`'s Phase 5).
///
/// Every method is best-effort: an unconfigured backend or no live
/// session makes writes no-op and reads return null. Adding a patient
/// must never fail because the backend is unreachable — [PatientBook]
/// stays the source of truth for the running app, and this table is the
/// durable copy that is read back on the next launch.
class PatientRepository {
  const PatientRepository._();

  static const PatientRepository instance = PatientRepository._();

  /// Whether a write or read would actually reach the backend.
  bool get isAvailable => BackendPatientRepository.instance.isAvailable;

  /// Inserts a new patient, or updates the existing row when [uuid] is
  /// given (the value a previous call returned, held on
  /// [Patient.remoteId] — the backend's own numeric id, opaque to every
  /// caller).
  ///
  /// Returns the row's id so the caller can pin it onto the in-memory
  /// record with [PatientBook.attachRemoteId]. Null when nothing was
  /// written.
  Future<String?> upsert({
    String? uuid,
    required String name,
    required String phone,
    required String address,
    required DateTime dob,
    required PatientGender gender,
    required PatientRelation relation,
    required String abhaId,
  }) {
    return BackendPatientRepository.instance.upsert(
      id: uuid,
      name: name,
      phone: phone,
      address: address,
      dob: dob,
      gender: gender,
      relation: relation,
      abhaId: abhaId,
    );
  }

  /// Marks a patient row soft-deleted.
  Future<void> softDelete(String uuid) =>
      BackendPatientRepository.instance.softDelete(uuid);

  /// Every non-deleted patient for the signed-in member, oldest first.
  ///
  /// Returns `null` (not an empty list) when the backend could not
  /// answer, so the caller can tell "this account has no saved patients"
  /// from "could not load them" and avoid wiping the in-memory list on a
  /// transient failure. [memberPhone] is accepted for parity with the old
  /// direct-Neon signature; the lookup itself is scoped to the signed-in
  /// session, not this value.
  Future<List<Patient>?> listForMember(String memberPhone) =>
      BackendPatientRepository.instance.listForMember();
}
