import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'order_track_screen.dart';
import 'purchase_service.dart';

/// The "your order is in" screen, shown once a checkout has filed an order.
///
/// It replaces the checkout in the stack rather than sitting on top of it —
/// the checkout is finished, and a back gesture from here should land on the
/// (now empty) cart, not on a payment form for an order already placed. From
/// here a member either tracks the order or heads back to the shop.
class OrderPlacedScreen extends StatelessWidget {
  final Purchase order;

  const OrderPlacedScreen({super.key, required this.order});

  String get _body => switch (order.kind) {
    OrderKind.prescription =>
      'The pharmacist reads your prescription, prices it, and messages you '
          'before anything is charged.',
    OrderKind.standard =>
      'We are getting your order ready. Track it any time from My Orders.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              const Spacer(),
              const _SuccessTick(),
              const SizedBox(height: 24),
              const Text(
                'Order placed',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order ${order.id}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => OrderTrackScreen(order: order),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.local_shipping_outlined, size: 20),
                  label: const Text(
                    'Track order',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text(
                  'Back to home',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBody,
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

/// The green disc and tick, popped in with a short scale so the screen reads
/// as a confirmation the moment it lands.
class _SuccessTick extends StatelessWidget {
  const _SuccessTick();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: AppColors.greenTint,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.brandGreen, width: 2),
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 46,
          color: AppColors.brandGreenDeep,
        ),
      ),
    );
  }
}
