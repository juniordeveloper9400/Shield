import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// One basket's entry point in a page's chrome: a circled cart glyph carrying
/// a red count, hidden while that basket is empty.
///
/// The app checks out three things that cannot be settled together — boxed
/// products, prescriptions waiting on a pharmacist, and lab visits booked per
/// patient — so it keeps three baskets. Each one is now shown on the pages
/// that fill it rather than all three being listed together on the home feed:
/// the cart a member sees is the cart the page in front of them adds to.
///
/// The three differ only in which service they read and which screen they
/// open, so the drawing lives here once. Three hand-copied count bubbles
/// drift apart, and two baskets that look different read as two different
/// features.
class BasketBadge extends StatelessWidget {
  /// The basket to rebuild against — the same object [count] reads, so
  /// filling it anywhere in the app moves the number here.
  final Listenable basket;

  /// What is in it right now, in whatever this basket counts.
  final int Function() count;

  /// Tooltip for the current count.
  final String Function(int count) tooltip;

  /// The basket's own screen, pushed on tap.
  final WidgetBuilder screen;

  const BasketBadge({
    super.key,
    required this.basket,
    required this.count,
    required this.tooltip,
    required this.screen,
  });

  static const Color badgeColour = Color(0xFFD93025);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: basket,
      builder: (context, _) {
        final filled = count();

        return Tooltip(
          message: tooltip(filled),
          child: Material(
            color: AppColors.white,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.searchBorder),
            ),
            child: InkWell(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: screen)),
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 42,
                height: 42,
                // Clip.none so the count can sit proud of the circle rather
                // than being cut off by it.
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      size: 21,
                      color: AppColors.textDark,
                    ),
                    if (filled > 0)
                      Positioned(
                        top: 2,
                        right: 0,
                        child: _Count(count: filled),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Count extends StatelessWidget {
  final int count;

  const _Count({required this.count});

  @override
  Widget build(BuildContext context) {
    // Past 99 the number would outgrow the circle, so it caps.
    final label = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: EdgeInsets.symmetric(horizontal: label.length > 1 ? 4 : 0),
      decoration: BoxDecoration(
        color: BasketBadge.badgeColour,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 10.5,
          height: 1,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
        ),
      ),
    );
  }
}
