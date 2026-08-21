import 'package:flutter/foundation.dart';

/// One line in the wallet ledger.
@immutable
class WalletEntry {
  final String label;
  final String date;

  /// Positive credits, negative debits, in whole rupees.
  final int amount;

  const WalletEntry({
    required this.label,
    required this.date,
    required this.amount,
  });

  bool get isCredit => amount >= 0;
}

/// The SHIELD wallet: a balance and the ledger behind it.
///
/// Real state rather than a hardcoded figure, because the privilege programme
/// credits a bonus into it — a number that is never shown anywhere would not
/// be a programme at all.
///
/// In memory only; a backend would replace this class wholesale.
class WalletService extends ChangeNotifier {
  WalletService._();

  static final WalletService instance = WalletService._();

  /// Opening balance, matching the ledger seeded below.
  static const int openingBalance = 3472;

  /// Opening reward / redeem points.
  static const int openingRewardPoints = 480;

  static const List<WalletEntry> _seed = [
    WalletEntry(label: 'Order SHD-100482', date: '16 Aug 2026', amount: -1248),
    WalletEntry(label: 'Wallet top-up', date: '15 Aug 2026', amount: 2000),
    WalletEntry(label: 'Referral reward', date: '11 Aug 2026', amount: 150),
    WalletEntry(label: 'Order SHD-100461', date: '12 Aug 2026', amount: -640),
    WalletEntry(label: 'Cashback · SHIELD28', date: '04 Aug 2026', amount: 210),
  ];

  int _balance = openingBalance;
  int _rewardPoints = openingRewardPoints;
  final List<WalletEntry> _entries = List.of(_seed);

  int get balance => _balance;
  int get rewardPoints => _rewardPoints;

  /// Newest first, which is the order the screen reads them in.
  List<WalletEntry> get entries => List.unmodifiable(_entries);

  /// Credits [amount], and [bonus] as its own line.
  ///
  /// Two entries rather than one combined credit: the bonus is the whole point
  /// of the privilege programme, and rolling it into the top-up would hide the
  /// thing the member signed up for.
  void topUp({
    required int amount,
    int bonus = 0,
    String label = 'Wallet top-up',
    String bonusLabel = 'Bonus credit',
    String date = 'Today',
  }) {
    if (amount <= 0) {
      return;
    }

    _entries.insert(0, WalletEntry(label: label, date: date, amount: amount));
    _balance += amount;

    if (bonus > 0) {
      _entries.insert(
        0,
        WalletEntry(label: bonusLabel, date: date, amount: bonus),
      );
      _balance += bonus;
    }
    notifyListeners();
  }

  /// Converts [points] into wallet balance and records a ledger credit.
  bool redeemPoints({int? points, String date = 'Today'}) {
    final toRedeem = points ?? _rewardPoints;
    if (toRedeem <= 0 || toRedeem > _rewardPoints) {
      return false;
    }

    _rewardPoints -= toRedeem;
    _entries.insert(
      0,
      WalletEntry(
        label: 'Shield points redeemed · $toRedeem pts',
        date: date,
        amount: toRedeem,
      ),
    );
    _balance += toRedeem;
    notifyListeners();
    return true;
  }

  @visibleForTesting
  void reset() {
    _balance = openingBalance;
    _rewardPoints = openingRewardPoints;
    _entries
      ..clear()
      ..addAll(_seed);
    notifyListeners();
  }
}
