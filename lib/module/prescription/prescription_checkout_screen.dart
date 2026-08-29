import 'package:flutter/material.dart';

import '../../dates.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_flow.dart';
import '../checkout/checkout_chrome.dart';
import '../checkout/payment_method.dart';
import '../location/address_book.dart';
import '../location/address_form_screen.dart';
import '../orders/purchase_service.dart';
import 'prescription_cart_service.dart';
import 'prescription_order_placed_screen.dart';

/// Checkout for the prescription basket.
///
/// A prescription is priced at the counter, so there is no bill to settle
/// here — what this screen collects is the delivery address and how the member
/// will pay once the pharmacist has confirmed the price. **Place order** files
/// it into My Orders as a processing order and empties the basket.
class PrescriptionCheckoutScreen extends StatefulWidget {
  final List<PrescriptionOrder> orders;

  const PrescriptionCheckoutScreen({super.key, required this.orders});

  @override
  State<PrescriptionCheckoutScreen> createState() =>
      _PrescriptionCheckoutScreenState();
}

class _PrescriptionCheckoutScreenState
    extends State<PrescriptionCheckoutScreen> {
  PaymentMethod _method = PaymentMethods.bankTransfer;
  bool _placing = false;

  int get _medicineCount =>
      widget.orders.fold(0, (sum, order) => sum + order.medicineCount);

  int get _unitCount =>
      widget.orders.fold(0, (sum, order) => sum + order.unitCount);

  void _chooseMethod(PaymentMethod method) {
    if (!method.isLive) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(method.comingSoonNote)));
      return;
    }
    setState(() => _method = method);
  }

  Future<void> _placeOrder() async {
    if (_placing) {
      return;
    }
    // The delivery address is the one thing this screen exists to collect, so
    // there is no order to place without it.
    if (AddressBook.instance.deliverTo == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Add a delivery address to place the order.'),
          ),
        );
      return;
    }
    setState(() => _placing = true);

    await AuthFlow.guard(context, () async {
      final id = 'SHD-${100500 + PurchaseService.instance.purchases.length}';
      final purchase = PurchaseService.instance.record(
        id: id,
        placedOn: formatDate(DateTime.now()),
        // Medicines across every prescription, so the order line reads as
        // something rather than "0 items"; falls back to the paper count.
        itemCount: _medicineCount == 0 ? widget.orders.length : _medicineCount,
        // Priced at the counter — nothing is owed yet, and a made-up figure
        // here would flow straight into the earnings total.
        mrpTotal: 0,
        paidTotal: 0,
        status: OrderStatus.processing,
        kind: OrderKind.prescription,
      );
      PrescriptionCartService.instance.clear();

      if (!mounted) {
        return;
      }
      // Replaces the checkout: it is done, and the confirmation is where the
      // member decides whether to track the order or head back to the shop.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PrescriptionOrderPlacedScreen(order: purchase),
        ),
      );
    });

    if (mounted) {
      setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Checkout',
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _SummaryCard(
            orders: widget.orders,
            medicineCount: _medicineCount,
            unitCount: _unitCount,
          ),
          const SizedBox(height: 14),
          const _DeliveryCard(),
          const SizedBox(height: 14),
          _PaymentCard(selected: _method, onSelect: _chooseMethod),
        ],
      ),
      // Rebuilds with the address book so the bar unlocks the moment a
      // delivery address is saved on the form above.
      bottomNavigationBar: ListenableBuilder(
        listenable: AddressBook.instance,
        builder: (context, _) => _PlaceOrderBar(
          busy: _placing,
          hasAddress: AddressBook.instance.deliverTo != null,
          onPressed: _placeOrder,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<PrescriptionOrder> orders;
  final int medicineCount;
  final int unitCount;

  const _SummaryCard({
    required this.orders,
    required this.medicineCount,
    required this.unitCount,
  });

  @override
  Widget build(BuildContext context) {
    final n = orders.length;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$n prescription${n == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          if (medicineCount > 0) ...[
            const SizedBox(height: 3),
            Text(
              '$medicineCount medicine${medicineCount == 1 ? '' : 's'} · '
              '$unitCount units',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          for (final order in orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
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
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.record.patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 14, color: AppColors.border),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.brandGreenDeep,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Priced at the counter once the pharmacist confirms what is '
                  'dispensed. You will see the bill before paying.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard();

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

        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 20,
                    color: AppColors.brandBlue,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Delivery address',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
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
                          fontSize: 14,
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
                Text(
                  '${address.receiver}\n${address.summary}\n${address.phone}',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textBody,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onSelect;

  const _PaymentCard({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment method',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Charged only after the pharmacy confirms the price.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          for (final method in PaymentMethods.all) ...[
            _MethodTile(
              method: method,
              selected: method.id == selected.id,
              onTap: () => onSelect(method),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? method.tint : AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? method.accent : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: method.tint,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(method.icon, size: 20, color: method.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      method.blurb,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!method.isLive) const ComingSoonPill(),
              if (method.isLive)
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? method.accent : AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The foot of the checkout: no amount, because nothing is owed until the
/// counter has priced it — just the one way forward.
class _PlaceOrderBar extends StatelessWidget {
  final bool busy;
  final bool hasAddress;
  final VoidCallback onPressed;

  const _PlaceOrderBar({
    required this.busy,
    required this.hasAddress,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasAddress
                      ? 'Priced at the counter'
                      : 'Add a delivery address first',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: hasAddress
                        ? FontWeight.w400
                        : FontWeight.w600,
                    color: hasAddress
                        ? AppColors.textMuted
                        : AppColors.danger,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: (busy || !hasAddress) ? null : onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text(
                          'Place order',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
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
}
