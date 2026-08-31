import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../cart/cart_bar.dart';
import '../cart/cart_screen.dart';
import '../cart/cart_service.dart';
import '../categories/category_listing_screen.dart' show ProductTile;
import '../search/search_screen.dart';
import 'product_showcase.dart';

/// The full contents of one home showcase — "Popular Items", "Deals You Love"
/// and the like — laid out as a scrollable grid.
///
/// Its chrome matches the category listing screen: a search magnifier in the
/// app bar that opens the app-wide product search, and a pinned filter strip
/// carrying the item count and a "Filter" pill for sort / offers. The showcase
/// on the feed is a clipped, horizontally scrolling row; "View all" brings the
/// reader here to the same products with room to see every one, reusing the
/// category listing's [ProductTile] so a card looks the same wherever it is
/// met.
class ProductCollectionScreen extends StatefulWidget {
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

  @override
  State<ProductCollectionScreen> createState() =>
      _ProductCollectionScreenState();
}

class _ProductCollectionScreenState extends State<ProductCollectionScreen> {
  _ProductSort _sort = _ProductSort.featured;
  bool _offersOnly = false;

  double _columnWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width -
          ProductCollectionScreen._pad * 2 -
          ProductCollectionScreen._gap) /
      2;

  /// Sort + offers choices that are doing something — the number on the
  /// filter pill.
  int get _activeFilters =>
      (_offersOnly ? 1 : 0) + (_sort != _ProductSort.featured ? 1 : 0);

  bool get _isNarrowed => _activeFilters > 0;

  /// The row's products with the sort/offers filter applied, in the order the
  /// grid should show them.
  List<Product> get _visible {
    final list = [
      for (final product in widget.products)
        if (!(_offersOnly && product.discountLabel == null)) product,
    ];

    switch (_sort) {
      case _ProductSort.featured:
        break;
      case _ProductSort.priceLowToHigh:
        list.sort((a, b) => _rupees(a.price).compareTo(_rupees(b.price)));
      case _ProductSort.priceHighToLow:
        list.sort((a, b) => _rupees(b.price).compareTo(_rupees(a.price)));
      case _ProductSort.biggestDiscount:
        list.sort(
          (a, b) => _discountPercent(b).compareTo(_discountPercent(a)),
        );
    }
    return list;
  }

  /// The magnifier in the app bar opens the app-wide product search, the same
  /// as the category listing screen's.
  void _openSearch() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
  }

  void _clearFilters() {
    setState(() {
      _sort = _ProductSort.featured;
      _offersOnly = false;
    });
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<_FilterChoice>(
      context: context,
      isScrollControlled: true,
      // Fill the screen, less the status bar — the two-pane filter the
      // category listing screen uses.
      useSafeArea: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _FilterSheet(sort: _sort, offersOnly: _offersOnly),
    );
    if (result != null) {
      setState(() {
        _sort = result.sort;
        _offersOnly = result.offersOnly;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final total = widget.products.length;
    final count = _isNarrowed
        ? '${visible.length} of $total item${total == 1 ? '' : 's'}'
        : '$total item${total == 1 ? '' : 's'}';

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          _CircleAction(icon: Icons.search_rounded, onTap: _openSearch),
          const SizedBox(width: 10),
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
              if (widget.subtitle != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Text(
                      widget.subtitle!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              // Item count + filter pill: pinned, so the filter stays one reach
              // away however far the grid has scrolled.
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedFilterHeader(
                  child: _FilterRow(
                    countLabel: count,
                    activeCount: _activeFilters,
                    onOpenFilter: _openFilter,
                  ),
                ),
              ),
              if (visible.isEmpty)
                SliverToBoxAdapter(
                  child: _NoMatches(onClear: _clearFilters),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    ProductCollectionScreen._pad,
                    14,
                    ProductCollectionScreen._pad,
                    8,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: ProductCollectionScreen._gap,
                      mainAxisExtent:
                          _columnWidth(context) + ProductTile.detailsExtent,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ProductTile(product: visible[index]),
                      childCount: visible.length,
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

/// Featured is the row's own order — the one the feed showed.
enum _ProductSort {
  featured('Featured'),
  priceLowToHigh('Price — low to high'),
  priceHighToLow('Price — high to low'),
  biggestDiscount('Biggest discount');

  const _ProductSort(this.label);

  final String label;
}

/// `1,749` and `899` both come in as strings with grouping commas; strip
/// everything but the digits to compare them.
int _rupees(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// The number out of a `38% OFF` badge, or 0 when the product carries none.
int _discountPercent(Product product) {
  final label = product.discountLabel;
  if (label == null) {
    return 0;
  }
  final match = RegExp(r'(\d+)').firstMatch(label);
  return match == null ? 0 : int.parse(match.group(1)!);
}

/// Circle icon button in the app bar — the magnifier and, alongside it, the
/// cart. The same shape the category listing screen uses.
class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.searchBorder),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 21, color: AppColors.textDark),
        ),
      ),
    );
  }
}

/// Height of the pinned filter strip.
const double _filterRowHeight = 52;

/// Pins the item-count-and-filter strip to the top of the grid while it
/// scrolls beneath, the same as the category listing screen's sticky header.
class _PinnedFilterHeader extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _PinnedFilterHeader({required this.child});

  @override
  double get minExtent => _filterRowHeight;

  @override
  double get maxExtent => _filterRowHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppColors.white,
      elevation: overlapsContent ? 3 : 0,
      shadowColor: AppColors.textDark.withValues(alpha: 0.15),
      child: SizedBox(height: _filterRowHeight, child: child),
    );
  }

  // The child closes over the current filter, so it is a fresh widget on
  // every rebuild.
  @override
  bool shouldRebuild(_PinnedFilterHeader oldDelegate) => true;
}

