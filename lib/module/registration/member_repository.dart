import '../../data/backend/backend_registration_repository.dart';
import 'registration_service.dart';

/// Persists the user profile behind a completed registration, through
/// `backend/api` (`PATCH`/`GET /v1/member/me`,
/// `BackendRegistrationRepository`) — never a direct Neon connection. This
/// used to also hold a direct-Neon fallback for when the backend call
/// failed; that path is gone now, along with the compiled-in database
/// credential it depended on (see `docs/security.md` and
/// `backend/docs/migration-plan.md`'s Phase 5) — a registration save that
/// can't reach the backend now fails outright rather than quietly writing
/// straight to the database with no server-side validation at all.
///
/// [RegistrationService] stays the in-memory source of truth the UI listens to;
/// this is the write-through.
class MemberRepository {
  MemberRepository._();

  static final MemberRepository instance = MemberRepository._();

  /// Whether a write would actually reach the backend.
  bool get isAvailable => BackendRegistrationRepository.instance.isAvailable;

  /// Inserts the member, or updates the existing row with the same
  /// [Registration.phone].
  ///
  /// `reward_points` is not written here — the reward-points ledger
  /// (`app.reward_point_transaction`) owns that column and moves it on the
  /// registration bonus, server-side, as a side effect of this same call.
  ///
  /// Throws on failure; callers decide whether that is fatal (see
  /// [RegistrationService]'s own doc — it is not).
  Future<void> upsertRegistration(Registration registration) =>
      BackendRegistrationRepository.instance.upsertRegistration(registration);

  /// Reads back a previously completed registration for [phone].
  ///
  /// Null when there is no row, when one exists but the form was never
  /// finished, or when the read failed. Every caller already treats a null
  /// profile as "not registered yet", so this fails safe rather than
  /// throwing.
  Future<Registration?> fetchByPhone(String phone) async {
    try {
      return await BackendRegistrationRepository.instance.fetchByPhone(phone);
    } catch (_) {
      return null;
    }
  }
}
