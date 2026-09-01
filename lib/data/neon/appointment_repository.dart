import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import 'neon_database.dart';

/// The four kinds of appointment a member can book — mirrors
/// `app.appointment_kind`.
enum AppointmentKind { clinic, tele, dental, dietitian }

/// Writes a member's appointment booking to the `app.appointment` table on
/// Neon.
///
/// Mirrors [PatientRepository]: every method is best-effort. When the app was
/// built without a `DATABASE_URL` (tests, a public release, Flutter web) or the
/// database is unreachable, the call no-ops and returns null rather than
/// throwing. Booking is an offer, not a gate — the confirmation the member
/// sees must not depend on the database being up.
///
/// `app.appointment.member_id` is `NOT NULL`, so [book] resolves the owning
/// `app.users` row from the signed-in mobile number first, inserting a minimal
/// user if sign-in has not already written one. `clinic_id` / `dietitian_id`
/// are resolved by name and left null when there is no match.
class AppointmentRepository {
  const AppointmentRepository._();

  static const AppointmentRepository instance = AppointmentRepository._();

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
    return _run('book', (conn) async {
      final rows = await conn.execute(
        Sql.named('''
          WITH owner AS (
            INSERT INTO app.users (phone, name)
            VALUES (@phone, @name)
            ON CONFLICT (phone) DO UPDATE SET updated_at = now()
            RETURNING id
          )
          INSERT INTO app.appointment
            (member_id, kind, clinic_id, dietitian_id, doctor_name, fee,
             scheduled_for, remarks)
          SELECT owner.id,
                 @kind::app.appointment_kind,
                 (SELECT id FROM app.clinic    WHERE name = @clinic_name),
                 (SELECT id FROM app.dietitian WHERE name = @dietitian_name),
                 @doctor_name, @fee, @scheduled_for, @remarks
          FROM owner
          RETURNING uuid
        '''),
        parameters: {
          'phone': memberPhone,
          'name': memberName,
          'kind': kind.name.toUpperCase(),
          'clinic_name': clinicName,
          'dietitian_name': dietitianName,
          'doctor_name': doctorName,
          'fee': fee,
          'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
          'remarks': remarks,
        },
      );
      return rows.isEmpty ? null : rows.first.first?.toString();
    });
  }

  /// Runs [action] against the shared connection, swallowing everything: a
  /// missing `DATABASE_URL`, a socket error, a SQL error. Returns null on any
  /// of them.
  Future<T?> _run<T>(
    String label,
    Future<T?> Function(Connection conn) action,
  ) async {
    if (!NeonDatabase.isConfigured) {
      return null;
    }
    try {
      final conn = await NeonDatabase.instance.connection();
      return await action(conn);
    } catch (error) {
      debugPrint('AppointmentRepository.$label: $error');
      return null;
    }
  }
}
