import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Swipeable offer strip with a page-dot indicator, matching the promo
/// carousel that sits below the app-download panel.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_Promo> _promos = [
    _Promo(
      titleTop: 'Extra Bachat',
      titleMiddle: 'On Every ',
      titleAccent: 'Refill',
      titleTail: '!',
      cta: 'Order Now',
      code: 'SHIELD28',
      percent: '28%',
      background: AppColors.creamTint,
    ),
    _Promo(
      titleTop: 'Health Essentials',
      titleMiddle: 'Up to ',
      titleAccent: '50%',
      titleTail: ' Off',
      cta: 'Order Now',
      code: 'SHIELD50',
      percent: '50%',
      background: AppColors.greenTint,
    ),
    _Promo(
      titleTop: 'Lab Tests',
      titleMiddle: 'Flat ',
      titleAccent: '35%',
      titleTail: ' Off',
      cta: 'Book Now',
      code: 'LAB35',
      percent: '35%',
      background: AppColors.offerTint,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _controller,
            itemCount: _promos.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PromoCard(promo: _promos[index]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < _promos.length; index++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 4,
                width: index == _page ? 26 : 18,
                decoration: BoxDecoration(
                  color: index == _page
                      ? AppColors.brandBlue
                      : AppColors.searchBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  final _Promo promo;

  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: promo.background,
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    promo.titleTop,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text.rich(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    TextSpan(
                      children: [
                        TextSpan(
                          text: promo.titleMiddle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        TextSpan(
                          text: promo.titleAccent,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandBlue,
                          ),
                        ),
                        TextSpan(
                          text: promo.titleTail,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: const Color(0xFFF5C518),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Text(
                          promo.cta,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 4, child: _CouponArt(promo: promo)),
          ],
        ),
      ),
    );
  }
}

/// Stylised coupon ticket standing in for the marketing artwork.
class _CouponArt extends StatelessWidget {
  final _Promo promo;

  const _CouponArt({required this.promo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.brandBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.brandGreenDeep,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'EXCLUSIVE COUPON',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'GET FLAT',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.white,
            ),
          ),
          Text(
            promo.percent,
            style: const TextStyle(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: AppColors.white,
            ),
          ),
          const Text(
            'OFF',
            style: TextStyle(
              fontSize: 16,
              height: 1,
              fontWeight: FontWeight.w900,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              promo.code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.brandBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Promo {
  final String titleTop;
  final String titleMiddle;
  final String titleAccent;
  final String titleTail;
  final String cta;
  final String code;
  final String percent;
  final Color background;

  const _Promo({
    required this.titleTop,
    required this.titleMiddle,
    required this.titleAccent,
    required this.titleTail,
    required this.cta,
    required this.code,
    required this.percent,
    required this.background,
  });
}
