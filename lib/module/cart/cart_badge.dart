import 'package:flutter/material.dart';

import 'basket_badge.dart';
import 'cart_screen.dart';
import 'cart_service.dart';

/// The products basket, shown wherever products can be added to it.
///
/// Units, not distinct products: the medicine cart is the one basket where
/// two of a thing is two things.
class CartBadge extends StatelessWidget {
  const CartBadge({super.key});

  static const Color badgeColour = BasketBadge.badgeColour;

  @override
  Widget build(BuildContext context) {
    return BasketBadge(
      basket: CartService.instance,
      count: () => CartService.instance.itemCount,
      tooltip: (count) => count == 0 ? 'Cart' : 'Cart · $count items',
      screen: (_) => const CartScreen(),
    );
  }
}
