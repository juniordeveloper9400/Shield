import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../dates.dart';
import '../../module/cart/cart_service.dart';
import '../../module/checkout/checkout_order.dart' show CheckoutFailedException;
import '../../module/checkout/fulfillment_type.dart';
import '../../module/labtest/lab_fulfillment_type.dart';
import '../../module/location/address_book.dart';
import '../../module/orders/bill_invoice.dart';
import '../../module/orders/purchase_service.dart';
import 'backend_address_repository.dart';
import 'backend_http.dart';
import 'care_repository.dart';

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

/// One lab package booked for a number of patients, as
/// [BackendOrderRepository.saveLabBookings] sends it. The package fields
/// are carried so a package the app knows but the backend has never seen
/// can still be matched by name against a fresh catalogue read.
@immutable
class LabBookingInput {
  final String name;
  final int testCount;
  final int profileCount;
  final String rating;
  final String booked;
  final String reportIn;
  final int unitPrice;
  final int mrp;
  final int patients;
  final String forWhom;
  final String ageRange;
  final String preparation;
  final String sample;
  final String about;

  const LabBookingInput({
    required this.name,
    this.testCount = 0,
    this.profileCount = 0,
    this.rating = '',
    this.booked = '',
    this.reportIn = '',
    required this.unitPrice,
    required this.mrp,
    required this.patients,
    this.forWhom = '',
    this.ageRange = '',
    this.preparation = '',
    this.sample = '',
    this.about = '',
  });
}

/// One line item on a standard order, as
/// [BackendOrderRepository.fetchItems] reads it back — enough for "Items in
/// this order" to show the real product picture rather than naming it with
/// no picture at all.
@immutable
class OrderItem {
  final String name;
  final String pack;
  final int qty;
  final int unitPrice;
  final int mrp;

  /// The product's own catalogue picture (a `data:` URI), or null when the
  /// line carries no product or the product has since lost its picture.
  final String? image;

  const OrderItem({
    required this.name,
    required this.pack,
    required this.qty,
    required this.unitPrice,
    required this.mrp,
    required this.image,
  });
}

/// One prescription submitted into an order, as
/// [BackendOrderRepository.fetchPrescriptions] reads it back — just enough
/// for [PrescriptionUploadedCard] to show the member's own uploaded scan
/// rather than a generic icon standing in for it.
@immutable
class OrderPrescription {
  final String code;

  /// The first page of the member's own uploaded scan (a `data:` URI), or
  /// null when this prescription was submitted with no photo — a script
  /// phoned in, not an error case.
  final String? image;
  final String doctor;

  /// An `app.prescription_status` value — `AWAITING_REVIEW` / `READ` /
  /// `ORDERED`.
  final String status;

  const OrderPrescription({
    required this.code,
    required this.image,
    required this.doctor,
    required this.status,
  });
}

/// Reads and places standard-order checkouts and lab bookings through
/// `backend/api`'s `/v1/member/{cart,orders,lab-bookings}` routes (see
/// `cart.service.ts`/`order.service.ts`/`booking.service.ts`), never a
/// direct Neon connection.
///
/// [OrderRepository] (the direct-Neon class this doesn't fully replace) still
/// files prescription-order checkouts — there is no backend route for that
/// at all yet; see that class's own doc. [listForMember]/[fetchBill]/
/// [fetchPrescriptions]/[fetchItems] read the exact same `app."order"` rows
/// regardless of which path wrote them — there is one production database
/// behind both — so reading through this class was always safe
/// independently of [checkoutStandardOrder]/[saveLabBookings] existing.
///
/// Checkout here is fundamentally different in shape from the old direct-
/// Neon version: the backend has its own server-side cart, priced from live
/// product rows, and computes every total itself — a client-submitted
/// amount is never trusted. [checkoutStandardOrder] bridges the app's
/// in-memory `CartService` (still the UI's source of truth) to that
/// server-side cart at the moment of checkout: sync the lines across, then
/// check out. The backend's own transaction also awards reward points and
/// advances a referral when the order is paid — `PurchaseService.record`
/// deliberately does neither any more, to avoid double-crediting once this
/// exists.
///
/// Best-effort, the same contract as every other backend repository, with
/// one deliberate exception: an unconfigured backend returns `null`/`[]`
/// rather than throwing (there is nothing to read or write through to, by
/// design), but a *configured* backend that fails [checkoutStandardOrder]
/// throws rather than swallowing it — that write must never fail silently,
/// since it would show "Order placed" for a purchase the admin console
/// never sees; see that method's own doc.
class BackendOrderRepository {
  BackendOrderRepository._();

