import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'cart_screen.dart';
import 'cart_service.dart';

/// Cart button carrying a red count badge, hidden while the cart is empty.
class CartBadge extends StatelessWidget {
  final double iconSize;
  final bool outlined;

  const CartBadge({super.key, this.iconSize = 21, this.outlined = true});

  static const Color badgeColour = Color(0xFFD93025);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService.instance,
      builder: (context, _) {
        final count = CartService.instance.itemCount;

        return Tooltip(
          message: count == 0 ? 'Cart' : 'Cart · $count items',
          child: Material(
            color: AppColors.white,
            shape: outlined
                ? const CircleBorder(
                    side: BorderSide(color: AppColors.searchBorder),
                  )
                : const CircleBorder(),
            child: InkWell(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CartScreen())),
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 42,
                height: 42,
                // Clip.none so the badge can sit proud of the circle.
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: iconSize,
                      color: AppColors.textDark,
                    ),
                    if (count > 0)
                      Positioned(top: 2, right: 0, child: _Badge(count: count)),
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

class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    // Past 99 the number would outgrow the circle, so it caps.
    final label = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: EdgeInsets.symmetric(horizontal: label.length > 1 ? 4 : 0),
      decoration: BoxDecoration(
        color: CartBadge.badgeColour,
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
