import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Trust block near the foot of the home feed: the four promises the rest of
/// the app is built around.
///
/// Laid out as full-width rows rather than a grid. A two-column grid fits at
/// 400px but not at 320, and the copy here is a sentence rather than a label,
/// so rows stay readable at every width the app supports.
class WhyShieldSection extends StatelessWidget {
  const WhyShieldSection({super.key});

  static const List<_Promise> _promises = [
    _Promise(
      icon: Icons.verified_outlined,
      title: '100% genuine medicines',
      body: 'Sourced directly from licensed distributors, never a marketplace.',
      tint: AppColors.offerTint,
      accent: AppColors.brandBlue,
    ),
    _Promise(
      icon: Icons.savings_outlined,
      title: 'Save up to 51%',
      body: 'We show you the equivalent salt at a lower price on every search.',
      tint: AppColors.greenTint,
      accent: AppColors.brandGreenDark,
    ),
    _Promise(
      icon: Icons.local_shipping_outlined,
      title: 'Free delivery over ₹500',
      body: 'Temperature-controlled packing, tracked from our door to yours.',
      tint: AppColors.offerTint,
      accent: AppColors.brandBlue,
    ),
    _Promise(
      icon: Icons.medical_information_outlined,
      title: 'Checked by pharmacists',
      body: 'Every prescription is verified by a registered pharmacist first.',
      tint: AppColors.greenTint,
      accent: AppColors.brandGreenDark,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why shop with SHIELD',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'The same medicine, for less, without the guesswork',
            style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          for (final promise in _promises) ...[
            _PromiseRow(promise: promise),
            if (promise != _promises.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _Promise {
  final IconData icon;
  final String title;
  final String body;
  final Color tint;
  final Color accent;

  const _Promise({
    required this.icon,
    required this.title,
    required this.body,
    required this.tint,
    required this.accent,
  });
}

class _PromiseRow extends StatelessWidget {
  final _Promise promise;

  const _PromiseRow({required this.promise});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: promise.tint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(promise.icon, size: 23, color: promise.accent),
        ),
        const SizedBox(width: 12),
        // Expanded, so a long line wraps instead of overflowing the row.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                promise.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                promise.body,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textBody,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
