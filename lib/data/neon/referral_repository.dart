import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../module/refer/referral_level.dart';
import 'neon_http.dart';

/// Reads and writes the refer-and-earn graph on Neon: `app.users.referral_code`,
/// and the `app.referral` row that tracks one invitee from sign-up to plan
/// activation.
///
/// Best-effort, the same contract as the other Neon repositories: with no
/// `DATABASE_URL` compiled in or the network down, reads return `null` and
/// writes no-op — the refer & earn screen must never break because the
/// database is unreachable, it just has nothing real to report yet.
class ReferralRepository {
  const ReferralRepository._();

  static const ReferralRepository instance = ReferralRepository._();

  bool get isAvailable => NeonHttp.isConfigured;

  /// The member's own invite code, generating and saving one the first time
  /// it is asked for. Null when the database is unreachable, or [phone] has
  /// no `app.users` row yet (sign-in writes one before this is ever called,
  /// so that should not happen in practice).
  ///
  /// `SAHAKAR-` plus four digits, retried against the column's `UNIQUE`
  /// constraint — a collision only ever costs another random draw, not a
  /// failed registration.
  Future<String?> ensureCodeFor(String phone) {
    return _run('ensureCodeFor', () async {
      final existing = await NeonHttp.instance.query(
        'SELECT referral_code FROM app.users WHERE phone = \$1',
        [phone],
      );
      final current = existing.isEmpty
          ? null
          : existing.first['referral_code']?.toString();
      if (current != null && current.isNotEmpty) {
        return current;
      }

      final random = Random();
      for (var attempt = 0; attempt < 8; attempt++) {
        final candidate = 'SAHAKAR-${1000 + random.nextInt(9000)}';
        try {
          final saved = await NeonHttp.instance.query(
            '''
              UPDATE app.users SET referral_code = \$1, updated_at = now()
              WHERE phone = \$2 AND referral_code IS NULL
              RETURNING referral_code
            ''',
            [candidate, phone],
          );
          if (saved.isNotEmpty) {
            return saved.first['referral_code']?.toString();
          }
          // No row moved: either this phone already has a code — another
          // call won the race — or there is no `app.users` row for it yet.
          // Reading it back settles which, without guessing.
          final recheck = await NeonHttp.instance.query(
            'SELECT referral_code FROM app.users WHERE phone = \$1',
            [phone],
          );
          if (recheck.isEmpty) {
            return null;
          }
          final settled = recheck.first['referral_code']?.toString();
          if (settled != null && settled.isNotEmpty) {
            return settled;
          }
          return null;
        } catch (error) {
          // Almost certainly the UNIQUE constraint — another member already
          // holds this candidate. Draw again rather than give up on one clash.
          NeonHttp.log(
            'ensureCodeFor: candidate $candidate taken, retrying',
            error: error,
          );
        }
      }
      return null;
    });
  }

  /// Records that [newMemberPhone] signed up using [code] — the one edge from
  /// inviter to invitee the whole ladder is climbed on.
  ///
  /// Returns `false` (and writes nothing) when the code does not resolve to a
  /// member, resolves to the phone signing up itself, or this phone already
  /// carries a referral row — a member is referred once, and the earliest
  /// attribution is the one that stands.
  Future<bool> recordSignup({
    required String code,
    required String newMemberPhone,
  }) async {
    final result = await _run<bool>('recordSignup', () async {
      // A code shared before the rename reads `SHIELD-1234`; every stored one
      // is now `SAHAKAR-1234` (migration 0051), so map the old prefix over.
      final trimmedCode = code.trim().replaceFirst(
        RegExp(r'^SHIELD-', caseSensitive: false),
        'SAHAKAR-',
      );
      if (trimmedCode.isEmpty) {
        return false;
      }

      final inviterRows = await NeonHttp.instance.query(
        'SELECT id, phone FROM app.users WHERE referral_code = \$1',
        [trimmedCode],
      );
      if (inviterRows.isEmpty) {
        return false;
      }
      final inviterId = inviterRows.first['id'];
      final inviterPhone = inviterRows.first['phone']?.toString();
      if (inviterPhone == newMemberPhone) {
        return false; // a code cannot refer its own owner
      }

      final inserted = await NeonHttp.instance.query(
        '''
          WITH invitee AS (
            SELECT id FROM app.users WHERE phone = \$1
          )
          INSERT INTO app.referral (
            inviter_member_id, invitee_member_id, invitee_phone,
            code_used, status, registered_at
          )
          SELECT \$2, invitee.id, \$1, \$3, 'REGISTERED', now()
          FROM invitee
          WHERE NOT EXISTS (
            SELECT 1 FROM app.referral existing
            WHERE existing.invitee_member_id = invitee.id
          )
          RETURNING id
        ''',
        [newMemberPhone, inviterId, trimmedCode],
      );
      if (inserted.isEmpty) {
        return false;
      }

      await NeonHttp.instance.query(
        '''
          UPDATE app.users SET referred_by_member_id = \$1, updated_at = now()
          WHERE phone = \$2 AND referred_by_member_id IS NULL
        ''',
        [inviterId, newMemberPhone],
      );
      NeonHttp.log('recordSignup: $newMemberPhone referred by $inviterPhone');
      return true;
    });
    return result ?? false;
  }

