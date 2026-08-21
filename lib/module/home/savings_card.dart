import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The savings panel that replaced the app-download promo.
///
/// A "get the app" block is dead weight inside the app itself — the reader is
/// already here. This offers something they can act on instead: the coupon,
/// what it saves, and the promises behind it.
class SavingsCard extends StatelessWidget {
  const SavingsCard({super.key});

  static const String couponCode = 'SHIELD28';

  static const List<_Assurance> _assurances = [
    _Assurance(Icons.repeat_rounded, 'Repeat in\none tap'),
    _Assurance(Icons.verified_outlined, 'Genuine,\nbill included'),
    _Assurance(Icons.local_shipping_outlined, 'Free over\n₹500'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: AppColors.offerTint,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_offer_rounded,
                  size: 16,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  'OFFER FOR YOU',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Save 28% on your medicines',
              style: TextStyle(
                fontSize: 24,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Applied automatically at checkout on your first order.',
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 16),
            const _CouponChip(),
            const SizedBox(height: 18),
            // Wrap, not Row: three items of two-line copy overflow a Row at
            // 320px, and wrapping is better here than shrinking the text.
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                for (final assurance in _assurances)
                  _AssuranceItem(assurance: assurance),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponChip extends StatelessWidget {
  const _CouponChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.brandGreenDeep, width: 1.4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            size: 18,
            color: AppColors.brandGreenDark,
          ),
          const SizedBox(width: 8),
          Text(
            SavingsCard.couponCode,
            style: const TextStyle(
              fontSize: 16,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _Assurance {
  final IconData icon;
  final String label;

  const _Assurance(this.icon, this.label);
}

class _AssuranceItem extends StatelessWidget {
  final _Assurance assurance;

  const _AssuranceItem({required this.assurance});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(assurance.icon, size: 20, color: AppColors.brandBlue),
        const SizedBox(width: 7),
        Text(
          assurance.label,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: AppColors.textBody,
          ),
        ),
      ],
    );
  }
}
