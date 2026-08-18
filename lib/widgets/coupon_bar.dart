import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Sticky promotional strip that sits directly above the bottom navigation.
class CouponBar extends StatelessWidget {
  final VoidCallback? onApply;

  const CouponBar({super.key, this.onApply});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandGreenDark,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.percent_rounded,
              size: 16,
              color: AppColors.brandGreenDark,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'FLAT 26% off on medicines & get 2% cashback',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onApply,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.brandBlue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Apply',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
