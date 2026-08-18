import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'circular_badge.dart';

/// "Shop medicines the right way" hero panel.
class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bannerTop, AppColors.bannerBottom],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 16, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Shop medicines\nthe right way',
                  style: TextStyle(
                    fontSize: 27,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const CircularBadge(diameter: 104),
            ],
          ),
          const SizedBox(height: 10),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'with ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                TextSpan(
                  text: 'Branded Substitutes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandGreenDeep,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 1.4, color: AppColors.textDark.withValues(alpha: 0.75)),
          const SizedBox(height: 14),
          // Wrap rather than Row: on narrow phones the two claims cannot sit
          // side by side and would otherwise overflow the banner.
          const Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _ClaimBadge(label: 'Same', highlight: 'Effect'),
              _ClaimBadge(label: 'Same', highlight: 'Composition'),
            ],
          ),
          const SizedBox(height: 18),
          const _LearnMoreButton(),
        ],
      ),
    );
  }
}

class _ClaimBadge extends StatelessWidget {
  final String label;
  final String highlight;

  const _ClaimBadge({required this.label, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.verified_rounded, size: 19, color: AppColors.brandGreenDeep),
        const SizedBox(width: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              TextSpan(
                text: highlight,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LearnMoreButton extends StatelessWidget {
  const _LearnMoreButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandNavy,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(30),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 12, 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Learn more',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 14),
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.brandBlue,
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
