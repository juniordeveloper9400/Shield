import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../catalogue/catalogue_service.dart';
import 'product_showcase.dart';

/// The member home feed's three product tabs: Offer of the Day, Popular Items
/// and Deals You Love. Each tab shows the products the admin ticked for it, so
/// a product added on the admin's Add product page appears under its tab.
class HomeProductTabs extends StatefulWidget {
  const HomeProductTabs({super.key});

  @override
  State<HomeProductTabs> createState() => _HomeProductTabsState();
}

class _HomeProductTabsState extends State<HomeProductTabs> {
  HomeTab _selected = HomeTab.offerOfTheDay;

  static const Map<HomeTab, String> _labels = {
    HomeTab.offerOfTheDay: 'Offer of the Day',
    HomeTab.popular: 'Popular Items',
    HomeTab.deals: 'Deals You Love',
  };

  static const Map<HomeTab, String> _subtitles = {
    HomeTab.offerOfTheDay: 'Handpicked by the pharmacy today',
    HomeTab.popular: 'Freshly added at the pharmacy',
    HomeTab.deals: 'Big savings & special discounts',
  };

  static const Map<HomeTab, String> _empty = {
    HomeTab.offerOfTheDay: 'No offers picked for today yet.',
    HomeTab.popular: 'No popular items picked yet.',
    HomeTab.deals: 'No deals picked yet.',
  };

  /// Each tab's own background — distinguishes the three at a glance, the
  /// whole panel (chip row included), not just the product cards.
  static const Map<HomeTab, Color> _background = {
    HomeTab.offerOfTheDay: AppColors.offerTint,
    HomeTab.popular: AppColors.panelGreen,
    HomeTab.deals: AppColors.panelCream,
  };

  /// Each tab's accent — the selected chip's fill and the row title's
  /// colour, tuned to read clearly against that tab's [_background].
  static const Map<HomeTab, Color> _accent = {
    HomeTab.offerOfTheDay: AppColors.brandBlue,
    HomeTab.popular: AppColors.brandGreenDeep,
    HomeTab.deals: AppColors.goldAccent,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CatalogueService.instance,
      builder: (context, _) {
        final catalogue = CatalogueService.instance;
        final products = catalogue.homeTabProducts(_selected);
        final background = _background[_selected]!;
        final accent = _accent[_selected]!;

        return Container(
          color: background,
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final tab in HomeTab.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: ValueKey('home-tab-${tab.name}'),
                          label: Text(_labels[tab]!),
                          selected: _selected == tab,
                          selectedColor: _accent[tab]!,
                          backgroundColor: AppColors.white,
                          labelStyle: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _selected == tab ? AppColors.white : AppColors.textDark,
                          ),
                          onSelected: (_) => setState(() => _selected = tab),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (products.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Text(
                    _empty[_selected]!,
                    key: const ValueKey('home-tab-empty'),
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
                  ),
                )
              else
                ProductShowcase(
                  title: _labels[_selected]!,
                  subtitle: _subtitles[_selected],
                  products: products,
                  backgroundColor: background,
                  titleColor: accent,
                ),
            ],
          ),
        );
      },
    );
  }
}