  static final BackendOrderRepository instance = BackendOrderRepository._();

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

  /// `code` (`'wallet'`/`'cash'`) → the backend's numeric `payment_method.id`
  /// — resolved once against the public catalogue and cached, the same
  /// pattern `WalletService`'s own tier-id lookups use. The checkout DTO
  /// only accepts the numeric id; the app only knows methods by their
  /// [PaymentMethod.id] code.
  Map<String, int>? _paymentMethodIdCache;

  Future<int?> _paymentMethodIdFor(String code) async {
    final cached = _paymentMethodIdCache;
    if (cached != null) {
      return cached[code];
    }
    try {
      final rows = await BackendHttp.instance.request(
        'GET',
        '/v1/public/catalogue/payment-methods',
        auth: false,
      ) as List<dynamic>;
      final map = <String, int>{};
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final rowCode = row['code']?.toString();
        final id = row['id'];
        if (rowCode != null && id != null) {
          map[rowCode] = (id as num).toInt();
        }
      }
      _paymentMethodIdCache = map;
      return map[code];
    } catch (error) {
      BackendHttp.log('BackendOrderRepository._paymentMethodIdFor failed', error: error);
      return null;
    }
  }

  /// Syncs [lines] into the backend's own cart (clearing anything stale left
  /// over from an earlier abandoned session first — a client-side cart
  /// reload must never leak into a fresh checkout), resolves [address] to a
  /// real `deliveryAddressId` (creating it fresh when it has never been
  /// written through — see [Address.remoteId]'s own doc), checks out with a
  /// fresh `Idempotency-Key`, and files [receiptPayerName]/[receiptReference]/
  /// [receiptAmount]/[receiptFileName]/[receiptImage] as the manual-transfer
  /// claim against the order it just placed.
  ///
  /// A line with no resolvable [CartLine.productId] (a stale add, or a
  /// catalogue read that never carried an id through) is skipped rather
  /// than failing the whole checkout — the same "never block the order"
  /// philosophy as every other best-effort write here.
  ///
  /// Unconfigured (a test build, or one with no `BACKEND_API_BASE_URL` —
  /// nothing to write through to, by design) returns `null`, same as every
  /// other method here — there is simply nothing to check out against. A
  /// *configured* backend that fails the checkout is different: that is a
  /// real order a member was about to be told was placed, so this throws
  /// [CheckoutFailedException] instead, letting the checkout screen keep
  /// them on the payment form rather than moving on to a "success" screen
  /// for an order that was never placed — see that exception's own doc.
  ///
  /// [fulfillmentType] is how the order reaches the member.
  /// [paymentMethodCode] is `'wallet'` (settles the order instantly — the
  /// backend debits the balance and marks it PAID in the same transaction
  /// as the order itself, see `order.service.ts`'s `checkout`) or `'cash'`
  /// (leaves it PENDING until it is collected in person).
  ///
  /// Returns the placed order, mapped the same way [listForMember]'s own
  /// rows are.
  Future<Purchase?> checkoutStandardOrder({
    required List<CartLine> lines,
    Address? address,
    String? reference,
    FulfillmentType fulfillmentType = FulfillmentType.homeDelivery,
    required String paymentMethodCode,
    String? receiptPayerName,
    String? receiptReference,
    double? receiptAmount,
    String? receiptFileName,
    String? receiptImage,
  }) async {
    if (!BackendHttp.isConfigured) {
      return null;
    }
    if (lines.isEmpty) {
      throw const CheckoutFailedException('Your cart is empty.');
    }
    try {
      // 1 · Clear any stale server-side lines from an earlier session.
      final existingCart = await BackendHttp.instance.request('GET', '/v1/member/cart')
          as Map<String, dynamic>;
      for (final line in (existingCart['lines'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        await BackendHttp.instance.request('DELETE', '/v1/member/cart/lines/${line['id']}');
      }

      // 2 · Add the current in-memory lines.
      var addedAny = false;
      for (final line in lines) {
        final productId = line.productId;
        if (productId == null) {
          BackendHttp.log(
            'BackendOrderRepository.checkoutStandardOrder: "${line.name}" has no product id — skipped',
          );
          continue;
        }
        await BackendHttp.instance.request(
          'POST',
          '/v1/member/cart/lines',
          body: {'productId': productId, 'qty': line.qty},
        );
        addedAny = true;
      }
      if (!addedAny) {
        throw const CheckoutFailedException(
          'Could not place your order — none of your items could be matched '
          'to the catalogue. Remove and re-add them, then try again.',
        );
      }

      // 3 · A real deliveryAddressId — the one already on file, or a fresh
      // write when this address has never been synced.
      final addressId = address == null
          ? null
          : int.tryParse(address.remoteId ?? '') ??
              int.tryParse(
                await BackendAddressRepository.instance.upsert(
                      label: address.label.name.toUpperCase(),
                      house: address.house,
                      area: address.area,
                      landmark: address.landmark,
                      pincode: address.pincode,
                      firstName: address.firstName,
                      lastName: address.lastName,
                      phone: address.phone,
                      patientId: address.patientId,
                    ) ??
                    '',
              );

      // 3b · The chosen payment method's numeric id.
      final paymentMethodId = await _paymentMethodIdFor(paymentMethodCode);

      // 4 · Checkout — totals are computed server-side from the lines just synced.
      final createdOrder = await BackendHttp.instance.request(
        'POST',
        '/v1/member/orders',
        body: {
          if (addressId != null) 'deliveryAddressId': addressId,
          if (reference != null) 'reference': reference,
          if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
          'fulfillmentType': fulfillmentType == FulfillmentType.storePickup
              ? 'STORE_PICKUP'
              : 'HOME_DELIVERY',
        },
        headers: {'Idempotency-Key': _newIdempotencyKey()},
      ) as Map<String, dynamic>;

      // 5 · The manual-transfer claim, against the order just placed — only
      // when there is one to file (a wallet or cash order never uploads a
      // receipt — see checkout_screen.dart's `_submitDelivering`).
      final hasReceipt =
          receiptPayerName != null ||
          receiptReference != null ||
          receiptAmount != null ||
          (receiptFileName != null && receiptFileName.isNotEmpty);
      if (hasReceipt) {
        try {
          await BackendHttp.instance.request(
            'POST',
            '/v1/member/orders/${createdOrder['id']}/receipt',
            body: {
              if (receiptPayerName != null) 'payerName': receiptPayerName,
              if (receiptReference != null) 'reference': receiptReference,
              if (receiptAmount != null) 'amount': receiptAmount,
              if (receiptFileName != null) 'fileName': receiptFileName,
              if (receiptImage != null) 'image': receiptImage,
            },
          );
        } catch (error) {
          // The order itself is real even if the receipt claim failed to
          // attach — never unwind a placed order over this.
          BackendHttp.log(
            'BackendOrderRepository: receipt claim failed for order ${createdOrder['id']}',
            error: error,
          );
        }
      }

      return _toPurchase(createdOrder);
    } on CheckoutFailedException {
      rethrow;
    } catch (error) {
      BackendHttp.log('BackendOrderRepository.checkoutStandardOrder failed', error: error);
      throw const CheckoutFailedException(
        'Could not place your order — check your connection and try again.',
      );
    }
  }

  /// Submits one or more already-uploaded prescriptions for fulfilment —
  /// `POST /v1/member/prescription-orders` (`PrescriptionService.
  /// submitForOrder`). An unpriced order shell the pharmacist prices at the
  /// counter, mirroring the old direct-Neon `OrderRepository.
  /// savePrescriptionOrder` + `PrescriptionRepository.markOrdered` exactly:
  /// the backend moves each prescription's own status to `ORDERED` in the
  /// same transaction as the order, so there is nothing left to do
  /// afterwards — no pricing or payment logic here either way, a
  /// prescription is priced at the counter first.
  ///
  /// [prescriptionIds] are the backend's numeric prescription ids — the
  /// same value `PrescriptionRepository.insertUpload` returned, carried on
  /// `PrescriptionRecord.remoteId`. [address] resolves to a real
  /// `addressId` the same way [checkoutStandardOrder] resolves one: the one
  /// already on file, or a fresh write when it has never been synced.
  ///
  /// A *configured* backend that fails this throws
  /// [CheckoutFailedException], same as [checkoutStandardOrder] and for the
  /// same reason: a prescription order placed on this device but never
  /// written is a script the pharmacist never sees. An *unconfigured*
  /// backend (a test build) returns null instead.
  Future<Purchase?> submitPrescriptionOrder({
    required List<int> prescriptionIds,
    Address? address,
    FulfillmentType fulfillmentType = FulfillmentType.homeDelivery,
  }) async {
    if (!BackendHttp.isConfigured) {
      return null;
    }
    if (prescriptionIds.isEmpty) {
      throw const CheckoutFailedException('Nothing here to submit.');
    }
    try {
      final addressId = address == null
          ? null
          : int.tryParse(address.remoteId ?? '') ??
              int.tryParse(
                await BackendAddressRepository.instance.upsert(
                      label: address.label.name.toUpperCase(),
                      house: address.house,
                      area: address.area,
                      landmark: address.landmark,
                      pincode: address.pincode,
                      firstName: address.firstName,
                      lastName: address.lastName,
                      phone: address.phone,
                      patientId: address.patientId,
                    ) ??
                    '',
              );

      final createdOrder = await BackendHttp.instance.request(
        'POST',
        '/v1/member/prescription-orders',
        body: {
          'prescriptionIds': prescriptionIds,
          if (addressId != null) 'addressId': addressId,
          'fulfillmentType': fulfillmentType == FulfillmentType.storePickup
              ? 'STORE_PICKUP'
              : 'HOME_DELIVERY',
        },
      ) as Map<String, dynamic>;

      return _toPurchase(createdOrder);
    } on CheckoutFailedException {
      rethrow;
    } catch (error) {
      BackendHttp.log('BackendOrderRepository.submitPrescriptionOrder failed', error: error);
      throw const CheckoutFailedException(
        'Could not place your order — check your connection and try again.',
      );
    }
  }

  /// A fresh random v4-shaped UUID for one checkout attempt. See
  /// `RewardsRepository`'s identical helper for why this must be
  /// high-entropy rather than derived from a timestamp.
  static String _newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int start, int end) =>
        bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// `code` (a `ShieldStore.id`) → the backend's numeric `shield_store.id`
  /// — resolved once against `/v1/public/care/lab-stores` and cached, the
  /// same pattern [_paymentMethodIdFor] uses. Only branches open for lab
  /// collection are in that list, so a branch that doesn't offer it (or
  /// one this app's bundled `ShieldStore` directory names but the backend
  /// doesn't recognise) simply resolves to null — [saveLabBookings] then
  /// omits `storeId` and the backend falls back to the member's own home
  /// branch, same as root's direct-Neon write already did.
  Map<String, int>? _labStoreIdCache;

  Future<int?> _labStoreIdFor(String code) async {
    final cached = _labStoreIdCache;
    if (cached != null) {
      return cached[code];
    }
    try {
      final rows = await BackendHttp.instance.request(
        'GET',
        '/v1/public/care/lab-stores',
        auth: false,
      ) as List<dynamic>;
      final map = <String, int>{};
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final rowCode = row['code']?.toString();
        final id = row['id'];
        if (rowCode != null && id != null) {
          map[rowCode] = (id as num).toInt();
        }
      }
      _labStoreIdCache = map;
      return map[code];
    } catch (error) {
      BackendHttp.log('BackendOrderRepository._labStoreIdFor failed', error: error);
      return null;
    }
  }

  /// Places every booking in the lab cart — one `POST /v1/member/
  /// lab-bookings` call per package (see `booking.service.ts`'s
  /// `bookLabTest`). [phone]/[name] are accepted for parity with the
  /// direct-Neon `OrderRepository.saveLabBookings` signature (so
  /// `lab_checkout_screen.dart`'s call site needs no changes beyond its
  /// import) but unused — the backend resolves identity from the session.
  ///
  /// The backend expects a real `labPackageId`, which [LabBookingInput]
  /// doesn't carry (root's direct-Neon write upserts `app.lab_package` by
  /// slug in the same transaction instead) — resolved here by matching
  /// [LabBookingInput.name] against a fresh [CareRepository.
  /// fetchLabPackages] read. [storeCode] is similarly a [ShieldStore.id],
  /// resolved to the backend's numeric id by [_labStoreIdFor].
  ///
  /// The backend's booking schema also wants a named `patients` array (a
  /// patient id, or a plain name) — the on-screen flow only ever collects a
  /// headcount per package ([LabBookingInput.patients]), so this
  /// synthesizes placeholder names ("Patient 1", "Patient 2", …) for that
  /// count, matching root's own booking UX exactly rather than the
  /// stricter shape the backend was also built to accept.
  ///
  /// Best-effort, the same contract as every write in this class except
  /// [checkoutStandardOrder]: a booking that fails to resolve or submit is
  /// logged and skipped rather than failing the rest of the basket — a lab
  /// booking is a request the lab confirms by phone, not money moving, so
  /// there is nothing here as failure-sensitive as a placed order.
  Future<void> saveLabBookings({
    String? phone,
    String? name,
    required List<LabBookingInput> bookings,
    Address? address,
    String? storeCode,
    LabFulfillmentType fulfillmentType = LabFulfillmentType.homeCollection,
  }) async {
    if (!BackendHttp.isConfigured || bookings.isEmpty) {
      return;
    }
    final addressId = address == null
        ? null
        : int.tryParse(address.remoteId ?? '') ??
            int.tryParse(
              await BackendAddressRepository.instance.upsert(
                    label: address.label.name.toUpperCase(),
                    house: address.house,
                    area: address.area,
                    landmark: address.landmark,
                    pincode: address.pincode,
                    firstName: address.firstName,
                    lastName: address.lastName,
                    phone: address.phone,
                    patientId: address.patientId,
                  ) ??
                  '',
            );
    final storeId = storeCode == null ? null : await _labStoreIdFor(storeCode);
    final packages = await CareRepository.instance.fetchLabPackages() ?? const [];
    for (final booking in bookings) {
      final package = packages.where((p) => p.name == booking.name).firstOrNull;
      if (package == null) {
        BackendHttp.log(
          'BackendOrderRepository.saveLabBookings: no backend package matches "${booking.name}" — skipped',
        );
        continue;
      }
      try {
        await BackendHttp.instance.request(
          'POST',
          '/v1/member/lab-bookings',
          body: {
            'labPackageId': int.parse(package.id),
            'patients': [
              for (var i = 1; i <= booking.patients; i++) {'name': 'Patient $i'},
            ],
            if (addressId != null) 'addressId': addressId,
            if (storeId != null) 'storeId': storeId,
            'fulfillmentType': fulfillmentType.apiValue,
          },
        );
      } catch (error) {
        BackendHttp.log(
          'BackendOrderRepository.saveLabBookings failed for "${booking.name}"',
          error: error,
        );
      }
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
