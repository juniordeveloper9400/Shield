import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/neon/order_repository.dart';
import '../../dates.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/full_screen_image_view.dart';
import '../auth/auth_service.dart';
import '../checkout/fulfillment_type.dart';
import 'bill_invoice.dart';
import 'invoice_view.dart';
import 'order_detail_sections.dart';
import 'purchase_service.dart';

/// The bill for one order, on its own screen — reachable from the "Bill"
/// button on an order card (My Orders) and from the account-wide Bills list,
/// so both land on the same place rather than each drawing its own copy.
///
/// Two things the store sent, one under the other:
///
///  * the **bill** itself — the picture the admin console attached, when it
///    attached one ([Purchase.billImage], already on the order the moment the
///    list loads); and
///  * the itemised **invoice** — every item with its quantity, price and
///    amount, the date, the store and customer, and the totals. That is read
///    fresh each time the screen opens (`OrderRepository.fetchInvoice`), so a
///    bill the counter has just edited shows its latest items.
///
/// A bill the store priced line by line has no picture, and one that was only
/// a picture has no itemised lines; each shows whichever it has.
class OrderBillScreen extends StatefulWidget {
  final Purchase order;

  /// Test hook: stands in for the database read of the invoice.
  @visibleForTesting
  final Future<BillInvoice?> Function(Purchase order)? invoiceLoader;

  const OrderBillScreen({super.key, required this.order, this.invoiceLoader});

  @override
  State<OrderBillScreen> createState() => _OrderBillScreenState();
}

class _OrderBillScreenState extends State<OrderBillScreen> {
  BillInvoice? _invoice;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    BillInvoice? invoice;
    try {
      final loader = widget.invoiceLoader;
      final phone = AuthService.instance.currentUser.value?.phone;
      if (loader != null) {
        invoice = await loader(widget.order);
      } else if (phone != null) {
        invoice = await OrderRepository.instance.fetchInvoice(
          phone: phone,
          orderCode: widget.order.id,
        );
      }
    } catch (_) {
      // Fall through to the invoice worked out from the order itself.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _invoice = invoice;
      _loading = false;
    });
  }

  /// What the screen prints when the database read gave nothing — offline, or
  /// no `DATABASE_URL`: the totals and dates the order already carries, and no
  /// item table (the invoice says the items were not listed).
  BillInvoice _fallback(Purchase order) {
    final user = AuthService.instance.currentUser.value;
    return BillInvoice.compose(
      number: order.id,
      billedAt: order.billedAt,
      customerName: user?.name ?? '',
      customerPhone: user?.phone ?? '',
      homeDelivery: order.fulfillmentType != FulfillmentType.storePickup,
      orderStatus: switch (order.status) {
        OrderStatus.delivered => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
        _ => 'In progress',
      },
      paid: _isPaid(order),
      billPaise: (order.billAmount ?? 0) * 100,
      paidTotalPaise: order.paidTotal * 100,
    );
  }

  static bool _isPaid(Purchase order) =>
      order.paymentStatus == OrderPaymentStatus.paid ||
      order.billStatus == OrderPaymentStatus.paid;

  Future<void> _share(BillInvoice invoice) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Sahakar 360 invoice ${invoice.number}',
          text: invoice.toShareText(),
        ),
      );
    } on Exception {
      // Platforms without a share sheet (some desktop browsers) throw rather
      // than silently doing nothing.
      messenger.showSnackBar(
        const SnackBar(content: Text('Sharing is not available here')),
      );
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
          'Bill & Invoice',
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
      // Rebuilds when the order is paid from the Pay now sheet below, so the
      // invoice flips to PAID and the button goes away without leaving.
      body: ListenableBuilder(
        listenable: PurchaseService.instance,
        builder: (context, _) {
          final order = PurchaseService.instance.purchases.firstWhere(
            (p) => p.id == widget.order.id,
            orElse: () => widget.order,
          );
          if (!order.hasBill) {
            return const _BillMessage(
              icon: Icons.receipt_long_outlined,
              title: 'No bill yet',
              body:
                  'The store has not created a bill for this order yet. '
                  'Check back once it is on its way.',
            );
          }
          return _buildBill(context, order);
        },
      ),
    );
  }

  Widget _buildBill(BuildContext context, Purchase order) {
    var invoice = _invoice ?? _fallback(order);
    if (_isPaid(order) && !invoice.paid) {
      invoice = invoice.markPaid();
    }
    final image = order.billImage;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (image != null) ...[
          _BillPictureCard(order: order, image: image),
          const SizedBox(height: 14),
        ],
        if (_loading)
          const _InvoiceLoading()
        else ...[
          InvoiceView(invoice: invoice),
          const SizedBox(height: 4),
          Align(
            child: TextButton.icon(
              onPressed: () => _share(invoice),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share invoice'),
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
        PayBillButton(order: order),
      ],
    );
  }
}

/// The picture of the bill the store attached, tappable to full screen.
class _BillPictureCard extends StatelessWidget {
  final Purchase order;
  final String image;

  const _BillPictureCard({required this.order, required this.image});

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            FullScreenImageView(image: image, title: 'Bill · ${order.id}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill from the store',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            order.billedAt != null
                ? 'Sent on ${formatDate(order.billedAt!)}'
                : 'Placed on ${order.placedOn}',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _open(context),
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
                  image: image,
                  fit: BoxFit.contain,
                  fallbackIcon: Icons.receipt_long_rounded,
                  iconSize: 44,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            child: TextButton.icon(
              onPressed: () => _open(context),
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
    );
  }
}

class _InvoiceLoading extends StatelessWidget {
  const _InvoiceLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(height: 10),
          Text(
            'Loading your invoice…',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
