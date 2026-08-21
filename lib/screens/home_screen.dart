import 'package:flutter/material.dart';

import '../module/cart/cart_badge.dart';
import '../theme/app_colors.dart';
import '../module/home/brand_quote.dart';
import '../module/home/category_section.dart';
import '../module/home/customer_reviews.dart';
import '../module/home/customer_testimonials.dart';
import '../module/home/health_articles.dart';
import '../module/home/home_footer.dart';
import '../module/home/home_header.dart';
import '../module/home/home_hero_banner.dart';
import '../module/home/how_it_works.dart';
import '../module/home/prescription_card.dart';
import '../module/home/product_showcase.dart';
import '../module/home/refer_earn_card.dart';
import '../module/home/why_shield.dart';
import '../module/privilege/privilege_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pageTint,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // Collapses on scroll down to just the search field and the cart.
            const SliverPersistentHeader(
              pinned: true,
              delegate: _CollapsingTopChrome(),
            ),

            SliverList(
              delegate: SliverChildListDelegate([
                const HomeHeroBanner(),
                const PrivilegeCard(),
                const ReferEarnCard(),

                // Directly under Refer & Earn, with no banner between them.
                Container(
                  color: AppColors.white,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
                const CustomerReviews(),
                const CategorySection(),
                const ProductShowcase(
                  title: 'Vitamins & Supplements',
                  subtitle: 'Daily nutrition, covered',
                  products: ProductCatalogue.vitamins,
                ),
                const ProductShowcase(
                  title: 'Popular Items',
                  subtitle: 'What customers reorder the most',
                  products: ProductCatalogue.bestSellers,
                ),
                const ProductShowcase(
                  title: 'Diabetes Care',
                  subtitle: 'Monitoring and everyday essentials',
                  products: ProductCatalogue.diabetesCare,
                ),
                const ProductShowcase(
                  title: 'Health Conditions',
                  subtitle: 'Relief for the everyday complaints',
                  products: ProductCatalogue.healthConditions,
                ),
                const ProductShowcase(
                  title: 'Deals You\'ll Love',
                  subtitle: 'Limited-time prices, while stocks last',
                  products: ProductCatalogue.dealsOfTheDay,
                ),
                const ProductShowcase(
                  title: 'New Product Arrivals',
                  subtitle: 'Fresh arrivals picked for you',
                  products: ProductCatalogue.newArrivals,
                ),
                const HealthArticlesSection(),
                const CustomerTestimonials(),
                const WhyShieldSection(),
                const HowItWorksSection(),
                // The last word before the legal footer: the claim, then the
                // places to follow it up.
                const BrandQuote(),
                const HomeFooter(),
              ]),
            ),
          ],
        ),
      ),
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
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
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

/// Fully expanded height: header row, location line, and the search field.
const double _chromeMaxExtent = 158;

/// Collapsed height: the search field and the cart, with [_chromeTopPad] of
/// clear space above and below them.
const double _chromeMinExtent = 74;

/// Breathing room above the top row, in both states. The collapsed bar sits
/// this far down from the top edge rather than flush against it.
const double _chromeTopPad = 12;

/// Centred against [HomeHeader.rowHeight], which the header pins down, so the
/// cart lines up with the wallet no matter what the fonts do.
const double _cartTop = _chromeTopPad + (HomeHeader.rowHeight - _cartSize) / 2;
const double _cartRight = 8;
const double _cartSize = 42;
const double _searchExpandedTop = 94;

/// Collapsed, the search shares the cart's gap from the top edge.
const double _searchCollapsedTop = _chromeTopPad;

/// Pins the top chrome and collapses it as the feed scrolls.
///
/// The cart is drawn here rather than inside [HomeHeader], at a fixed offset
/// that is identical in both states — so the header and location fade away
/// beneath it and the search field rises to meet it, but the cart itself never
/// moves a pixel.
class _CollapsingTopChrome extends SliverPersistentHeaderDelegate {
  const _CollapsingTopChrome();

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);

    final searchTop =
        _searchExpandedTop + (_searchCollapsedTop - _searchExpandedTop) * t;
    // Once collapsed the search has to stop short of the cart; expanded it can
    // run the full width because the cart is a row above it.
    final searchRight = 16 + (_cartRight + _cartSize + 10 - 16) * t;

    return Material(
      color: AppColors.pageTint,
      elevation: overlapsContent ? 2 : 0,
      shadowColor: AppColors.textDark.withValues(alpha: 0.18),
      child: SizedBox.expand(
        child: ClipRect(
          child: Stack(
            children: [
              // Menu, wordmark, wallet and location: fade out on the way down.
              Positioned(
                top: 0,
                left: 0,
                // Leaves the cart's column clear so the wallet never overlaps.
                right: _cartRight + _cartSize + 2,
                child: IgnorePointer(
                  ignoring: t > 0.5,
                  child: Opacity(
                    opacity: 1 - t,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(12, _chromeTopPad, 0, 0),
                      child: HomeHeader(showCart: false),
                    ),
                  ),
                ),
              ),

              // Fixed in both states.
              const Positioned(
                top: _cartTop,
                right: _cartRight,
                child: CartBadge(),
              ),

              Positioned(
                top: searchTop,
                left: 16,
                right: searchRight,
                child: const _SearchField(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => _chromeMaxExtent;

  @override
  double get minExtent => _chromeMinExtent;

  @override
  bool shouldRebuild(covariant _CollapsingTopChrome oldDelegate) => false;
}