  /// The code [phone] themselves signed up with, if any — `app.referral
  /// .code_used` on the row where they are the invitee. Lets the
  /// registration form show a member's own referral code back to them on
  /// every later visit, rather than only while they are still typing it in.
  /// Null when nobody referred this member, or the database is unreachable.
  Future<String?> codeUsedBy(String phone) {
    return _run('codeUsedBy', () async {
      final rows = await NeonHttp.instance.query(
        'SELECT code_used FROM app.referral WHERE invitee_phone = \$1',
        [phone],
      );
      if (rows.isEmpty) {
        return null;
      }
      final code = rows.first['code_used']?.toString();
      return (code == null || code.isEmpty) ? null : code;
    });
  }

  /// Advances [phone]'s inbound referral (they are the one who was invited)
  /// from `REGISTERED` to `TRANSACTED` — the first paid order they complete.
  ///
  /// A no-op when nobody referred this member, or their referral has already
  /// moved past `REGISTERED`: the status only ever moves forward.
  ///
  /// When it does advance one, the inviter's ladder is re-checked straight
  /// away (`app.award_referral_level_points`, migration 0043): a referral
  /// reaching `TRANSACTED` is exactly what can carry them across a rung, and
  /// the reward points that rung pays are credited here, at that moment — the
  /// same thing `OrderService.checkout` does on the backend. It pays each
  /// rung once (guarded by `users.referral_level_awarded`) and pays every rung
  /// crossed since the last check, so a failed attempt is made good the next
  /// time a referral transacts or a plan activates.
  Future<void> markTransacted(String phone) async {
    await _run('markTransacted', () async {
      final advanced = await NeonHttp.instance.query(
        '''
          UPDATE app.referral r
          SET status = 'TRANSACTED', transacted_at = now()
          FROM app.users u
          WHERE u.id = r.invitee_member_id AND u.phone = \$1
            AND r.status = 'REGISTERED'
          RETURNING r.inviter_member_id
        ''',
        [phone],
      );
      for (final row in advanced) {
        await NeonHttp.instance.query(
          'SELECT app.award_referral_level_points(\$1::bigint)',
          [row['inviter_member_id']],
        );
      }
    });
  }

  /// The signed-in member's real standing: who has joined on their code, how
  /// many of those have transacted, how many went on to activate a privilege
  /// plan, and what that has paid — 2% of each approved load (see
  /// [ReferralLadder.planCommissionOn]), worked out the same way the
  /// commission card on the screen works it out, so the two can never
  /// disagree.
  ///
  /// Null on a failed read; the caller keeps whatever it already had rather
  /// than treating a blip as "nothing referred yet".
  Future<ReferralProgress?> progressFor(String phone) {
    return _run('progressFor', () async {
      // Everyone who has actually joined (an invite that was only shared has
      // no status past SHARED), newest first, with how far each has got. Names
      // are cut down to first name + last initial before they leave here.
      final invitedRows = await NeonHttp.instance.query(
        '''
          SELECT r.status, u.name, r.registered_at, r.transacted_at,
                 r.plan_activated_at, r.created_at
          FROM app.referral r
          JOIN app.users inviter ON inviter.id = r.inviter_member_id
          LEFT JOIN app.users u  ON u.id = r.invitee_member_id
          WHERE inviter.phone = \$1
            AND r.status IN ('REGISTERED', 'TRANSACTED', 'PLAN_ACTIVATED')
          ORDER BY r.created_at DESC, r.id DESC
        ''',
        [phone],
      );
      final invitees = inviteesFrom(invitedRows);
      final directReferrals = invitees
          .where((p) => p.stage != ReferredStage.joined)
          .length;

      // One row per approved privilege card issued to somebody this member
      // referred — a member can activate more than one card, and each pays
      // its own share.
      final activatedRows = await NeonHttp.instance.query(
        '''
          SELECT wc.amount
          FROM app.referral r
          JOIN app.users inviter  ON inviter.id = r.inviter_member_id
          JOIN app.wallet w       ON w.member_id = r.invitee_member_id
          JOIN app.wallet_card wc ON wc.wallet_id = w.id AND wc.status = 'APPROVED'
          WHERE inviter.phone = \$1
        ''',
        [phone],
      );
      var sahakarMoney = 0;
      for (final row in activatedRows) {
        sahakarMoney += ReferralLadder.planCommissionOn(_int(row['amount']));
      }

      return ReferralProgress(
        directReferrals: directReferrals,
        pendingReferrals: invitees.length - directReferrals,
        invitees: invitees,
        plansActivated: activatedRows.length,
        sahakarMoney: sahakarMoney,
      );
    });
  }

  /// Turns the `app.referral` rows for one inviter into the people list,
  /// keeping their order. A row whose status is not a person who has joined
  /// (`SHARED`, or anything unknown) is left out.
  @visibleForTesting
  static List<ReferredMember> inviteesFrom(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final people = <ReferredMember>[];
    for (final row in rows) {
      final stage = ReferredStage.fromStatus(row['status']?.toString());
      if (stage == null) continue;
      final registeredAt =
          _date(row['registered_at']) ?? _date(row['created_at']);
      people.add(
        ReferredMember(
          name: ReferredMember.shortName(row['name']?.toString()),
          stage: stage,
          joinedAt: registeredAt,
          transactedAt: _date(row['transacted_at']),
          planActivatedAt: _date(row['plan_activated_at']),
        ),
      );
    }
    return people;
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static int _int(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return num.tryParse(value.toString())?.toInt() ?? 0;
  }

  Future<T?> _run<T>(String label, Future<T?> Function() action) async {
    if (!NeonHttp.isConfigured) {
      return null;
    }
    try {
      return await action();
    } catch (error) {
      NeonHttp.log('ReferralRepository.$label failed', error: error);
      return null;
    }
  }
}
