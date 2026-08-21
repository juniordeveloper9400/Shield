import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/social_glyphs.dart';

/// The positioning line, set as the sign-off that closes the home feed.
///
/// It reads as the last word rather than another card: no panel, no border,
/// the mark and the claim centred on the page tint, and the social discs
/// underneath. Set large and softly, because at the end of a long scroll the
/// job is to leave the claim behind, not to compete with the shelves above it.
class BrandQuote extends StatelessWidget {
  const BrandQuote({super.key});

  static const String quote = "World's first smart clinic integrated pharmacy";

  /// Reads as the proof behind the claim: what "integrated" actually buys you.
  static const String support =
      'Doctor consults, lab tests and your medicines — handled in one place.';

  static void _notReadyYet(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label is coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.pageTint,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The claim is long, so it steps down rather than breaking into a
          // stack of short lines on a small handset.
          final double quoteSize = constraints.maxWidth < 300
              ? 24
              : constraints.maxWidth < 340
              ? 27
              : 30;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The mark held back to a watermark: the claim below is what
              // this block is for, and a full-strength logo would out-shout it.
              Opacity(
                opacity: 0.32,
                child: Image.asset(
                  'assets/logos/shield_logo.png',
                  height: 62,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.verified_user_rounded,
                    size: 62,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                quote,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: quoteSize,
                  height: 1.22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.brandBlue.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                support,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 26),
              // Wrap, not Row: at a large text scale the discs step onto a
              // second line instead of running off the edge.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 14,
                children: [
                  for (final network in SocialNetwork.values)
                    SocialIcon(
                      network: network,
                      onTap: () => _notReadyYet(context, network.label),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
