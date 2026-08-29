import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../cart/cart_bar.dart';
import '../cart/cart_screen.dart';
import '../cart/cart_service.dart';
import '../categories/category_listing_screen.dart' show ProductTile;
import 'product_showcase.dart';

/// The full contents of one home showcase — "Popular Items", "Deals You Love"
/// and the like — laid out as a scrollable grid.
///
/// The showcase on the feed is a clipped, horizontally scrolling row; "View
/// all" brings the reader here to the same products with room to see every
/// one, reusing the category listing's [ProductTile] so a card looks the same
/// wherever it is met.
class ProductCollectionScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Product> products;

  const ProductCollectionScreen({
    super.key,
    required this.title,
    required this.products,
    this.subtitle,
  });

  /// Horizontal padding either side of the grid, and the gap between columns.
  static const double _pad = 12;
  static const double _gap = 12;

  double _columnWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width - _pad * 2 - _gap) / 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          _CartAction(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CartScreen())),
          ),
          const SizedBox(width: 12),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              if (subtitle != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    '${products.length} '
                    'item${products.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_pad, 14, _pad, 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: _gap,
                    mainAxisExtent:
                        _columnWidth(context) + ProductTile.detailsExtent,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ProductTile(product: products[index]),
                    childCount: products.length,
                  ),
                ),
              ),
              // Clears the floating cart bar so the last row stays reachable.
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: CartBar()),
        ],
      ),
    );
  }
}

/// Cart circle in the app bar, carrying the live item count.
class _CartAction extends StatelessWidget {
  final VoidCallback onTap;

  const _CartAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService.instance,
      builder: (context, _) {
        final count = CartService.instance.itemCount;
        return Semantics(
          button: true,
          label: count == 0 ? 'Cart' : 'Cart · $count items',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: AppColors.white,
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.searchBorder),
                ),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 21,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD93A2B),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
