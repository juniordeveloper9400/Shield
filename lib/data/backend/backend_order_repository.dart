import '../../dates.dart';
import '../../module/checkout/fulfillment_type.dart';
import '../../module/orders/bill_invoice.dart';
import '../../module/orders/purchase_service.dart';
import '../neon/order_repository.dart' show OrderItem, OrderPrescription;
import 'backend_http.dart';

/// One order's `app.bill` row, as [BackendOrderRepository.fetchBill] reads
/// it back — the itemised invoice [order_bill_screen.dart] shows under
/// "Invoice". [Purchase.billImage]/[Purchase.billedAt] already carry the
/// picture and send date (read eagerly, alongside every other order, by
/// [listForMember] — see that method's own doc); this is the rest:
/// customer, store, delivery address, totals and lines.
class OrderBillDetail {
  final BillInvoice? invoice;

  const OrderBillDetail({required this.invoice});
}

/// Reads placed orders through `backend/api`'s `/v1/member/orders` routes
/// (see `order.service.ts`), never a direct Neon connection.
///
/// Read-only for now: [OrderRepository] (the direct-Neon class this
/// doesn't replace yet) still files standard-order checkouts,
/// prescription-order checkouts, lab bookings, and the member-triggered
/// wallet-pay write — see that class's own doc for why each stays there.
/// Every order this reads back is the exact same `app."order"` row
/// regardless of which path wrote it: there is one production database
/// behind both, so this is safe to migrate on its own, write paths and
/// all.
///
/// Best-effort, the same contract as every other backend repository: an
/// unconfigured backend or the network down returns `null`/`[]` rather
/// than throwing, so a transient failure never looks like "no orders at
/// all" — [PurchaseService] keeps whatever it already has.
class BackendOrderRepository {
  const BackendOrderRepository._();

  static const BackendOrderRepository instance = BackendOrderRepository._();

  bool get isAvailable => BackendHttp.isConfigured;

  /// Every order the member has placed, newest first.
  ///
  /// Returns `null` (not an empty list) when the backend is off or
  /// unreachable, so [PurchaseService.ensureLoaded] can tell "this member
  /// has no orders yet" from "could not load them" and leave whatever is
  /// already on screen alone rather than blanking it on a network blip.
  Future<List<Purchase>?> listForMember() async {
    if (!BackendHttp.isConfigured) {
      return null;
    }
    try {
      final rows = await BackendHttp.instance.request('GET', '/v1/member/orders')
          as List<dynamic>;
      return rows.cast<Map<String, dynamic>>().map(_toPurchase).toList(growable: false);
    } catch (error) {
      BackendHttp.log('BackendOrderRepository.listForMember failed', error: error);
      return null;
    }
  }

  /// The store's itemised invoice for one of the member's own orders —
  /// `GET /v1/member/orders/:id/bill` (`OrderService.getBillForMember`).
  ///
  /// [backendId] is [Purchase.backendId], not the printed code. Returns
  /// `null` when the backend is off, unreachable, the order is not this
  /// member's, or (a 404) no bill has been sent for it yet — the screen
  /// then prints what the order already carries from [listForMember].
  Future<OrderBillDetail?> fetchBill(int backendId) async {
    if (!BackendHttp.isConfigured) {
      return null;
    }
    try {
      final body = await BackendHttp.instance.request('GET', '/v1/member/orders/$backendId/bill')
          as Map<String, dynamic>;
      return OrderBillDetail(invoice: _invoiceFromBill(body));
    } on BackendHttpException catch (error) {
      // 404 — "no bill sent for this order yet" — the ordinary case for
      // most orders, not a failure to log.
      if (error.isNotFound) return null;
      BackendHttp.log('BackendOrderRepository.fetchBill failed', error: error);
      return null;
    } catch (error) {
      BackendHttp.log('BackendOrderRepository.fetchBill failed', error: error);
      return null;
    }
  }

  static BillInvoice _invoiceFromBill(Map<String, dynamic> body) {
    String text(Map<String, dynamic>? map, String key) =>
        (map?[key] ?? '').toString().trim();
    String joined(Map<String, dynamic>? map, List<String> keys) =>
        keys.map((key) => text(map, key)).where((p) => p.isNotEmpty).join(', ');
    Map<String, dynamic>? asMap(Object? value) =>
        value is Map<String, dynamic> ? value : null;

    final invoiceBlock = asMap(body['invoice']);
    final customer = asMap(invoiceBlock?['customer']);
    final store = asMap(invoiceBlock?['store']);
    final address = asMap(invoiceBlock?['deliveryAddress']);
    final orderStatus = text(invoiceBlock, 'status');
    final sentAt = DateTime.tryParse(text(body, 'sentAt'));

    return BillInvoice.compose(
      number: text(invoiceBlock, 'number'),
      billedAt: sentAt,
      placedAt: DateTime.tryParse(text(invoiceBlock, 'placedAt')),
      customerName: text(customer, 'name'),
      customerPhone: text(customer, 'phone'),
      storeName: text(store, 'name'),
      storeAddress: joined(store, ['area', 'city', 'state', 'pincode']),
      storePhone: text(store, 'phone'),
      homeDelivery: text(invoiceBlock, 'fulfillmentType') != 'STORE_PICKUP',
      deliveryAddress: joined(address, [
        'house',
        'area',
        'landmark',
        'city',
        'state',
        'pincode',
      ]),
      orderStatus: orderStatus == 'DELIVERED'
          ? 'Completed'
          : orderStatus == 'CANCELLED'
              ? 'Cancelled'
              : 'In progress',
      paid: text(invoiceBlock, 'paymentStatus') == 'PAID' || text(body, 'status') == 'PAID',
      paidAt: DateTime.tryParse(text(body, 'paidAt')) ??
          DateTime.tryParse(text(invoiceBlock, 'paidAt')),
      lines: [
        for (final line in (invoiceBlock?['lines'] as List<dynamic>? ?? const []))
          if (line is Map<String, dynamic>)
            InvoiceLine(
              name: text(line, 'name'),
              pack: text(line, 'pack'),
              qty: int.tryParse(text(line, 'qty')) ?? 1,
              unitPaise: paiseFrom(line['unitPrice']),
            ),
      ],
      billPaise: paiseFrom(body['amount']),
      paidTotalPaise: paiseFrom(invoiceBlock?['paidTotal']),
      deliveryFeePaise: paiseFrom(invoiceBlock?['deliveryFee']),
    );
  }

