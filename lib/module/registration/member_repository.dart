import 'package:postgres/postgres.dart';

import '../../data/neon/neon_database.dart';
import 'registration_service.dart';

/// Persists the member profile behind a completed registration to Neon
/// (`app.member`).
///
/// [RegistrationService] stays the in-memory source of truth the UI listens
/// to; this is the write-through to the database. It is a no-op when the app
/// was built without a `DATABASE_URL` (tests, or any build that left it out —
/// see [NeonDatabase.isConfigured]), so the registration flow keeps working
/// with or without a backend.
class MemberRepository {
  MemberRepository._();

  static final MemberRepository instance = MemberRepository._();

  /// Whether a write would actually reach a database.
  bool get isAvailable => NeonDatabase.isConfigured;

  /// Inserts the member, or updates the existing row with the same [phone].
  ///
  /// Identity is the 10-digit mobile number (`app.member.phone` is unique and
  /// carries no `+91`). The assigned branch is resolved from
  /// [Registration.storeId] — the app's stable store code — to the
  /// `app.shield_store` primary key. [rewardPoints] is the member's current
  /// balance so the row reflects the points the registration just credited.
  ///
  /// Throws if the write fails; callers decide whether that is fatal.
  Future<void> upsertRegistration(
    Registration registration, {
    required int rewardPoints,
  }) async {
    if (!isAvailable) {
      return;
    }

    final conn = await NeonDatabase.instance.connection();
    await conn.execute(
      Sql.named('''
        insert into app.member (
          phone, name, email, gender, dob,
          address, place, pincode, state,
          home_store_id, reward_points, registration_completed_at
        )
        values (
          @phone, @name, @email, @gender::app.gender, @dob::date,
          @address, @place, @pincode, @state,
          (select id from app.shield_store where code = @storeCode),
          @rewardPoints, now()
        )
        on conflict (phone) do update set
          name                      = excluded.name,
          email                     = excluded.email,
          gender                    = excluded.gender,
          dob                       = excluded.dob,
          address                   = excluded.address,
          place                     = excluded.place,
          pincode                   = excluded.pincode,
          state                     = excluded.state,
          home_store_id             = excluded.home_store_id,
          reward_points             = excluded.reward_points,
          registration_completed_at = coalesce(
            app.member.registration_completed_at,
            excluded.registration_completed_at
          )
      '''),
      parameters: {
        'phone': registration.phone,
        'name': registration.name,
        'email': registration.email.isEmpty ? null : registration.email,
        'gender': registration.gender.name.toUpperCase(),
        'dob': _isoDate(registration.dob),
        'address': registration.address,
        'place': registration.place,
        'pincode': registration.pincode,
        'state': registration.state,
        'storeCode': registration.storeId,
        'rewardPoints': rewardPoints,
      },
    );
  }

  /// `1994-09-04` — an unambiguous value for a `date` column.
  static String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
