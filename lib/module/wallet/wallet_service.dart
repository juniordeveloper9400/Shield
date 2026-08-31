import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../dates.dart';
import '../../money.dart';
import '../privilege/privilege_tier.dart';
import '../registration/shield_store.dart';

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

/// A privilege plan the account holds: what was loaded onto it, when, and
/// until when it is good for.
///
/// A plan rather than a bare [PrivilegeLoad] because the wallet has to answer
/// two questions the load cannot: when money last went on, and when it stops
/// working. Both are dates, and both are per plan — an account holding a
/// silver plan from March and a gold one from August expires them on
/// different days.
@immutable
class WalletCard {
  final PrivilegeLoad load;

  /// The day the card was issued. Validity runs from here.
  final DateTime issuedOn;

  /// The day money last went onto it — the issue date until it is topped up.
  final DateTime rechargedOn;

  /// Topped up onto the card since it was issued, over and above the load it
  /// was issued for.
  final int recharged;

  /// The SHIELD branch this plan was activated against — the one a member with
  /// more than one plan can bill a later order to by picking this plan at
  /// checkout. Null on plans activated before the branch was recorded.
  final ShieldStore? store;

  const WalletCard({
    required this.load,
    required this.issuedOn,
    required this.rechargedOn,
    this.recharged = 0,
    this.store,
  });

  String get name => load.name;

  /// Everything the card carries: what it was issued with, bonus included,
  /// plus every recharge since.
  int get loaded => load.credited + recharged;

  /// A twelfth of what is on the card, which is what comes due each month.
  ///
  /// Off the programme's own rule, the same one the card was sold on, so what
  /// the wallet releases matches what the privilege screen offered.
  int get monthlyRedeemable => PrivilegeProgramme.monthlyShareOf(loaded);

  /// The day of the month this card's instalment falls due.
  ///
  /// Its issue day, and the reason two cards on one account do not come due
  /// together: a card taken on the 10th releases a twelfth on the 10th of
  /// every month, and one taken on the 25th waits until the 25th.
  int get cycleDay => issuedOn.day;

  /// The day this card comes due in the month [asOf] falls in.
  ///
  /// Clamped to the length of that month, so a card issued on the 31st comes
  /// due on the 28th in February rather than slipping into March.
  DateTime dueDayIn(DateTime asOf) {
    final lastOfMonth = DateTime(asOf.year, asOf.month + 1, 0).day;
    return DateTime(asOf.year, asOf.month, math.min(cycleDay, lastOfMonth));
  }

  /// Whether this card's instalment for the month [asOf] falls in has been
  /// released.
  ///
  /// A card issued on the 25th is not drawable on the 24th of a later month:
  /// its month has not come round yet. An expired card never is.
  bool isActiveOn(DateTime asOf) {
    if (asOf.isAfter(expiresOn) || asOf.isBefore(issuedOn)) {
      return false;
    }
    return !asOf.isBefore(dueDayIn(asOf));
  }

  /// The next day this card comes due: this month's if it has not passed,
  /// otherwise next month's.
  DateTime nextDueOn(DateTime asOf) {
    final thisMonth = dueDayIn(asOf);
    if (!asOf.isBefore(thisMonth)) {
      return dueDayIn(DateTime(asOf.year, asOf.month + 1, 1));
    }
    return thisMonth;
  }

  /// Which instalment of [PrivilegeProgramme.validityMonths] the card is on,
  /// counting from one on the day it was issued.
  int instalmentOn(DateTime asOf) {
    var months =
        (asOf.year - issuedOn.year) * 12 + (asOf.month - issuedOn.month);
    if (asOf.day < dueDayIn(asOf).day) {
      // This month's has not been released yet, so the card is still on the
      // one before it.
      months -= 1;
    }
    return (months + 1).clamp(1, PrivilegeProgramme.validityMonths);
  }

  /// What has been released off this card so far: one instalment for every
  /// month that has come due.
  int releasedBy(DateTime asOf) => monthlyRedeemable * instalmentOn(asOf);

  /// What is still locked up in the card, waiting on later months.
  int remainingAfter(DateTime asOf) {
    final left = loaded - releasedBy(asOf);
    return left < 0 ? 0 : left;
  }

