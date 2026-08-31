import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import '../../module/privilege/privilege_tier.dart';
import 'neon_database.dart';

/// Writes a privilege-card activation to the `app.wallet`, `app.wallet_card`
/// and `app.wallet_entry` tables on Neon.
///
/// Mirrors [MemberRepository] / [PatientRepository]: every method is
/// best-effort. When the app was built without a `DATABASE_URL` (tests, a
/// public release, Flutter web) or the database is unreachable, the call
/// no-ops and returns null rather than throwing. Activating a plan must never
/// fail because the database is down — [WalletService] stays the source of
/// truth for the running session, and these rows are the durable copy.
///
/// `app.wallet.member_id` is `NOT NULL`, so [activateCard] resolves the owning
/// `app.member` row from the signed-in mobile number first, inserting a minimal
/// member if sign-in has not already written one.
class WalletRepository {
  const WalletRepository._();

  static const WalletRepository instance = WalletRepository._();

  /// Records an activation: opens the member's wallet if it is not open yet,
  /// issues (or recharges) the `app.wallet_card` for [tierKind] + [amount],
  /// writes the `ACTIVATION` and `BONUS` ledger lines, and moves the wallet
  /// balance — the same effect [WalletService.activate] has in memory.
  ///
  /// Re-activating a load the wallet already holds recharges that card
  /// (`recharged_extra += credited`) instead of issuing a second one, matching
  /// the in-memory behaviour.
  ///
  /// Returns the `app.wallet_card` row's `uuid`, or null when nothing was
  /// written.
  Future<String?> activateCard({
    required String memberPhone,
    required String memberName,
    required PrivilegeCardKind tierKind,
    required int amount,
    required int bonus,
    required int credited,
    required String cardNumber,
    String? storeCode,
    DateTime? issuedOn,
  }) {
    return _run('activateCard', (conn) async {
      final issued = (issuedOn ?? DateTime.now()).toIso8601String().split('T').first;
      final kind = tierKind.name.toUpperCase();

      return conn.runTx((tx) async {
        // 1 · The owning member — insert a minimal row if sign-in has not
        // already written one, matching the CTE idiom in PatientRepository.
        final ownerRows = await tx.execute(
          Sql.named('''
            INSERT INTO app.member (phone, name)
            VALUES (@phone, @name)
            ON CONFLICT (phone) DO UPDATE SET updated_at = now()
            RETURNING id
          '''),
          parameters: {'phone': memberPhone, 'name': memberName},
        );
        final memberId = ownerRows.first.first as int;

        // 2 · The wallet — one per member (member_id is UNIQUE). Opening it is
        // idempotent; opened_at is stamped once and kept.
        final walletRows = await tx.execute(
          Sql.named('''
            INSERT INTO app.wallet (member_id, opened_at)
            VALUES (@member_id, now())
            ON CONFLICT (member_id) DO UPDATE SET
              opened_at  = COALESCE(app.wallet.opened_at, now()),
              updated_at = now()
            RETURNING id
          '''),
          parameters: {'member_id': memberId},
        );
        final walletId = walletRows.first.first as int;

        // 3 · The tier, and how long a card issued on it stays live.
        final tierRows = await tx.execute(
          Sql.named('''
            SELECT id, validity_months FROM app.membership_tier
            WHERE kind = @kind::app.privilege_card_kind
          '''),
          parameters: {'kind': kind},
        );
        if (tierRows.isEmpty) {
          // Reference data missing — nothing to hang the card off.
          return null;
        }
        final tierId = tierRows.first[0] as int;
        final validityMonths = tierRows.first[1] as int;

        // 4 · The activation branch, resolved from ShieldStore.id == code.
        int? storeId;
        if (storeCode != null && storeCode.isNotEmpty) {
          final storeRows = await tx.execute(
            Sql.named('SELECT id FROM app.shield_store WHERE code = @code'),
            parameters: {'code': storeCode},
          );
          if (storeRows.isNotEmpty) {
            storeId = storeRows.first.first as int;
          }
        }

        // 5 · The card — recharge the matching load if the wallet already
        // holds it, otherwise issue a new one.
        final existing = await tx.execute(
          Sql.named('''
            SELECT id FROM app.wallet_card
            WHERE wallet_id = @wallet_id AND tier_id = @tier_id AND amount = @amount
            LIMIT 1
          '''),
          parameters: {
            'wallet_id': walletId,
            'tier_id': tierId,
            'amount': amount,
          },
        );

        final String cardUuid;
        final int cardId;
        if (existing.isNotEmpty) {
          cardId = existing.first.first as int;
          final updated = await tx.execute(
            Sql.named('''
              UPDATE app.wallet_card SET
                recharged_extra = recharged_extra + @credited,
                recharged_on    = @issued::date
              WHERE id = @id
              RETURNING uuid
            '''),
            parameters: {'id': cardId, 'credited': credited, 'issued': issued},
          );
          cardUuid = updated.first.first.toString();
        } else {
          final inserted = await tx.execute(
            Sql.named('''
              INSERT INTO app.wallet_card
                (wallet_id, tier_id, amount, bonus, card_number, store_id,
                 issued_on, recharged_on, expires_on)
              VALUES
                (@wallet_id, @tier_id, @amount, @bonus, @card_number, @store_id,
                 @issued::date, @issued::date,
                 @issued::date + make_interval(months => @months))
              RETURNING id, uuid
            '''),
            parameters: {
              'wallet_id': walletId,
              'tier_id': tierId,
              'amount': amount,
              'bonus': bonus,
              'card_number': cardNumber,
              'store_id': storeId,
              'issued': issued,
              'months': validityMonths,
            },
          );
          cardId = inserted.first[0] as int;
          cardUuid = inserted.first[1].toString();
        }

        // 6 · The ledger — the activation credit and its bonus as two lines,
        // the same labels WalletService writes in memory.
        final tierName = _tierName(tierKind);
        await tx.execute(
          Sql.named('''
            INSERT INTO app.wallet_entry
              (wallet_id, kind, label, amount, occurred_on, wallet_card_id)
            VALUES
              (@wallet_id, 'ACTIVATION', @activation_label, @amount, @issued::date, @card_id),
              (@wallet_id, 'BONUS',      @bonus_label,      @bonus,  @issued::date, @card_id)
          '''),
          parameters: {
            'wallet_id': walletId,
            'card_id': cardId,
            'activation_label': '$tierName activation',
            'bonus_label': '$tierName bonus · 10%',
            'amount': amount,
            'bonus': bonus,
            'issued': issued,
          },
        );

        // 7 · Move the balance by what actually landed.
        await tx.execute(
          Sql.named('''
            UPDATE app.wallet SET balance = balance + @credited, updated_at = now()
            WHERE id = @wallet_id
          '''),
          parameters: {'wallet_id': walletId, 'credited': credited},
        );

        return cardUuid;
      });
    });
  }

  /// The tier's display name, matching `app.membership_tier.name` and the
  /// labels [WalletService] uses (`PrivilegeProgramme.<tier>.name`).
  static String _tierName(PrivilegeCardKind kind) => switch (kind) {
        PrivilegeCardKind.silver => PrivilegeProgramme.silver.name,
        PrivilegeCardKind.gold => PrivilegeProgramme.gold.name,
        PrivilegeCardKind.platinum => PrivilegeProgramme.platinum.name,
      };

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
      debugPrint('WalletRepository.$label: $error');
      return null;
    }
  }
}
