import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import '../../module/patients/patient_book.dart';
import 'neon_database.dart';

/// Writes the people on an account to the `app.patient` table on Neon.
///
/// Mirrors [MemberRepository]: every method is best-effort. When the app was
/// built without a `DATABASE_URL` (tests, a public release, Flutter web) or the
/// database is unreachable, the calls no-op and return null rather than
/// throwing. Adding a patient must never fail because the database is down —
/// [PatientBook] stays the source of truth for the running app, and this table
/// is the durable copy.
///
/// `app.patient.member_id` is `NOT NULL`, so [upsert] resolves the owning
/// `app.member` row from the signed-in mobile number first, inserting a minimal
/// member if sign-in has not already written one.
class PatientRepository {
  const PatientRepository._();

  static const PatientRepository instance = PatientRepository._();

  /// Inserts a new patient, or updates the existing row when [uuid] is given
  /// (the value a previous [upsert] returned, held on [Patient.remoteId]).
  ///
  /// Returns the row's `uuid` — the same value back for an update, a fresh one
  /// for an insert — so the caller can pin it onto the in-memory record with
  /// [PatientBook.attachRemoteId]. Null when nothing was written.
  ///
  /// [memberPhone] / [memberName] identify the owning account; a patient added
  /// before sign-in ever reached the database still lands against a member row.
  Future<String?> upsert({
    String? uuid,
    required String memberPhone,
    required String memberName,
    required String name,
    required String phone,
    required String address,
    required DateTime dob,
    required PatientGender gender,
    required PatientRelation relation,
    required String abhaId,
  }) {
    // The column values common to both statements. `Sql.named` rejects a
    // parameter map that carries a key the statement does not mention, so the
    // member and uuid keys are added only to the map of the query that uses
    // them.
    final fields = <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      // A plain ISO date string cast to `date`, so a local `DateTime` with a
      // midnight time-of-day cannot drift a day across the connection.
      'dob': dob.toIso8601String().split('T').first,
      'gender': _genderName(gender),
      'relation': _relationName(relation),
      // Digits only, matching how [PatientBook] stores it.
      'abha': abhaId.replaceAll(RegExp(r'\D'), ''),
    };

    return _run('upsert', (conn) async {
      if (uuid != null) {
        final updated = await conn.execute(
          Sql.named('''
            UPDATE app.patient SET
              name       = @name,
              phone      = @phone,
              address    = @address,
              dob        = @dob::date,
              gender     = @gender::app.gender,
              relation   = @relation::app.patient_relation,
              abha_id    = @abha,
              updated_at = now()
            WHERE uuid = @uuid::uuid AND deleted_at IS NULL
            RETURNING uuid
          '''),
          parameters: {...fields, 'uuid': uuid},
        );
        if (updated.isNotEmpty) {
          return updated.first.first?.toString();
        }
        // The row is gone (database wiped, or a stale id) — fall through and
        // write a fresh one rather than silently losing the patient.
      }

      final inserted = await conn.execute(
        Sql.named('''
          WITH owner AS (
            INSERT INTO app.member (phone, name)
            VALUES (@member_phone, @member_name)
            ON CONFLICT (phone) DO UPDATE SET updated_at = now()
            RETURNING id
          )
          INSERT INTO app.patient
            (member_id, name, phone, address, dob, gender, relation, abha_id)
          SELECT owner.id, @name, @phone, @address, @dob::date,
                 @gender::app.gender, @relation::app.patient_relation, @abha
          FROM owner
          RETURNING uuid
        '''),
        parameters: {
          ...fields,
          'member_phone': memberPhone,
          'member_name': memberName,
        },
      );
      return inserted.isEmpty ? null : inserted.first.first?.toString();
    });
  }

  /// Marks a patient row soft-deleted (`deleted_at = now()`), matching the
  /// schema's soft-delete convention for `patient`. A no-op when [uuid] is
  /// unknown.
  Future<void> softDelete(String uuid) async {
    await _run('softDelete', (conn) async {
      await conn.execute(
        Sql.named('UPDATE app.patient SET deleted_at = now() '
            'WHERE uuid = @uuid::uuid AND deleted_at IS NULL'),
        parameters: {'uuid': uuid},
      );
    });
  }

  /// The `app.gender` enum label for [gender] (`FEMALE` / `MALE` / `OTHER`).
  static String _genderName(PatientGender gender) => gender.name.toUpperCase();

  /// The `app.patient_relation` enum label for [relation]
  /// (`SELF` / `SPOUSE` / `CHILD` / `PARENT` / `OTHER`).
  static String _relationName(PatientRelation relation) =>
      relation.name.toUpperCase();

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
      debugPrint('PatientRepository.$label: $error');
      return null;
    }
  }
}
