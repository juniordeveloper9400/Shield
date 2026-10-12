import '../../module/privilege/privilege_tier.dart';

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

