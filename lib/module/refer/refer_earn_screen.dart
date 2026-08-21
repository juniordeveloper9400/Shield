import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/app_colors.dart';
import 'journey_map.dart';
import 'referral_level.dart';

/// Refer & earn: current standing, the shareable code, and the level ladder
/// drawn as a journey map.
class ReferEarnScreen extends StatelessWidget {
  final ReferralProgress progress;

  const ReferEarnScreen({
    super.key,
    this.progress = ReferralLadder.sampleProgress,
  });

  static const String referralCode = 'SHIELD-RN4821';

  @override
  Widget build(BuildContext context) {
    const levels = ReferralLadder.levels;
    final cleared = progress.currentLevel(levels);
    final next = progress.nextLevel(levels);

    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Refer & Earn',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _StandingCard(
              cleared: cleared,
              next: next,
              progress: progress,
              totalLevels: levels.length,
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _CodeCard(code: referralCode),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Your journey',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Text(
              'Clear each level to unlock the next reward.',
              style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 18),
          JourneyMap(levels: levels, progress: progress),
        ],
      ),
    );
  }
}

class _StandingCard extends StatelessWidget {
  final int cleared;
  final ReferralLevel? next;
  final ReferralProgress progress;
  final int totalLevels;

  const _StandingCard({
    required this.cleared,
    required this.next,
    required this.progress,
    required this.totalLevels,
  });

  @override
  Widget build(BuildContext context) {
    final nextLevel = next;
    final fraction = nextLevel == null
        ? 1.0
        : progress.progressTowards(nextLevel);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandBlue, AppColors.brandNavy],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Current level',
                  style: TextStyle(fontSize: 13.5, color: Color(0xFFC9D8F0)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$cleared of $totalLevels',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            cleared == 0
                ? 'Not started'
                : 'Level $cleared · ${ReferralLadder.levels[cleared - 1].title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Metric(value: '${progress.directReferrals}', label: 'Referred'),
              _Metric(value: '${progress.effectiveCards}', label: 'Privilege'),
              const _Metric(value: '₹300', label: 'Earned'),
            ],
          ),
          if (nextLevel != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: const Color(0x33FFFFFF),
                valueColor: const AlwaysStoppedAnimation(AppColors.brandGreen),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Refer '
              '${(nextLevel.directRequired - progress.directReferrals).clamp(0, 99)}'
              ' more to reach Level ${nextLevel.level} and earn '
              '${nextLevel.reward}',
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFFDCE7F7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFFC9D8F0)),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String code;

  const _CodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your invite code',
            style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pageTint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.brandGreen, width: 1.3),
                  ),
                  child: Text(
                    code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _InviteButton(code: code),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  final String code;

  const _InviteButton({required this.code});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await SharePlus.instance.share(
            ShareParams(
              subject: 'Join me on SHIELD',
              text:
                  'Join me on SHIELD! Save up to 51% on medicines and unlock Privilege membership. '
                  'Use my invite code $code when you sign up.',
            ),
          );
        } on Exception {
          // Platforms without a share sheet (some desktop browsers) throw
          // rather than silently doing nothing.
          messenger.showSnackBar(
            const SnackBar(content: Text('Sharing is not available here')),
          );
        }
      },
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
      label: const Text(
        'Invite',
        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandBlue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
