/// One rung of the refer-and-earn ladder.
///
/// A level unlocks when the member has enough direct referrals and enough of
/// those referrals have activated the designated Privilege Card tier.
class ReferralLevel {
  final int level;
  final String title;
  final String? cardName;
  final String requirement;
  final int directRequired;

  /// How many of the referred members must activate a Privilege Card.
  final int cardsRequired;

  final String reward;

  /// Cash rewards render differently from point rewards.
  final bool isCash;

  const ReferralLevel({
    required this.level,
    required this.title,
    this.cardName,
    required this.requirement,
    required this.directRequired,
    required int cardsRequired,
    required this.reward,
    required this.isCash,
  }) : cardsRequired = cardsRequired;

  /// Compatibility alias for subscriptionsRequired.
  int get subscriptionsRequired => cardsRequired;
}

/// How far a member has progressed.
class ReferralProgress {
  final int directReferrals;

  /// Referred members who have activated a Privilege Card.
  final int cardsActivated;

  const ReferralProgress({
    required this.directReferrals,
    required int cardsActivated,
  }) : cardsActivated = cardsActivated;

  const ReferralProgress.legacy({
    required int directReferrals,
    required int subscribedReferrals,
  }) : directReferrals = directReferrals,
       cardsActivated = subscribedReferrals;

  /// Compatibility getter for legacy tests/code.
  int get subscribedReferrals => cardsActivated;

  /// A card activator must be someone the member referred, so the count can
  /// never exceed the referral total. Clamping here stops inconsistent data.
  int get effectiveCards =>
      cardsActivated > directReferrals ? directReferrals : cardsActivated;

  /// Compatibility alias for effectiveSubscriptions.
  int get effectiveSubscriptions => effectiveCards;

  bool isLevelCleared(ReferralLevel level) {
    return directReferrals >= level.directRequired &&
        effectiveCards >= level.cardsRequired;
  }

  /// Highest cleared level, or 0 when nothing is cleared yet.
  int currentLevel(List<ReferralLevel> levels) {
    var cleared = 0;
    for (final level in levels) {
      if (isLevelCleared(level)) {
        cleared = level.level;
      } else {
        break;
      }
    }
    return cleared;
  }

  /// The level being worked towards, or null once every level is cleared.
  ReferralLevel? nextLevel(List<ReferralLevel> levels) {
    for (final level in levels) {
      if (!isLevelCleared(level)) {
        return level;
      }
    }
    return null;
  }

  /// Fraction of the way to [level], clamped to 0..1.
  double progressTowards(ReferralLevel level) {
    if (level.directRequired <= 0) {
      return 1;
    }
    return (directReferrals / level.directRequired).clamp(0.0, 1.0);
  }
}

/// The published ladder based on Privilege Card tiers.
class ReferralLadder {
  const ReferralLadder._();

  static const List<ReferralLevel> levels = [
    ReferralLevel(
      level: 1,
      title: 'Starter',
      requirement: 'Refer 1 member',
      directRequired: 1,
      cardsRequired: 0,
      reward: '100 points',
      isCash: false,
    ),
    ReferralLevel(
      level: 2,
      title: 'Silver Shield',
      cardName: 'Silver Shield',
      requirement: 'Refer 2 members and activate Silver Privilege Card',
      directRequired: 2,
      cardsRequired: 2,
      reward: '₹200',
      isCash: true,
    ),
    ReferralLevel(
      level: 3,
      title: 'Gold Shield',
      cardName: 'Gold Shield',
      requirement: 'Refer 4 members and activate Gold Privilege Card',
      directRequired: 4,
      cardsRequired: 3,
      reward: '₹500',
      isCash: true,
    ),
    ReferralLevel(
      level: 4,
      title: 'Platinum Shield',
      cardName: 'Platinum Shield',
      requirement: 'Refer 8 members and activate Platinum Privilege Card',
      directRequired: 8,
      cardsRequired: 6,
      reward: '₹1,200',
      isCash: true,
    ),
    ReferralLevel(
      level: 5,
      title: 'Diamond Shield',
      cardName: 'Diamond Shield',
      requirement: 'Refer 16 members and activate Diamond Privilege Card',
      directRequired: 16,
      cardsRequired: 12,
      reward: '₹3,000',
      isCash: true,
    ),
  ];

  /// Fixture standing in for the signed-in member's real progress.
  static const ReferralProgress sampleProgress = ReferralProgress(
    directReferrals: 3,
    cardsActivated: 2,
  );
}
