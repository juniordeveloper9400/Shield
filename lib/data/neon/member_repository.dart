import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import 'neon_database.dart';

/// Writes the signed-in member to the `app.member` table on Neon and reads
/// back the little the app needs from it.
///
/// Every method is best-effort: when the app was built without a
/// `DATABASE_URL` (tests, a public release, Flutter web) or the database is
/// unreachable, the calls no-op and return null rather than throwing. Sign-in
/// must never fail because the database is down — the Firebase session is the
/// source of truth for *whether* a member is in; this table is the record of
/// *who*.
class MemberRepository {
  const MemberRepository._();

  static const MemberRepository instance = MemberRepository._();

  /// Inserts the member on first sign-in, or refreshes their name,
  /// `firebase_uid` and `last_login_at` on a return sign-in. Keyed on the
  /// mobile number, which is unique in `app.member`.
  Future<void> upsertOnSignIn({
    required String name,
    required String phone,
    String? firebaseUid,
  }) async {
    await _run('upsertOnSignIn', (conn) async {
      await conn.execute(
        Sql.named('''
          INSERT INTO app.member (phone, name, firebase_uid, last_login_at)
          VALUES (@phone, @name, @uid, now())
          ON CONFLICT (phone) DO UPDATE SET
            name         = EXCLUDED.name,
            firebase_uid = COALESCE(EXCLUDED.firebase_uid, app.member.firebase_uid),
            last_login_at = now(),
            updated_at   = now()
        '''),
        parameters: {
          'phone': phone,
          'name': name,
          'uid': firebaseUid,
        },
      );
    });
  }

  /// The stored name for [phone], used at launch when the Firebase profile
  /// carries no display name. Null when there is no row or the lookup failed.
  Future<String?> nameByPhone(String phone) async {
    return _run('nameByPhone', (conn) async {
      final rows = await conn.execute(
        Sql.named('SELECT name FROM app.member WHERE phone = @phone LIMIT 1'),
        parameters: {'phone': phone},
      );
      if (rows.isEmpty) {
        return null;
      }
      final value = rows.first.first;
      return value is String && value.trim().isNotEmpty ? value : null;
    });
  }

  /// Bumps `last_login_at` for a session restored at launch, so the column
  /// tracks real app opens and not just fresh OTP sign-ins.
  Future<void> touchLogin(String phone) async {
    await _run('touchLogin', (conn) async {
      await conn.execute(
        Sql.named('UPDATE app.member SET last_login_at = now() '
            'WHERE phone = @phone'),
        parameters: {'phone': phone},
      );
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
      debugPrint('MemberRepository.$label: $error');
      return null;
    }
  }
}
