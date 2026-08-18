import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// App-exclusive discount panel with the store-listing mockup on the right.
class AppOfferCard extends StatelessWidget {
  const AppOfferCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: AppColors.offerTint,
        padding: const EdgeInsets.only(left: 18, top: 18, bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(flex: 5, child: _OfferCopy()),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.86,
                      child: const _PhoneMockup(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: _StoreStats(),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: _DownloadButton(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferCopy extends StatelessWidget {
  const _OfferCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            Icon(Icons.radio_button_checked, size: 13, color: AppColors.brandBlue),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'APP EXCLUSIVE OFFER',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: AppColors.brandBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Save ',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              TextSpan(
                text: '28%',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.brandBlue,
                  decorationThickness: 2.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'on your medicines',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.brandGreen, width: 1.3),
          ),
          child: const Text(
            'TM28APP',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  const _PhoneMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          bottomLeft: Radius.circular(22),
        ),
        border: Border.all(color: AppColors.textDark, width: 3),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                color: AppColors.textDark,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Image.asset(
                'assets/logos/shield_logo.png',
                height: 26,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'SHIELD – Online\nHealth App',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE7EBF0),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Install',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreStats extends StatelessWidget {
  const _StoreStats();

  @override
  Widget build(BuildContext context) {
    // Wrap so the rating group drops to a second line on narrow phones
    // instead of running past the card edge.
    return const Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '1Cr+ ',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              TextSpan(
                text: 'Downloads',
                style: TextStyle(fontSize: 14.5, color: AppColors.textBody),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 18, color: Color(0xFFF5A623)),
            SizedBox(width: 3),
            Flexible(
              child: Text.rich(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                TextSpan(
                  children: [
                    TextSpan(
                      text: '4.5 ',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    TextSpan(
                      text: '5.61L reviews',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandBlue,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(10),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Download App',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Spacer(),
              Icon(Icons.play_arrow_rounded, color: AppColors.white, size: 24),
              SizedBox(width: 12),
              Icon(Icons.apple, color: AppColors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
