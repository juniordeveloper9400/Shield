/// One line of the reward-points ledger: a signed amount, why it moved, and
/// when. `points` is negative for a redemption.
///
/// The read/write repository this used to live beside
/// (`RewardsRepository`, direct Neon) is gone — see
/// `BackendRewardsRepository` and `RewardsService`'s own doc for where
/// every one of its callers moved to.
class RewardTxn {
  final int points;

  /// An `app.reward_txn_reason` value —
  /// `REGISTRATION` / `ORDER` / `REFERRAL_LEVEL` / `REDEMPTION` / `ADJUSTMENT`.
  final String reason;
  final String note;
  final DateTime at;

  const RewardTxn({
    required this.points,
    required this.reason,
    required this.note,
    required this.at,
  });

  bool get isCredit => points >= 0;
}
