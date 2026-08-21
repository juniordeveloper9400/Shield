import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Order history reached from the Orders tab.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  static const List<_Order> _orders = [
    _Order(
      id: 'SHD-100482',
      placedOn: '16 Aug 2026',
      itemCount: 4,
      total: '₹1,248',
      status: _OrderStatus.delivered,
    ),
    _Order(
      id: 'SHD-100461',
      placedOn: '12 Aug 2026',
      itemCount: 2,
      total: '₹640',
      status: _OrderStatus.outForDelivery,
    ),
    _Order(
      id: 'SHD-100433',
      placedOn: '04 Aug 2026',
      itemCount: 7,
      total: '₹2,115',
      status: _OrderStatus.processing,
    ),
    _Order(
      id: 'SHD-100398',
      placedOn: '27 Jul 2026',
      itemCount: 1,
      total: '₹289',
      status: _OrderStatus.cancelled,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _OrderCard(order: _orders[index]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final _Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.id,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Placed on ${order.placedOn}  ·  ${order.itemCount} item'
            '${order.itemCount == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                order.total,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandBlue,
                  side: const BorderSide(color: AppColors.brandBlue),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View details',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _OrderStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: status.foreground,
        ),
      ),
    );
  }
}

enum _OrderStatus {
  delivered('Delivered', AppColors.greenTint, AppColors.brandGreenDark),
  outForDelivery('Out for delivery', AppColors.offerTint, AppColors.brandBlue),
  processing('Processing', Color(0xFFFDF3E0), Color(0xFFB4761A)),
  cancelled('Cancelled', Color(0xFFFBEBEB), Color(0xFFB4322F));

  final String label;
  final Color background;
  final Color foreground;

  const _OrderStatus(this.label, this.background, this.foreground);
}

class _Order {
  final String id;
  final String placedOn;
  final int itemCount;
  final String total;
  final _OrderStatus status;

  const _Order({
    required this.id,
    required this.placedOn,
    required this.itemCount,
    required this.total,
    required this.status,
  });
}
