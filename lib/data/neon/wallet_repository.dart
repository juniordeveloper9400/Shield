import '../../module/privilege/privilege_tier.dart';
import 'neon_http.dart';

/// The wallet's own row — `app.wallet.balance`. The one authoritative figure
/// for [WalletService.balance]: the column every debit and credit in
/// `wallet_entry` is written against in the same statement, never derived
/// client-side.
class RemoteWallet {
  final int balance;

  const RemoteWallet({required this.balance});
}

/// One line of the real ledger — `app.wallet_entry` — as
/// [BackendWalletRepository.fetchEntries] reads it back.
///
/// Covers every kind the table holds: `ACTIVATION`/`BONUS` (a plan approved),
/// `REFERRAL_EARNINGS` (a friend's plan paying out), `AGENT_EARNINGS` (agent
/// commission moved in), and `SPEND` (an order paid from the wallet). A
/// `SPEND` row for an order only exists once the database has actually
/// debited the balance for it — for a standard order, at checkout; for a
/// prescription order, only once the store has billed it and staff have
/// collected it with the member's OTP (`collectBillWithWallet`,
/// `shieldweb/src/api/billPayments.ts`) — so reading this ledger back is what
/// keeps the wallet's transaction history showing only money that has really
/// moved, the same way [MemberEarnings] is always read fresh off the real
/// order list rather than kept as a running local total.
class RemoteWalletEntry {
  final String kind;
  final String label;
  final int amount;
  final DateTime occurredOn;

  const RemoteWalletEntry({
    this.kind = '',
    required this.label,
    required this.amount,
    required this.occurredOn,
  });
}

/// A privilege card as it stands on the backend — what the app reads back to
/// learn whether a submitted plan has been approved yet.
class RemoteWalletCard {
  final String uuid;

  /// `PENDING` · `APPROVED` · `REJECTED` (the `app.approval_status` tokens).
  final String status;
  final PrivilegeCardKind tierKind;
  final int amount;
  final int bonus;
  final int rechargedExtra;
  final String? storeCode;
  final DateTime issuedOn;
  final DateTime expiresOn;
  final DateTime submittedAt;

  /// The Super Admin's reason, set only when [status] is `REJECTED`.
  final String reviewerNote;

  const RemoteWalletCard({
    required this.uuid,
    required this.status,
    required this.tierKind,
    required this.amount,
    required this.bonus,
    required this.rechargedExtra,
    required this.storeCode,
    required this.issuedOn,
    required this.expiresOn,
    required this.submittedAt,
    required this.reviewerNote,
  });

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  /// What lands on the balance once the card is approved: the load, its bonus
  /// and anything recharged onto it since.
  int get credited => amount + bonus + rechargedExtra;
}

/// The one write left here that still goes straight to Neon —
/// [recordSpend], debiting the wallet for an order paid at checkout.
/// Submitting a plan for approval, and every read of the wallet's balance,
/// ledger and cards, moved to `backend/api` (see [BackendWalletRepository]);
/// this one write has nothing to call there instead, because checkout
/// itself (`lib/data/neon/order_repository.dart`) is not migrated to the
/// backend yet — see `docs/security.md` and
/// `backend/docs/migration-plan.md`'s Phase 5. Remove this class (down to
/// just the data classes above, which [BackendWalletRepository] also
/// builds) once checkout migrates and debits the wallet itself, the way
/// registration already credits its own bonus.
///
/// Best-effort, the same contract as every other direct-Neon write that
/// used to live here: no `DATABASE_URL` (tests, a build without
/// `--dart-define-from-file=.env`) or an unreachable endpoint → the call
/// no-ops. A failed debit must never be mistaken for a successful one.
class WalletRepository {
  const WalletRepository._();

  static const WalletRepository instance = WalletRepository._();

  bool get isAvailable => NeonHttp.isConfigured;

  /// Debits [amount] off the member's wallet for an order paid by wallet at
  /// checkout (or from a "Pay now" bill), and posts the matching `SPEND`
  /// ledger line against [orderId].
  ///
  /// Two sequential statements, the same accepted risk as every other write
  /// in this file — Neon's `/sql` endpoint runs one statement per request
  /// with no client transaction. The `UPDATE` itself guards against an
  /// overdraw (`WHERE balance >= amount`); when it returns no row — a stale
  /// balance, or a second attempt racing the first — nothing is debited and
  /// the ledger line is never inserted, so the two stay in step.
  ///
  /// Returns false without writing anything when the member has no wallet
  /// row yet, or the debit could not be applied.
  Future<bool> recordSpend({
    required String memberPhone,
    required int amount,
    required String label,
    required int orderId,
  }) async {
    final result = await _run('recordSpend', () async {
      final walletId = _rowId(
        await NeonHttp.instance.query(
          '''
            SELECT w.id
            FROM app.wallet w
            JOIN app.users u ON u.id = w.member_id
            WHERE u.phone = \$1
            LIMIT 1
          ''',
          [memberPhone],
        ),
      );
      if (walletId == null) {
        return false;
      }

      final debited = await NeonHttp.instance.query(
        '''
          UPDATE app.wallet
          SET balance = balance - \$2, updated_at = now()
          WHERE id = \$1 AND balance >= \$2
          RETURNING id
        ''',
        [walletId, amount],
      );
      if (debited.isEmpty) {
        return false;
      }

      await NeonHttp.instance.query(
        '''
          INSERT INTO app.wallet_entry
            (wallet_id, kind, label, amount, occurred_on, order_id)
          VALUES (\$1, 'SPEND'::app.wallet_entry_kind, \$2, \$3, current_date, \$4)
        ''',
        [walletId, label, -amount, orderId],
      );
      return true;
    });
    return result ?? false;
  }

  static int? _rowId(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return null;
    final value = rows.first['id'] ?? rows.first.values.firstOrNull;
    if (value == null) return null;
    return value is int ? value : int.tryParse(value.toString());
  }

  Future<T?> _run<T>(String label, Future<T?> Function() action) async {
    if (!NeonHttp.isConfigured) {
      return null;
    }
    try {
      return await action();
    } catch (error) {
      NeonHttp.log('WalletRepository.$label failed', error: error);
      return null;
    }
  }
}
