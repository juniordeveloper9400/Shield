import 'package:flutter/material.dart';

import '../../dates.dart';
import '../../money.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/full_screen_image_view.dart';
import 'purchase_service.dart';

/// The bill for one order, on its own screen — reachable from the "Bill"
/// button on an order card (My Orders) and from the account-wide Bills list,
/// so both land on the same place rather than each drawing its own copy.
///
/// Unlike the backend/api build, [Purchase.billImage] here is already on the
/// order the moment the list itself loads (the Neon query joins `app.bill`
/// straight into `listForMember` — see `OrderRepository`'s own doc), so
/// there is nothing to fetch here.
class OrderBillScreen extends StatelessWidget {
  final Purchase order;

  const OrderBillScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Bill',
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
      body: !order.hasBill
          ? const _BillMessage(
              icon: Icons.receipt_long_outlined,
              title: 'No bill yet',
              body:
                  'The store has not created a bill for this order yet. '
                  'Check back once it is on its way.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.id,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order.billedAt != null
                            ? 'Billed on ${formatDate(order.billedAt!)}'
                            : 'Placed on ${order.placedOn}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (order.billAmount != null) ...[
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text(
                              'Amount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '₹${formatRupees(order.billAmount!)}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FullScreenImageView(
                              image: order.billImage!,
                              title: 'Bill · ${order.id}',
                            ),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            height: 320,
                            decoration: BoxDecoration(
                              color: AppColors.pageTint,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: AppImage(
                              image: order.billImage!,
                              fit: BoxFit.contain,
                              fallbackIcon: Icons.receipt_long_rounded,
                              iconSize: 44,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageView(
                                image: order.billImage!,
                                title: 'Bill · ${order.id}',
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.fullscreen_rounded, size: 18),
                          label: const Text('View full screen'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.brandBlue,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _BillMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _BillMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
