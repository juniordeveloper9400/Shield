import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../auth/auth_flow.dart';
import '../location/address_book.dart';
import '../location/address_form_screen.dart';
import 'prescription_cart_service.dart';
import 'prescription_checkout_screen.dart';

/// The prescription basket: whole prescriptions waiting on the counter.
///
/// Laid out like the product cart — a count strip, white bordered cards, an
/// "add another" row and a delivery-address section — so a member who has
/// filled one basket already knows this one. One row per prescription, led by
/// its number; the medicines on it are a count rather than a list, since what
/// is being confirmed here is which papers to fill. See
/// [PrescriptionCartService] for why this is its own basket.
class PrescriptionCartScreen extends StatelessWidget {
  const PrescriptionCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
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

          final count = cart.orders.length;

          return ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Text(
                  '$count ${count == 1 ? 'Prescription' : 'Prescriptions'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < count; index++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _OrderCard(index: index, order: cart.orders[index]),
                ),
              _AddMoreRow(onTap: () => Navigator.of(context).maybePop()),
              Container(
                color: AppColors.pageTint,
                padding: const EdgeInsets.all(16),
                child: const Column(
                  children: [
                    _DeliveryAddressCard(),
                    SizedBox(height: 12),
                    _PricingNote(),
                  ],
                ),
              ),
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
          return const _CheckoutBar();
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

/// One prescription in the basket, in the product cart's two-part card: the
/// number and patient up top with the remove control, the size of the order
/// below a divider.
///
/// The number leads, in a chip, because it is the handle the counter and the
/// member share — everything else on the row describes which prescription that
/// number is.
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
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
                ),
                const SizedBox(width: 6),
                _RemoveButton(
                  key: ValueKey('remove-prescription-${order.number}'),
                  onTap: () =>
                      PrescriptionCartService.instance.removeAt(index),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

/// The delivery-address section, the same one the product checkout carries:
/// "DELIVER TO", the saved address, and a way to add or change it. Setting it
/// here carries straight through to the checkout, which shares
/// [AddressBook.instance].
class _DeliveryAddressCard extends StatelessWidget {
  const _DeliveryAddressCard();

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddressFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AddressBook.instance,
      builder: (context, _) {
        final address = AddressBook.instance.deliverTo;

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
                  const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: AppColors.brandBlue,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'DELIVER TO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  if (address != null)
                    TextButton(
                      onPressed: () => _edit(context),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandBlue,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (address == null)
                OutlinedButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.add_location_alt_outlined, size: 20),
                  label: const Text('Add delivery address'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandBlue,
                    side: const BorderSide(
                      color: AppColors.brandBlue,
                      width: 1.4,
                    ),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${address.label.label} · ${address.receiver}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.summary,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.phone,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The row that sends the member back to add another prescription — the
/// product cart's "Add more medicines" in prescription terms.
class _AddMoreRow extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMoreRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            top: BorderSide(color: AppColors.border),
            bottom: BorderSide(color: AppColors.border),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            Expanded(
              child: Text(
                'Add another prescription',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandBlue,
                ),
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.add_rounded, color: AppColors.brandBlue),
          ],
        ),
      ),
    );
  }
}

/// The circular close control on a card, matching the product cart's.
class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RemoveButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            Icons.close_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
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

/// The checkout bar, the product cart's shape: what the basket holds on the
/// left, the one way forward on the right. No amount, because there is not one
/// yet — the left line says the price comes at the counter instead.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar();

  @override
  Widget build(BuildContext context) {
    final cart = PrescriptionCartService.instance;
    final count = cart.orderCount;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Column(
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
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: () => _proceed(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Proceed to checkout',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
