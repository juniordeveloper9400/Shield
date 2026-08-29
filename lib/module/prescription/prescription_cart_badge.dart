import 'package:flutter/material.dart';

import '../cart/basket_badge.dart';
import 'prescription_cart_screen.dart';
import 'prescription_cart_service.dart';

/// The prescription basket, shown on the upload screen that fills it.
///
/// Counts papers, not medicines: six lines off one prescription is one thing
/// for the counter to dispense.
class PrescriptionCartBadge extends StatelessWidget {
  const PrescriptionCartBadge({super.key});

  static const Color badgeColour = BasketBadge.badgeColour;

  @override
  Widget build(BuildContext context) {
    return BasketBadge(
      basket: PrescriptionCartService.instance,
      count: () => PrescriptionCartService.instance.orderCount,
      tooltip: (count) => count == 0
          ? 'Prescriptions to fill'
          : 'Prescriptions to fill · $count',
      screen: (_) => const PrescriptionCartScreen(),
    );
  }
}
