import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../module/home/app_offer_card.dart';
import '../module/home/category_section.dart';
import '../module/home/customer_reviews.dart';
import '../module/home/home_header.dart';
import '../module/home/prescription_card.dart';
import '../module/home/product_showcase.dart';
import '../module/home/promo_banner.dart';
import '../module/home/promo_carousel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pageTint,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 6, 8, 0),
              child: HomeHeader(),
            ),
            const SizedBox(height: 14),
            const _HeroCopy(),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _SearchField(),
            ),
            const SizedBox(height: 18),

            // The banner is full-bleed and the prescription card straddles its
            // lower edge, matching the way the reference layers the two.
            Stack(
              children: [
                Column(
                  children: [
                    const PromoBanner(),
                    Container(height: 62, color: AppColors.white),
                  ],
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.textDark.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const PrescriptionCard(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              child: const AppOfferCard(),
            ),
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.only(bottom: 22),
              child: const PromoCarousel(),
            ),
            const CategorySection(),
            const ProductShowcase(
              title: 'New on SHIELD',
              subtitle: 'Fresh arrivals picked for you',
              products: ProductCatalogue.newArrivals,
            ),
            const ProductShowcase(
              title: 'Best Sellers',
              subtitle: 'What customers reorder the most',
              products: ProductCatalogue.bestSellers,
            ),
            const ProductShowcase(
              title: 'Deals of the Day',
              subtitle: 'Limited-time prices, while stocks last',
              products: ProductCatalogue.dealsOfTheDay,
            ),
            const CustomerReviews(),
            Container(color: AppColors.white, height: 20),
          ],
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Say GoodBye to high medicine prices',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Compare prices and save up to 51%',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15.5, color: AppColors.textBody),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search for medicine',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 16),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.brandBlue,
          size: 24,
        ),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.searchBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.6),
        ),
      ),
    );
  }
}
