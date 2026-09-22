import '../../data/backend/backend_registration_repository.dart';
import '../../data/neon/neon_http.dart';
import 'registration_service.dart';

/// Persists the user profile behind a completed registration.
///
/// Tries `backend/api` first (`BackendRegistrationRepository`, `PATCH`/`GET
/// /v1/member/me`) and falls back to the direct-Neon path below only when
/// there is no backend session yet or the backend call itself fails — both
/// write the identical `app.users` row, this is a resilience fallback
/// during the migration off the compiled-in Neon credential, not two
/// separate copies of the data. See the migration plan's own doc for why
/// the Neon path stays in place rather than being deleted outright.
///
/// [RegistrationService] stays the in-memory source of truth the UI listens to;
/// this is the write-through. The Neon leg is a no-op when the app was built
/// without a `DATABASE_URL` (tests, or a build that left
/// `--dart-define-from-file=.env` off — see [NeonHttp.isConfigured]), so the
/// registration flow keeps working with or without either backend.
class MemberRepository {
  MemberRepository._();

  static final MemberRepository instance = MemberRepository._();

  /// Whether a write would actually reach a database — the backend or Neon.
  bool get isAvailable =>
      BackendRegistrationRepository.instance.isAvailable || NeonHttp.isConfigured;

  /// Inserts the member, or updates the existing row with the same [phone].
  ///
  /// Identity is the 10-digit mobile number (`app.users.phone` is unique and
  /// carries no `+91`). The assigned branch is resolved from
  /// [Registration.storeId] — the app's stable store code — to the
  /// `app.shield_store` primary key.
  ///
  /// `reward_points` is not written here — the reward-points ledger
  /// (`app.reward_point_transaction`, via `RewardsRepository`) owns that column
  /// and moves it on the registration bonus.
  ///
  /// Throws if neither the backend nor Neon could save it; callers decide
  /// whether that is fatal (see [RegistrationService]'s own doc — it is not).
  Future<void> upsertRegistration(Registration registration) async {
    final backend = BackendRegistrationRepository.instance;
    if (backend.isAvailable) {
      try {
        await backend.upsertRegistration(registration);
        NeonHttp.log('upsertRegistration: saved via backend ${registration.phone}');
        return;
      } catch (error) {
        NeonHttp.log(
          'upsertRegistration: backend failed, falling back to Neon',
          error: error,
        );
        // Falls through to the direct-Neon write below.
      }
    }

    if (!NeonHttp.isConfigured) {
      return;
    }

    await NeonHttp.instance.query(
      '''
        INSERT INTO app.users (
          phone, name, email, gender, dob,
          address, place, pincode, state,
          home_store_id, registration_completed_at
        )
        VALUES (
          \$1, \$2, \$3, \$4::app.gender, \$5::date,
          \$6, \$7, \$8, \$9,
          (SELECT id FROM app.shield_store WHERE code = \$10),
          now()
        )
        ON CONFLICT (phone) DO UPDATE SET
          name                      = EXCLUDED.name,
          email                     = EXCLUDED.email,
          gender                    = EXCLUDED.gender,
          dob                       = EXCLUDED.dob,
          address                   = EXCLUDED.address,
          place                     = EXCLUDED.place,
          pincode                   = EXCLUDED.pincode,
          state                     = EXCLUDED.state,
          home_store_id             = EXCLUDED.home_store_id,
          registration_completed_at = COALESCE(
            app.users.registration_completed_at,
            EXCLUDED.registration_completed_at
          )
      ''',
      [
        registration.phone,
        registration.name,
        registration.email.isEmpty ? null : registration.email,
        registration.gender.name.toUpperCase(),
        _isoDate(registration.dob),
        registration.address,
        registration.place,
        registration.pincode,
        registration.state,
        registration.storeId,
      ],
    );
    NeonHttp.log('upsertRegistration: saved ${registration.phone}');
  }

  /// `1994-09-04` — an unambiguous value for a `date` column.
  static String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Reads back a previously completed registration for [phone] — the row
  /// [upsertRegistration] wrote, joined back to the store's stable code.
  ///
  /// Null when there is no row, when one exists but the form was never
  /// finished (`registration_completed_at` is only set on submit, so a bare
  /// sign-in row does not count), or when the read failed. Every caller
  /// already treats a null profile as "not registered yet", so this fails
  /// safe rather than throwing.
  Future<Registration?> fetchByPhone(String phone) async {
    final backend = BackendRegistrationRepository.instance;
    if (backend.isAvailable) {
      try {
        // A clean answer — registered or not — is trusted as-is; only a
        // thrown failure (network, session not ready yet) falls through to
        // the Neon read below.
        return await backend.fetchByPhone(phone);
      } catch (error) {
        NeonHttp.log('fetchByPhone: backend failed, falling back to Neon', error: error);
      }
    }

    if (!NeonHttp.isConfigured) {
      return null;
    }
    try {
      final rows = await NeonHttp.instance.query(
        '''
          SELECT u.name, u.email, u.gender, u.dob,
                 u.address, u.place, u.pincode, u.state,
                 s.code AS store_code
          FROM app.users u
          LEFT JOIN app.shield_store s ON s.id = u.home_store_id
          WHERE u.phone = \$1 AND u.registration_completed_at IS NOT NULL
          LIMIT 1
        ''',
        [phone],
      );
      if (rows.isEmpty) {
        return null;
      }

      final row = rows.first;
      final storeCode = row['store_code'] as String?;
      final dob = row['dob'] as String?;
      // Both are required by the form; either missing means the row is not
      // a usable registration, not something worth surfacing as one.
      if (storeCode == null || dob == null) {
        return null;
      }
      final genderName = (row['gender'] as String?)?.toUpperCase();

      return Registration(
        name: (row['name'] as String?) ?? '',
        phone: phone,
        email: (row['email'] as String?) ?? '',
        gender: Gender.values.firstWhere(
          (gender) => gender.name.toUpperCase() == genderName,
          orElse: () => Gender.other,
        ),
        dob: DateTime.parse(dob),
        address: (row['address'] as String?) ?? '',
        place: (row['place'] as String?) ?? '',
        pincode: (row['pincode'] as String?) ?? '',
        state: (row['state'] as String?) ?? '',
        storeId: storeCode,
      );
    } catch (error) {
      NeonHttp.log('fetchByPhone failed', error: error);
      return null;
    }
  }
}