  /// The prescription(s) submitted into this order — `GET /v1/member/
  /// orders/:id/prescriptions` (`OrderService.getPrescriptionsForOrder`).
  /// Empty for a standard order, which never has one; null when the
  /// backend is unreachable. [backendId] is [Purchase.backendId].
  Future<List<OrderPrescription>?> fetchPrescriptions(int backendId) async {
    if (!BackendHttp.isConfigured) {
      return null;
    }
    try {
      final rows = await BackendHttp.instance
          .request('GET', '/v1/member/orders/$backendId/prescriptions') as List<dynamic>;
      return rows.cast<Map<String, dynamic>>().map((row) {
        final image = (row['image'] as String?)?.trim();
        return OrderPrescription(
          code: (row['code'] ?? '').toString(),
          image: image == null || image.isEmpty ? null : image,
          doctor: (row['doctor'] ?? '').toString(),
          status: (row['status'] ?? '').toString().toUpperCase(),
        );
      }).toList(growable: false);
    } catch (error) {
      BackendHttp.log('BackendOrderRepository.fetchPrescriptions failed', error: error);
      return null;
    }
  }

  /// This order's own line items with a real product picture against each
  /// one — `GET /v1/member/orders/:id/items` (`OrderService.
  /// getItemsForOrder`). Empty for a prescription order, which never has
  /// `order_line` rows at all; null when the backend is unreachable.
  /// [backendId] is [Purchase.backendId].
  Future<List<OrderItem>?> fetchItems(int backendId) async {
    if (!BackendHttp.isConfigured) {
      return null;
    }
    try {
      final rows = await BackendHttp.instance.request('GET', '/v1/member/orders/$backendId/items')
          as List<dynamic>;
      return rows.cast<Map<String, dynamic>>().map((row) {
        int i(Object? v) => v is int ? v : (double.tryParse((v ?? '').toString())?.round() ?? 0);
        final image = (row['image'] as String?)?.trim();
        return OrderItem(
          name: (row['name'] ?? '').toString(),
          pack: (row['pack'] ?? '').toString(),
          qty: i(row['qty']),
          unitPrice: i(row['unitPrice']),
          mrp: i(row['mrp']),
          image: image == null || image.isEmpty ? null : image,
        );
      }).toList(growable: false);
    } catch (error) {
      BackendHttp.log('BackendOrderRepository.fetchItems failed', error: error);
      return null;
    }
  }

  /// One `GET /v1/member/orders` row → a [Purchase]. The backend's own
  /// JSON (camelCase, numbers typed) rather than Neon's text-only SQL rows.
  static Purchase _toPurchase(Map<String, dynamic> row) {
    final placedAt =
        DateTime.tryParse((row['placedAt'] ?? '').toString()) ?? DateTime.now();
    final billImage = (row['billImage'] as String?)?.trim();
    return Purchase(
      id: (row['code'] ?? '').toString(),
      backendId: (row['id'] as num?)?.toInt(),
      placedOn: formatDateTime12h(placedAt),
      itemCount: (row['itemCount'] as num?)?.toInt() ?? 0,
      mrpTotal: double.tryParse((row['mrpTotal'] ?? '').toString())?.round() ?? 0,
      paidTotal: double.tryParse((row['paidTotal'] ?? '').toString())?.round() ?? 0,
      status: _statusFrom(row['status']?.toString()),
      kind: row['kind']?.toString() == 'PRESCRIPTION'
          ? OrderKind.prescription
          : OrderKind.standard,
      fulfillmentType: row['fulfillmentType']?.toString() == 'STORE_PICKUP'
          ? FulfillmentType.storePickup
          : FulfillmentType.homeDelivery,
      paymentStatus: row['paymentStatus']?.toString() == 'PAID'
          ? OrderPaymentStatus.paid
          : OrderPaymentStatus.pending,
      billImage: billImage == null || billImage.isEmpty ? null : billImage,
      billedAt: DateTime.tryParse((row['billedAt'] ?? '').toString()),
      billAmount: row['billAmount'] == null
          ? null
          : double.tryParse(row['billAmount'].toString())?.round(),
      billStatus: row['billStatus'] == null
          ? null
          : (row['billStatus'].toString() == 'PAID'
              ? OrderPaymentStatus.paid
              : OrderPaymentStatus.pending),
      billDiscount:
          double.tryParse((row['billDiscount'] ?? '').toString())?.round() ?? 0,
      storeContactedAt: DateTime.tryParse((row['storeContactedAt'] ?? '').toString()),
      reviewedAt: DateTime.tryParse((row['reviewedAt'] ?? '').toString()),
      convertedToBillAt: DateTime.tryParse((row['convertedToBillAt'] ?? '').toString()),
    );
  }

  static OrderStatus _statusFrom(String? label) => switch (label) {
        'OUT_FOR_DELIVERY' => OrderStatus.outForDelivery,
        'DELIVERED' => OrderStatus.delivered,
        'CANCELLED' => OrderStatus.cancelled,
        _ => OrderStatus.processing,
      };
}
