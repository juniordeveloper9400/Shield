import 'neon_http.dart';

/// The four kinds of appointment a member can book — mirrors
/// `app.appointment_kind`.
enum AppointmentKind { clinic, tele, dental, dietitian }

/// Writes a member's appointment booking to the `app.appointment` table on
/// Neon, over the HTTP SQL endpoint.
///
/// Every method is best-effort: when the app was built without a database URL
/// (tests, a build that left `--dart-define-from-file=.env` off — see
/// [NeonHttp.isConfigured]) or the network is down, the call no-ops and returns
/// null rather than throwing. Booking is an offer, not a gate — the
/// confirmation the member sees must not depend on the database being up.
///
/// Goes over [NeonHttp] (HTTPS on 443) rather than the raw Postgres socket so
/// it behaves identically on Android, on Flutter web and in a `--release`
/// build.
///
/// `app.appointment.member_id` is `NOT NULL`, so [book] resolves the owning
/// `app.users` row from the signed-in mobile number first, inserting a minimal
/// user if sign-in has not already written one. `clinic_id` / `dietitian_id`
/// are resolved by name and left null when there is no match.
class AppointmentRepository {
  const AppointmentRepository._();

  static const AppointmentRepository instance = AppointmentRepository._();

  bool get isAvailable => NeonHttp.isConfigured;

  /// Records a `REQUESTED` appointment (the `status` column default).
  ///
  /// The app books against plain-word slots ("Today, 4:00 PM"), not real
  /// timestamps, so [scheduledFor] is usually null and the wording is carried
  /// in [remarks] instead.
  ///
  /// Returns the `app.appointment` row's `uuid`, or null when nothing was
  /// written.
  Future<String?> book({
    required String memberPhone,
    required String memberName,
    required AppointmentKind kind,
    String? clinicName,
    String? dietitianName,
    String? doctorName,
    num? fee,
    DateTime? scheduledFor,
    String remarks = '',
  }) {
    return _run('book', () async {
      final rows = await NeonHttp.instance.query(
        '''
          WITH owner AS (
            INSERT INTO app.users (phone, name)
            VALUES (\$1, \$2)
            ON CONFLICT (phone) DO UPDATE SET updated_at = now()
            RETURNING id
          )
          INSERT INTO app.appointment
            (member_id, kind, clinic_id, dietitian_id, doctor_name, fee,
             scheduled_for, remarks)
          SELECT owner.id,
                 \$3::app.appointment_kind,
                 (SELECT id FROM app.clinic    WHERE name = \$4),
                 (SELECT id FROM app.dietitian WHERE name = \$5),
                 \$6, \$7, \$8::timestamptz, \$9
          FROM owner
          RETURNING uuid
        ''',
        [
          memberPhone,
          memberName,
          kind.name.toUpperCase(),
          clinicName,
          dietitianName,
          doctorName,
          fee,
          scheduledFor?.toUtc().toIso8601String(),
          remarks,
        ],
      );
      return rows.isEmpty ? null : rows.first['uuid']?.toString();
    });
  }

  /// Runs [action], swallowing everything: a missing URL, a network error, a
  /// SQL error. Returns null on any of them.
  Future<T?> _run<T>(String label, Future<T?> Function() action) async {
    if (!NeonHttp.isConfigured) {
      return null;
    }
    try {
      return await action();
    } catch (error) {
      NeonHttp.log('AppointmentRepository.$label failed', error: error);
      return null;
    }
  }
}