  /// A year on from issue, to the day.
  DateTime get expiresOn {
    final months = issuedOn.month - 1 + PrivilegeProgramme.validityMonths;
    return DateTime(
      issuedOn.year + months ~/ 12,
      months % 12 + 1,
      issuedOn.day,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresOn);

  String get loadedLabel => '₹${formatRupees(loaded)}';

  String get rechargedOnLabel => formatDate(rechargedOn);

  String get expiresOnLabel => formatDate(expiresOn);

  /// A recharge of [amount] on [date]: the same card, carrying more. The
  /// activation branch is fixed on the first issue and rides through recharges.
  WalletCard rechargedWith(int amount, DateTime date) => WalletCard(
    load: load,
    issuedOn: issuedOn,
    rechargedOn: date,
    recharged: recharged + amount,
    store: store,
  );
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

  /// What is in the wallet before a plan opens it: nothing.
  ///
  /// It used to open at ₹3,472 against a ledger of five made-up transactions —
  /// an order, a top-up, a referral reward, a cashback. That money came from
  /// nowhere. A wallet is opened by activating a privilege plan and is filled
  /// by that plan, so the only figure it can honestly show before one is
  /// activated is zero, and the only lines in it afterwards are the ones the
  /// plan actually put there.
  ///
  /// It stays a named constant because a backend would fill it from the
  /// account rather than from here.
  static const int openingBalance = 0;

  /// Opening reward / redeem points. Nothing, for the same reason.
  static const int openingRewardPoints = 0;

  /// The ledger a wallet opens with. Empty: every line in the wallet is put
  /// there by something the member did.
  static const List<WalletEntry> _seed = [];

  int _balance = openingBalance;
  int _rewardPoints = openingRewardPoints;
  int _redeemed = 0;
  final List<WalletEntry> _entries = List.of(_seed);

  /// The cards on the account, oldest first, or empty while the wallet is
  /// still closed.
  final List<WalletCard> _cards = [];

  int get balance => _balance;
  int get rewardPoints => _rewardPoints;

  /// Every card on the account, oldest first. What the back of the wallet
  /// card lists: an account may hold more than one, and each carries its own
  /// recharge and expiry dates.
  List<WalletCard> get cards => List.unmodifiable(_cards);

  /// The card in hand — the most recently issued one.
  ///
  /// The wallet is drawn against the whole set, but the screens that name one
  /// card mean this one.
  PrivilegeLoad? get card => _cards.isEmpty ? null : _cards.last.load;

  /// A wallet is opened by activating a privilege card and not otherwise.
  ///
  /// The programme is the way in: money is loaded onto a card, the card opens
  /// the wallet, and the wallet spends it. Nothing moves before that, so the
  /// flag is checked here as well as being drawn in the UI — a locked wallet
  /// that could still be topped up through some other path would not be
  /// locked at all.
  bool get isActivated => _cards.isNotEmpty;

  /// What comes due this month across every card that has come round.
  ///
  /// The cards pool once they are due — two cards are two twelfths, drawn from
  /// one balance — but they do not come due together. Each releases its
  /// twelfth on its own issue day, so an account holding a card from the 10th
  /// and one from the 25th can draw on the first from the 10th of a month and
  /// on the second only from the 25th. A card whose day has not come round,
  /// or one that has expired, adds nothing.
  int monthlyRedeemableOn(DateTime asOf) {
    var total = 0;
    for (final card in _cards) {
      if (card.isActiveOn(asOf)) {
        total += card.monthlyRedeemable;
      }
    }
    return total;
  }

  int get monthlyRedeemable => monthlyRedeemableOn(DateTime.now());

  /// The cards drawable right now, and the ones still waiting on their day.
  List<WalletCard> activeCardsOn(DateTime asOf) => [
    for (final card in _cards)
      if (card.isActiveOn(asOf)) card,
  ];

  List<WalletCard> waitingCardsOn(DateTime asOf) => [
    for (final card in _cards)
      if (!card.isActiveOn(asOf)) card,
  ];

  /// What the programme has added on top of what was paid in: the 10% bonus
  /// on every plan the account holds.
  ///
  /// Worked out from the plans rather than tallied off the ledger, so it
  /// cannot drift from the cards it is a bonus on — and so a wallet reset or
  /// a reordered ledger cannot change it.
  int get bonusEarned {
    var total = 0;
    for (final card in _cards) {
      total += card.load.bonus;
    }
    return total;
  }

  /// Drawn against this month's allowance so far.
  ///
  /// Only what has been spent since a card opened the wallet counts: the
  /// seeded ledger predates the card, and was paid out of the wallet's own
  /// balance rather than against an allowance that did not exist yet.
  int get redeemedThisMonth => _redeemed;

  /// What is left of this month's allowance.
  ///
  /// Floored at zero rather than allowed to go negative: an allowance that
  /// has been used up is used up, and a negative one would read as a debt the
  /// member does not owe.
  int get monthlyBalance {
    final left = monthlyRedeemable - _redeemed;
    return left < 0 ? 0 : left;
  }

  /// Newest first, which is the order the screen reads them in.
  List<WalletEntry> get entries => List.unmodifiable(_entries);

  /// Opens the wallet on [load], crediting what was paid and the bonus.
  ///
  /// The one way a wallet comes to be open. Activating a card the account
  /// already holds recharges that card; activating a different one issues a
  /// second card alongside it, which is why the wallet holds a list.
  void activate(
    PrivilegeLoad load, {
    String date = 'Today',
    DateTime? on,
    ShieldStore? store,
  }) {
    final day = on ?? DateTime.now();
    final existing = _cards.indexWhere((card) => card.load == load);
    if (existing >= 0) {
      _cards[existing] = _cards[existing].rechargedWith(load.credited, day);
    } else {
      _cards.add(
        WalletCard(load: load, issuedOn: day, rechargedOn: day, store: store),
      );
    }

    _credit(
      amount: load.amount,
      bonus: load.bonus,
      label: '${load.name} activation',
      bonusLabel: '${load.name} bonus · 10%',
      date: date,
    );
  }

  /// Credits [amount], and [bonus] as its own line.
  ///
  /// Returns false, changing nothing, while the wallet is still closed. The
  /// money goes onto the card in hand, so the back of the wallet card can say
  /// when that card was last recharged.
  bool topUp({
    required int amount,
    int bonus = 0,
    String label = 'Wallet top-up',
    String bonusLabel = 'Bonus credit',
    String date = 'Today',
    DateTime? on,
  }) {
    if (!isActivated || amount <= 0) {
      return false;
    }
    _cards[_cards.length - 1] = _cards.last.rechargedWith(
      amount + bonus,
      on ?? DateTime.now(),
    );
    _credit(
      amount: amount,
      bonus: bonus,
      label: label,
      bonusLabel: bonusLabel,
      date: date,
    );
    return true;
  }

  /// Credits [amount] moved across from the agent portal — commission the
  /// agent has earned and chosen to keep in the app rather than withdraw.
  ///
  /// Unlike [topUp] this does not need a privilege plan: the money is the
  /// agent's own commission, not a programme load, so it lands as a plain
  /// balance line and opens nothing.
  bool creditEarnings({
    required int amount,
    String label = 'Agent earnings added',
    String date = 'Today',
  }) {
    if (amount <= 0) {
      return false;
    }
    _balance += amount;
    _entries.insert(0, WalletEntry(label: label, date: date, amount: amount));
    notifyListeners();
    return true;
  }

  /// Spends [amount] against the wallet, drawing on this month's allowance.
  ///
  /// The one debit path, so [redeemedThisMonth] cannot drift from the ledger.
  /// Refused when the wallet is closed or the balance would go negative — the
  /// wallet holds real money and cannot be overdrawn.
  bool spend({
    required int amount,
    required String label,
    String date = 'Today',
  }) {
    if (!isActivated || amount <= 0 || amount > _balance) {
      return false;
    }

    _balance -= amount;
    _redeemed += amount;
    _entries.insert(0, WalletEntry(label: label, date: date, amount: -amount));
    notifyListeners();
    return true;
  }

  /// Two entries rather than one combined credit: the bonus is the whole point
  /// of the privilege programme, and rolling it into the top-up would hide the
  /// thing the member signed up for.
  void _credit({
    required int amount,
    required int bonus,
    required String label,
    required String bonusLabel,
    required String date,
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
    // Points become wallet balance, so they cannot be redeemed into a wallet
    // that is not open yet.
    if (!isActivated || toRedeem <= 0 || toRedeem > _rewardPoints) {
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
    _cards.clear();
    _balance = openingBalance;
    _rewardPoints = openingRewardPoints;
    _redeemed = 0;
    _entries
      ..clear()
      ..addAll(_seed);
    notifyListeners();
  }
}
