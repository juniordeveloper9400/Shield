import 'package:flutter/material.dart';

import '../../money.dart';
import '../../theme/app_colors.dart';

/// A named privilege card.
///
/// Every card carries the same 10% bonus — the tiers differ only in how much
/// is loaded, so the name is a badge rather than a better rate. Stating that
/// plainly beats implying a rate that scales when it does not.
class PrivilegeTier {
  final String name;
  final int amount;

  /// One line on the card explaining who the tier suits.
  final String blurb;

  /// The card's own colour. Each tier owns a hue so the five are told apart
  /// at a glance rather than by reading the amounts.
  final Color accent;

  /// The pale wash of [accent] the card sits on when selected.
  final Color tint;

  const PrivilegeTier({
    required this.name,
    required this.amount,
    required this.blurb,
    required this.accent,
    required this.tint,
  });

  /// What SHIELD adds on top.
  int get bonus => PrivilegeProgramme.bonusOn(amount);

  /// What lands in the wallet in total.
  int get credited => amount + bonus;

  String get amountLabel => '₹${formatRupees(amount)}';

  String get bonusLabel => '₹${formatRupees(bonus)}';

  String get creditedLabel => '₹${formatRupees(credited)}';
}

/// The privilege programme's rules and its published cards.
class PrivilegeProgramme {
  const PrivilegeProgramme._();

  /// SHIELD adds this share of whatever is loaded.
  static const double bonusRate = 0.10;

  /// Loads are in whole multiples of this, starting at one of them.
  static const int step = 10000;

  /// Guards a custom entry against a typo that would load a fortune.
  static const int maxAmount = 500000;

  static const List<PrivilegeTier> tiers = [
    PrivilegeTier(
      name: 'Silver Shield',
      amount: 10000,
      blurb: 'A year of routine refills for one person.',
      accent: AppColors.silverAccent,
      tint: AppColors.silverTint,
    ),
    PrivilegeTier(
      name: 'Gold Shield',
      amount: 20000,
      blurb: 'Covers a couple, with room for lab tests.',
      accent: AppColors.goldAccent,
      tint: AppColors.goldTint,
    ),
    PrivilegeTier(
      name: 'Platinum Shield',
      amount: 30000,
      blurb: 'A family on long-term medication.',
      accent: AppColors.platinumAccent,
      tint: AppColors.platinumTint,
    ),
    PrivilegeTier(
      name: 'Titanium Shield',
      amount: 40000,
      blurb: 'Chronic care across several patients.',
      accent: AppColors.titaniumAccent,
      tint: AppColors.titaniumTint,
    ),
    PrivilegeTier(
      name: 'Diamond Shield',
      amount: 50000,
      blurb: 'The largest published card, and the largest bonus.',
      accent: AppColors.diamondAccent,
      tint: AppColors.diamondTint,
    ),
  ];

  /// 10% of [amount], rounded down to the rupee.
  ///
  /// Down rather than to nearest: a bonus is a promise, and the safe direction
  /// to round a promise is the one that cannot overstate it.
  static int bonusOn(int amount) =>
      amount <= 0 ? 0 : (amount * bonusRate).floor();

  static bool isValidAmount(int amount) =>
      amount >= step && amount <= maxAmount && amount % step == 0;

  /// The card an arbitrary amount is issued as.
  ///
  /// Amounts above the published cards keep the top name rather than inventing
  /// one — the bonus rate is identical, so a new name would suggest a benefit
  /// that is not there.
  static PrivilegeTier? tierFor(int amount) {
    if (!isValidAmount(amount)) {
      return null;
    }
    for (final tier in tiers) {
      if (tier.amount == amount) {
        return tier;
      }
    }
    return PrivilegeTier(
      name: tiers.last.name,
      amount: amount,
      blurb: tiers.last.blurb,
      accent: tiers.last.accent,
      tint: tiers.last.tint,
    );
  }
}
