import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../auth/auth_flow.dart';
import 'prescription_cart_service.dart';
import 'prescription_checkout_screen.dart';

/// The prescription basket: whole prescriptions waiting on the counter.
///
/// One row per prescription, led by its number. The medicines on it are a
/// count rather than a list — what the member is confirming here is which
/// papers they want filled, and the lines behind each are on the prescription
/// card itself. See [PrescriptionCartService] for why this is its own basket.
class PrescriptionCartScreen extends StatelessWidget {
  const PrescriptionCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Prescription orders',
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
      body: ListenableBuilder(
        listenable: PrescriptionCartService.instance,
        builder: (context, _) {
          final cart = PrescriptionCartService.instance;
          if (cart.isEmpty) {
            return const _EmptyState();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              for (var index = 0; index < cart.orders.length; index++) ...[
                _OrderCard(index: index, order: cart.orders[index]),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              const _PricingNote(),
            ],
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: PrescriptionCartService.instance,
        builder: (context, _) {
          if (PrescriptionCartService.instance.isEmpty) {
            return const SizedBox.shrink();
          }
          return const _SendBar();
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 52,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              'No prescriptions to fill',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Send a prescription here once the counter has read it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One prescription in the basket.
///
/// The number leads, in a monospaced-looking chip, because it is the handle
/// the counter and the member share — everything else on the row describes
/// which prescription that number is.
class _OrderCard extends StatelessWidget {
  final int index;
  final PrescriptionOrder order;

  const _OrderCard({required this.index, required this.order});

  @override
  Widget build(BuildContext context) {
    final record = order.record;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.number,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        record.patient.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  _contents(order),
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textBody,
                  ),
                ),
                if (record.doctor.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    record.doctor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: ValueKey('remove-prescription-${order.number}'),
            tooltip: 'Remove ${order.number}',
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
            onPressed: () =>
                PrescriptionCartService.instance.removeAt(index),
          ),
        ],
      ),
    );
  }

  /// "6 medicines · 168 units · 28 days' supply" — the size of the order,
  /// which is what a member checks before sending it.
  static String _contents(PrescriptionOrder order) {
    final medicines = order.medicineCount;
    final parts = <String>[
      '$medicines medicine${medicines == 1 ? '' : 's'}',
      '${order.unitCount} units',
      if (order.record.supplyLabel.isNotEmpty)
        order.record.supplyLabel.split(' · ').last,
    ];
    return parts.join(' · ');
  }
}

/// Why there is no total on this screen.
///
/// The other two baskets carry a bill; this one cannot until the counter has
/// priced what it is dispensing. Saying so is better than an empty space
/// where every other basket has a figure.
class _PricingNote extends StatelessWidget {
  const _PricingNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(13),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: AppColors.brandGreenDeep,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'The pharmacy prices each prescription once it has confirmed '
              'what is being dispensed. You will be shown the bill before '
              'anything is charged.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sends the basket to the counter. No amount on it, because there is not one
/// yet — the button says what happens next instead of what it costs.
class _SendBar extends StatelessWidget {
  const _SendBar();

  @override
  Widget build(BuildContext context) {
    final cart = PrescriptionCartService.instance;
    final count = cart.orderCount;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count prescription${count == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Priced at the counter',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => _proceed(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                child: const Text(
                  'Proceed to checkout',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _proceed(BuildContext context) async {
    // Ordering medicine against a named patient needs a signed-in account,
    // the same guard the other two baskets check out behind.
    await AuthFlow.guard(context, () async {
      if (!context.mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrescriptionCheckoutScreen(
            orders: PrescriptionCartService.instance.orders,
          ),
        ),
      );
    });
  }
}
