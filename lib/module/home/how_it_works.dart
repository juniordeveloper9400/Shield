import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Three-step explainer for the order journey, sat below the trust block.
///
/// A vertical stepper rather than three columns: the step copy is a sentence,
/// and three columns of prose is unreadable at 320px.
class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  static const List<_Step> _steps = [
    _Step(
      icon: Icons.search_rounded,
      title: 'Search or upload',
      body:
          'Type a medicine name, or photograph your prescription and let us '
          'read it for you.',
    ),
    _Step(
      icon: Icons.fact_check_outlined,
      title: 'A pharmacist checks it',
      body:
          'We confirm the salt, the strength and the quantity before anything '
          'is dispatched.',
    ),
    _Step(
      icon: Icons.home_outlined,
      title: 'Delivered to your door',
      body: 'Tracked all the way, with the invoice and the bill in the app.',
    ),
  ];

  /// Diameter of the numbered badge. The connector between two steps is drawn
  /// at this width so it lines up under the badge's centre.
  static const double badgeSize = 38;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pageTint,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How SHIELD works',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Three steps, start to doorstep',
            style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _steps.length; i++)
            _StepRow(
              step: _steps[i],
              number: i + 1,
              isLast: i == _steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String body;

  const _Step({required this.icon, required this.title, required this.body});
}

class _StepRow extends StatelessWidget {
  final _Step step;
  final int number;
  final bool isLast;

  const _StepRow({
    required this.step,
    required this.number,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: HowItWorksSection.badgeSize,
                height: HowItWorksSection.badgeSize,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.brandBlue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ),
              // The rail joining this step to the next one. IntrinsicHeight
              // above is what lets it stretch to whatever the copy needs.
              if (!isLast)
                const Expanded(
                  child: SizedBox(
                    width: 2,
                    child: ColoredBox(color: AppColors.searchBorder),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(step.icon, size: 17, color: AppColors.brandBlue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.body,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