/// The pinned strip: how many items are showing, and the "Filter" pill.
class _FilterRow extends StatelessWidget {
  final String countLabel;
  final int activeCount;
  final VoidCallback onOpenFilter;

  const _FilterRow({
    required this.countLabel,
    required this.activeCount,
    required this.onOpenFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _filterRowHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: ProductCollectionScreen._pad,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              countLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          _FilterPill(onTap: onOpenFilter, activeCount: activeCount),
        ],
      ),
    );
  }
}

/// "Filter" affordance. Carries a count badge once the sheet has narrowed the
/// grid, so an active filter is visible without opening it. The rounded pill
/// the category listing screen uses.
class _FilterPill extends StatelessWidget {
  final VoidCallback onTap;
  final int activeCount;

  const _FilterPill({required this.onTap, required this.activeCount});

  @override
  Widget build(BuildContext context) {
    final active = activeCount > 0;

    return Material(
      color: active ? AppColors.brandBlue : AppColors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: active ? AppColors.brandBlue : AppColors.searchBorder,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 9, 18, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 18,
                color: active ? AppColors.white : AppColors.textDark,
              ),
              const SizedBox(width: 8),
              Text(
                active ? 'Filter · $activeCount' : 'Filter',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.white : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the filter sheet hands back on Apply.
class _FilterChoice {
  final _ProductSort sort;
  final bool offersOnly;

  const _FilterChoice({required this.sort, required this.offersOnly});
}

/// The left-rail facets, in the order the rail shows them.
enum _Facet {
  sort('Sort'),
  offers('Offers');

  const _Facet(this.label);

  final String label;
}

/// The two-pane filter sheet the category listing screen uses: a rail of
/// facets on the left, that facet's options on the right, and a Clear / Apply
/// bar pinned to the foot. Here the facets are Sort and Offers rather than
/// sub-categories and brands, since a home showcase carries neither.
class _FilterSheet extends StatefulWidget {
  final _ProductSort sort;
  final bool offersOnly;

  const _FilterSheet({required this.sort, required this.offersOnly});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _ProductSort _sort = widget.sort;
  late bool _offersOnly = widget.offersOnly;
  _Facet _facet = _Facet.sort;

  bool get _isActive => _sort != _ProductSort.featured || _offersOnly;

  int get _activeCount =>
      (_sort != _ProductSort.featured ? 1 : 0) + (_offersOnly ? 1 : 0);

  int _countFor(_Facet facet) => switch (facet) {
    _Facet.sort => _sort != _ProductSort.featured ? 1 : 0,
    _Facet.offers => _offersOnly ? 1 : 0,
  };

  String get _paneHeading => switch (_facet) {
    _Facet.sort => 'Sort by',
    _Facet.offers => 'Offers',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: double.infinity,
      child: Column(
        children: [
          _SheetHeader(onClose: () => Navigator.of(context).pop()),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 150,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final facet in _Facet.values)
                        _RailTab(
                          label: facet.label,
                          selected: _facet == facet,
                          count: _countFor(facet),
                          onTap: () => setState(() => _facet = facet),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: AppColors.pageTint,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Text(
                          _paneHeading,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: _facet == _Facet.sort
                              ? [
                                  for (final option in _ProductSort.values)
                                    _OptionRow(
                                      label: option.label,
                                      checked: _sort == option,
                                      onTap: () =>
                                          setState(() => _sort = option),
                                    ),
                                ]
                              : [
                                  _OptionRow(
                                    label: 'All products',
                                    checked: !_offersOnly,
                                    onTap: () =>
                                        setState(() => _offersOnly = false),
                                  ),
                                  _OptionRow(
                                    label: 'On offer only',
                                    checked: _offersOnly,
                                    onTap: () =>
                                        setState(() => _offersOnly = true),
                                  ),
                                ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _SheetFooter(
            canClear: _isActive,
            activeCount: _activeCount,
            onClear: () => setState(() {
              _sort = _ProductSort.featured;
              _offersOnly = false;
            }),
            onApply: () => Navigator.of(context).pop(
              _FilterChoice(sort: _sort, offersOnly: _offersOnly),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Filters" and the round close button, over the two panes.
class _SheetHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _SheetHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
      child: Row(
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const Spacer(),
          Material(
            color: AppColors.white,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.searchBorder),
            ),
            child: InkWell(
              onTap: onClose,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One facet on the left rail, carrying the count of options ticked under it.
class _RailTab extends StatelessWidget {
  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _RailTab({
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.pageTint : AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single-select option row in the right pane.
class _OptionRow extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _OptionRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(
              checked
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 22,
              color: checked ? AppColors.brandBlue : AppColors.searchBorder,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: checked ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clear on the left, a full-width Apply on the right — pinned under the panes.
class _SheetFooter extends StatelessWidget {
  final bool canClear;
  final int activeCount;
  final VoidCallback onClear;
  final VoidCallback onApply;

  const _SheetFooter({
    required this.canClear,
    required this.activeCount,
    required this.onClear,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            TextButton(
              onPressed: canClear ? onClear : null,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandBlue,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onApply,
                child: const Text(
                  'Apply',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of the grid when the filter leaves nothing to list. Mirrors
/// the category listing screen's empty state.
class _NoMatches extends StatelessWidget {
  final VoidCallback onClear;

  const _NoMatches({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 56),
      child: Column(
        children: [
          const Icon(
            Icons.filter_alt_off_outlined,
            size: 44,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 14),
          const Text(
            'No products match your filters',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try removing the sort or the offers filter.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandBlue,
              side: const BorderSide(color: AppColors.brandBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Clear filters'),
          ),
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
