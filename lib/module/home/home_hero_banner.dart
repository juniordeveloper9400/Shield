import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Top hero promotional banner displayed immediately below the search bar.
class HomeHeroBanner extends StatelessWidget {
  const HomeHeroBanner({super.key});

  static const String assetPath = 'assets/banners/hero_banner.jpg';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.offerTint,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.brandBlue,
                    size: 36,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
