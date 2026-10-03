import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/neon/order_repository.dart';
import '../../money.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_service.dart';
import '../checkout/fulfillment_type.dart';
import '../refer/referral_service.dart';
import '../rewards/rewards_service.dart';

/// Where an order has got to.
enum OrderStatus {
  delivered('Delivered', AppColors.greenTint, AppColors.brandGreenDark),
  outForDelivery('Out for delivery', AppColors.offerTint, AppColors.brandBlue),
  processing('Processing', Color(0xFFFDF3E0), Color(0xFFB4761A)),
  cancelled('Cancelled', Color(0xFFFBEBEB), Color(0xFFB4322F));

  final String label;
  final Color background;
  final Color foreground;

  const OrderStatus(this.label, this.background, this.foreground);

  /// Whether this order still counts. A cancelled order was never paid for,
  /// so it saved nothing and must not be added into what a member has earned.
  bool get counts => this != OrderStatus.cancelled;
}

/// The four stages a member sees an order move through — and the only status
/// they see. Derived by [Purchase.stage] from what the store has actually done
/// (the raw [OrderStatus] keeps driving delivery and cancellation behind the
/// scenes), so a stage can only advance when the store really did the step.
/// Labelled Pending / Processed / Billing / Completed — the exact words the
/// admin console's own order and prescription lifecycle status already use
/// (see shieldweb's orderLifecycle.ts), so the same order never reads as two
/// different things depending on who is looking at it:
///
///  * [placed] (label "Pending") — the order exists.
///  * [storeContact] (label "Processed") — staff used Call / WhatsApp on the
///    member in the admin console (`app."order".store_contacted_at`).
///  * [billed] (label "Billing") — the store has sent a bill for it.
///  * [complete] (label "Completed") — the store completed the order.
enum OrderStage {
  placed('Pending', Color(0xFFFDF3E0), Color(0xFFB4761A)),
  storeContact('Processed', AppColors.offerTint, AppColors.brandBlue),
  billed('Billing', Color(0xFFEDE7F6), Color(0xFF5E35B1)),
  complete('Completed', AppColors.greenTint, AppColors.brandGreenDark),
  cancelled('Cancelled', Color(0xFFFBEBEB), Color(0xFFB4322F));

  final String label;
  final Color background;
  final Color foreground;

  const OrderStage(this.label, this.background, this.foreground);

  /// The furthest stage an order has reached, from the three things the
  /// store's actions leave behind: its status, whether a bill row exists, and
  /// whether staff have contacted the member.
  ///
  /// The one rule, shared by [Purchase.stage] on the Track order screen and by
  /// [LinkedOrder.stage] on a prescription's card, so the two can never say
  /// different things about the same order. Cancelled and delivered come
  /// straight from the status. Below that, a bill means [billed], and a
  /// contact stamp — or an order already out for delivery, which the store
  /// obviously handled — means [storeContact]. Reading the *furthest* signal
  /// means an order billed without anyone pressing Call still shows as billed,
  /// never stuck.
  static OrderStage derive({
    required OrderStatus status,
    required bool billed,
    required bool contacted,
  }) {
    if (status == OrderStatus.cancelled) return OrderStage.cancelled;
    if (status == OrderStatus.delivered) return OrderStage.complete;
    if (billed) return OrderStage.billed;
    if (contacted || status == OrderStatus.outForDelivery) {
      return OrderStage.storeContact;
    }
    return OrderStage.placed;
  }
}

/// Where an order came from — which decides the stages it moves through.
///
/// A [standard] order is picked from stock and goes straight to packing. A
/// [prescription] order is read and priced by a pharmacist first, so its
/// tracker carries two stages the standard one does not.
enum OrderKind { standard, prescription }

/// Whether an order (or the bill on a prescription order) has actually been
/// paid — the `app.order_payment_status` / `app.bill`'s own status token,
/// read back the same way on both.
enum OrderPaymentStatus { pending, paid }

/// One completed purchase: what it was worth at list price, and what was
/// actually paid for it.
///
/// Both figures are kept rather than a discount percentage, because the
/// saving is the difference between two real amounts. A rate would have to be
/// applied to something to become money again, and every application is
/// another chance for the figure on one screen to disagree with the figure on
/// another.
@immutable
class Purchase {
  final String id;
  final String placedOn;
  final int itemCount;

  /// What the items on this order add up to at their printed price.
  final int mrpTotal;

  /// What the member actually paid.
  final int paidTotal;

  final OrderStatus status;

  /// What kind of order this is. Defaults to [OrderKind.standard] so every
  /// existing call site and stored line keeps its meaning.
  final OrderKind kind;

  /// The store's own invoice for this order, when one has been sent — a
  /// small `data:` image the admin console attaches, not the receipt the
  /// member themselves uploaded. Null until then.
  final String? billImage;

  /// When [billImage] was attached. Null until a bill has been sent.
  final DateTime? billedAt;

  /// How this order reaches the member. Defaults to [FulfillmentType.homeDelivery]
  /// so every existing call site and stored line keeps its meaning.
  final FulfillmentType fulfillmentType;

  /// Whether this order itself has been paid — distinct from [billStatus],
  /// which is what a prescription's priced bill carries. A standard order
  /// paid by wallet at checkout is [OrderPaymentStatus.paid] the moment it is
  /// placed; a cash order stays [OrderPaymentStatus.pending] until someone at
  /// the counter or on the delivery round collects it.
  final OrderPaymentStatus paymentStatus;

  /// What the store billed this order at, in whole rupees. Null when no
  /// `app.bill` row exists for it yet; a row still at zero is a draft the
  /// counter has not priced (see [hasBill]).
  final int? billAmount;

  /// Whether [billAmount] has actually been paid. Null until the bill has a
  /// price at all.
  final OrderPaymentStatus? billStatus;

  /// How much of the bill's own priced subtotal the store knocked off —
  /// `app.bill.discount_amount`. ₹0 for an order with no bill yet, a bill
  /// with no discount, or a plain picture-only bill (which never carries
  /// one). This, not [mrpTotal]/[paidTotal] (the checkout-time printed price
  /// vs. what was paid), is what "Your earnings" counts as saved — a real
  /// offer the store actually gave at billing time, not a permanent catalog
  /// discount every member already sees before ever placing the order.
  final int billDiscount;

  /// When staff first contacted the member about this order —
  /// `app."order".store_contacted_at`. Null until the store has (or for an
  /// order that predates it and skipped straight to a bill; [stage] handles
  /// both).
  final DateTime? storeContactedAt;

  /// When staff saved/submitted the order's review — `app."order".reviewed_at`.
  /// Null until then. The admin console's own order list counts this alone
  /// as "Processed" too (`orderLifecycle.ts`'s `orderLifecycleStatus`); [stage]
  /// reads it alongside [storeContactedAt] so this screen can never show
  /// "Pending" for an order the console already calls "Processed".
  final DateTime? reviewedAt;

  /// "Convert to bill →" in the admin console — `app."order"
  /// .converted_to_bill_at`. Null until then. This, not whether a priced
  /// [billStatus] row exists yet (pricing is its own later step), is what
  /// the console counts as reaching "Billing" (`orderLifecycle.ts`), and what
  /// [stage] reads for the same reason.
  final DateTime? convertedToBillAt;

  const Purchase({
    required this.id,
    required this.placedOn,
    required this.itemCount,
    required this.mrpTotal,
    required this.paidTotal,
    required this.status,
    this.kind = OrderKind.standard,
    this.billImage,
    this.billedAt,
    this.fulfillmentType = FulfillmentType.homeDelivery,
    this.paymentStatus = OrderPaymentStatus.pending,
    this.billAmount,
    this.billStatus,
    this.billDiscount = 0,
    this.storeContactedAt,
    this.reviewedAt,
    this.convertedToBillAt,
  });

  /// The furthest stage the order has reached — see [OrderStage].
  ///
  /// Cancelled and delivered come straight from the order's status. Below
  /// that, "Convert to bill →" having been clicked means [OrderStage.billed]
  /// — the same milestone the console itself counts, not whether a priced
  /// bill has actually been sent yet — and either staff action — a review
  /// saved, or a contact stamp — or an order already out for delivery, which
  /// the store obviously handled — means [OrderStage.storeContact]. Reading
  /// the *furthest* signal means an order billed without anyone pressing
  /// Call still shows as billed, never stuck.
  OrderStage get stage => OrderStage.derive(
    status: status,
    billed: convertedToBillAt != null,
    contacted: storeContactedAt != null || reviewedAt != null,
  );

  /// Whether the store has sent a bill for this order: either a picture it
  /// attached, or a priced bill it typed in line by line (which carries no
  /// picture at all). A bill row still at ₹0 with nothing attached is a draft
  /// the counter has not finished, so it does not count.
  bool get hasBill => billImage != null || (billAmount ?? 0) > 0;

  /// A copy with just the payment fields swapped in — what a wallet "Pay now"
  /// applies once the debit has gone through, so the order and its bill read
  /// as paid without waiting on the next full server sync.
  Purchase copyWith({
    OrderPaymentStatus? paymentStatus,
    OrderPaymentStatus? billStatus,
    DateTime? convertedToBillAt,
  }) => Purchase(
    id: id,
    placedOn: placedOn,
    itemCount: itemCount,
    mrpTotal: mrpTotal,
    paidTotal: paidTotal,
    status: status,
    kind: kind,
    billImage: billImage,
    billedAt: billedAt,
    fulfillmentType: fulfillmentType,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    billAmount: billAmount,
    billStatus: billStatus ?? this.billStatus,
    billDiscount: billDiscount,
    storeContactedAt: storeContactedAt,
    reviewedAt: reviewedAt,
    convertedToBillAt: convertedToBillAt ?? this.convertedToBillAt,
  );

  /// A prescription order still waiting on money: priced or not, nothing has
  /// been paid and it has not been delivered or called off.
  bool get awaitingPayment =>
      kind == OrderKind.prescription &&
      paidTotal == 0 &&
      status != OrderStatus.delivered &&
      status != OrderStatus.cancelled;

  /// What the order earned: the gap between the printed price and the bill.
  ///
  /// A ₹500 product bought for ₹450 earned ₹50. Never negative — an order
  /// that somehow cost more than list price did not earn a negative amount,
  /// it earned nothing.
  int get saved => mrpTotal - paidTotal < 0 ? 0 : mrpTotal - paidTotal;

  String get paidLabel => '₹${formatRupees(paidTotal)}';

  String get mrpLabel => '₹${formatRupees(mrpTotal)}';

  String get savedLabel => '₹${formatRupees(saved)}';

  /// `₹450` — what the store billed, or null before a bill has a price. What
  /// the Track order screen's Billing-stage callout shows.
  String? get billLabel =>
      billAmount == null ? null : '₹${formatRupees(billAmount!)}';

  /// The bill's own gross subtotal before [billDiscount] came off it — the
  /// "Bill" figure "Your earnings" shows next to what was actually paid, the
  /// same "printed vs paid" shape as [mrpTotal]/[paidTotal] but sourced from
  /// the store's own bill rather than checkout.
  int get billGross => (billAmount ?? 0) + billDiscount;

  String get billGrossLabel => '₹${formatRupees(billGross)}';

  String get billPaidLabel => '₹${formatRupees(billAmount ?? 0)}';

  String get billDiscountLabel => '₹${formatRupees(billDiscount)}';
}

/// The order a prescription was placed into — its code and where it has got to
/// — as read off the prescription's row (`app.prescription_order` →
/// `app."order"`). What a prescription's card shows as its order status.
///
/// The app's own order book ([PurchaseService.purchaseFor]) is preferred when
/// it has the order, since it also carries the bill and payment; this is what
/// the card falls back on until the book has loaded it.
@immutable
class LinkedOrder {
  /// The order's own code (`RX-MU8BWHGBD56A`) — not the prescription's
  /// `RX-0003`.
  final String code;
  final OrderStatus status;
  final DateTime? storeContactedAt;

  /// When staff saved/submitted the order's review — mirrors [Purchase.reviewedAt].
  final DateTime? reviewedAt;
  final bool billed;

  const LinkedOrder({
    required this.code,
    required this.status,
    this.storeContactedAt,
    this.reviewedAt,
    this.billed = false,
  });

  /// Reads an `app."order".status` token — `PROCESSING` / `OUT_FOR_DELIVERY`
  /// / `DELIVERED` / `CANCELLED` — plus the same stage signals
  /// [Purchase.stage] reads, into a link; null when there is no order code (a
  /// prescription that was never ordered).
  static LinkedOrder? fromTokens({
    Object? code,
    Object? status,
    Object? storeContactedAt,
    Object? reviewedAt,
    Object? billed,
  }) {
    final orderCode = (code ?? '').toString().trim();
    if (orderCode.isEmpty) {
      return null;
    }
    return LinkedOrder(
      code: orderCode,
      status: switch ((status ?? '').toString().toUpperCase()) {
        'DELIVERED' => OrderStatus.delivered,
        'OUT_FOR_DELIVERY' => OrderStatus.outForDelivery,
        'CANCELLED' => OrderStatus.cancelled,
        _ => OrderStatus.processing,
      },
      storeContactedAt: DateTime.tryParse((storeContactedAt ?? '').toString()),
      reviewedAt: DateTime.tryParse((reviewedAt ?? '').toString()),
      // NeonHttp's `/sql` endpoint hands every value back as text (see its
      // own `Neon-Raw-Text-Output` header), so a SQL boolean arrives as
      // `'t'`/`'true'`, never the real `bool` a plain JSON API would give —
      // the same defensive read `agent_repository.dart`'s own `active` field
      // already needs.
      billed: billed == true ||
          const ['true', 't', '1'].contains(
            billed?.toString().trim().toLowerCase(),
          ),
    );
  }

  /// The furthest stage this order has reached — see [OrderStage]. The same
  /// rule [Purchase.stage] uses, so a prescription's card and the order it
  /// was placed into can never disagree.
  OrderStage get stage => OrderStage.derive(
    status: status,
    billed: billed,
    contacted: storeContactedAt != null || reviewedAt != null,
  );

  /// A bare [Purchase] carrying just what the tracker draws from — its status
  /// and stage signals — for a link the order book has not loaded yet.
  /// [convertedToBillAt] only needs to be non-null when [billed] is true —
  /// [Purchase.stage] only ever checks its presence, never its actual value,
  /// since this link never carries the real stamp itself (just whether one
  /// exists).
  Purchase toPurchase() => Purchase(
    id: code,
    placedOn: '',
    itemCount: 0,
    mrpTotal: 0,
    paidTotal: 0,
    status: status,
    kind: OrderKind.prescription,
    storeContactedAt: storeContactedAt,
    reviewedAt: reviewedAt,
    convertedToBillAt: billed ? DateTime.now() : null,
  );

  @override
  bool operator ==(Object other) =>
      other is LinkedOrder &&
      other.code == code &&
      other.status == status &&
      other.storeContactedAt == storeContactedAt &&
      other.reviewedAt == reviewedAt &&
      other.billed == billed;

  @override
  int get hashCode =>
      Object.hash(code, status, storeContactedAt, reviewedAt, billed);
}

/// The order book, and the earnings that come out of it.
///
/// One place, because the orders list and the earnings card were otherwise
/// two fixtures of the same purchases: a screen that lists four orders and a
/// card that totals a different four is the app disagreeing with itself over
/// money. The list reads [purchases]; the card reads the sums below it.
///
/// In memory only; a backend would replace this class wholesale.
class PurchaseService extends ChangeNotifier {
  PurchaseService._() {
    AuthService.instance.currentUser.addListener(_onAuthChanged);
  }

  static final PurchaseService instance = PurchaseService._();

  final List<Purchase> _purchases = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  List<Purchase> get purchases => List.unmodifiable(_purchases);

  void _onAuthChanged() {
    final phone = AuthService.instance.currentUser.value?.phone;
    if (phone != null) {
      unawaited(ensureLoaded(force: true));
    }
  }

  /// Ensures member orders are loaded from the backend/database.
  Future<void> ensureLoaded({bool force = false}) async {
    final phone = AuthService.instance.currentUser.value?.phone;
    if (phone == null) return;
    if (!force && _purchases.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();
    try {
      final remote = await OrderRepository.instance.listForMember(phone);
      if (remote != null) {
        _purchases
          ..clear()
          ..addAll(remote);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// The loaded order [link] points at, matched by order code, or null when
  /// the order book has not loaded it (yet).
  Purchase? purchaseFor(LinkedOrder? link) {
    if (link == null) return null;
    for (final purchase in _purchases) {
      if (purchase.id == link.code) return purchase;
    }
    return null;
  }

  bool get isEmpty => _purchases.isEmpty;

  /// Orders that still count — everything but the cancelled ones.
  Iterable<Purchase> get _counted =>
      _purchases.where((purchase) => purchase.status.counts);

  /// Orders still on their way: what the dashboard calls active.
  int get activeCount => _purchases
      .where(
        (purchase) =>
            purchase.status == OrderStatus.processing ||
            purchase.status == OrderStatus.outForDelivery,
      )
      .length;

  /// What everything bought would have cost at printed prices.
  int get mrpTotal =>
      _counted.fold(0, (sum, purchase) => sum + purchase.mrpTotal);

  /// What was actually paid for it.
  int get paidTotal =>
      _counted.fold(0, (sum, purchase) => sum + purchase.paidTotal);

  /// The whole of what buying through Sahakar 360 has earned.
  ///
  /// Added up from the orders rather than stored, so it cannot fall behind
  /// the list it is a sum of.
  int get savedTotal => _counted.fold(0, (sum, purchase) => sum + purchase.saved);

  String get mrpLabel => '₹${formatRupees(mrpTotal)}';

  String get paidLabel => '₹${formatRupees(paidTotal)}';

  String get savedLabel => '₹${formatRupees(savedTotal)}';

  /// The share of list price the member has kept, 0..1.
  ///
  /// Worked out at the end, over the totals, rather than averaged across the
  /// orders' own rates — a 40% saving on ₹100 and a 5% saving on ₹5,000 do not
  /// average to 22.5% of anything a member spent.
  double get savedFraction => mrpTotal <= 0 ? 0 : savedTotal / mrpTotal;

  /// "26%" — the same fraction as a whole number of percent.
  String get savedPercentLabel => '${(savedFraction * 100).round()}%';

  /// Only the orders the store actually gave a bill discount on — what
  /// "Your earnings"' order breakdown shows at all, now that it counts a
  /// real offer at billing time rather than the checkout-time printed price.
  Iterable<Purchase> get billDiscounted =>
      _counted.where((purchase) => purchase.billDiscount > 0);

  /// What those bills' own subtotals add up to before the discount.
  int get billGrossTotal =>
      billDiscounted.fold(0, (sum, purchase) => sum + purchase.billGross);

  /// What was actually billed for them, net of the discount.
  int get billPaidTotal =>
      billDiscounted.fold(0, (sum, purchase) => sum + (purchase.billAmount ?? 0));

  /// The whole of what the store's own bill discounts add up to — added up
  /// from the orders rather than stored, so it cannot fall behind the list
  /// it is a sum of.
  int get billSavedTotal =>
      billDiscounted.fold(0, (sum, purchase) => sum + purchase.billDiscount);

  /// Files a completed order and returns the record that was filed, so a
  /// confirmation screen can carry the member straight to it.
  Purchase record({
    required String id,
    required String placedOn,
    required int itemCount,
    required int mrpTotal,
    required int paidTotal,
    OrderStatus status = OrderStatus.processing,
    OrderKind kind = OrderKind.standard,
    FulfillmentType fulfillmentType = FulfillmentType.homeDelivery,
    OrderPaymentStatus paymentStatus = OrderPaymentStatus.pending,
  }) {
    final purchase = Purchase(
      id: id,
      placedOn: placedOn,
      itemCount: itemCount,
      mrpTotal: mrpTotal,
      paidTotal: paidTotal,
      status: status,
      kind: kind,
      fulfillmentType: fulfillmentType,
      paymentStatus: paymentStatus,
    );
    _purchases.insert(0, purchase);

    // Reward points for what was actually paid (₹100 → 10 pts).
    // Best-effort and signed-in only; a prescription order still awaiting
    // pricing has paidTotal 0 and earns nothing until it is paid.
    if (purchase.status.counts &&
        paymentStatus == OrderPaymentStatus.paid &&
        paidTotal > 0) {
      unawaited(
        RewardsService.instance.awardForOrder(code: id, paidRupees: paidTotal),
      );
      // If somebody referred this member, their first paid order is the
      // "transacted" step the ladder actually asks for — see
      // ReferralLadder.stepsFor. A no-op for a member nobody referred.
      unawaited(ReferralService.instance.markTransacted());
    }

    notifyListeners();
    return purchase;
  }

  /// Replaces one order in place — what a wallet "Pay now" calls once its
  /// debit has gone through, so the screen it was tapped from reflects the
  /// payment without waiting on the next [replaceRemote]. A no-op when
  /// [updated] is not (by id) an order already on file.
  void updateOne(Purchase updated) {
    final index = _purchases.indexWhere((p) => p.id == updated.id);
    if (index == -1) {
      return;
    }
    _purchases[index] = updated;
    notifyListeners();
  }

  /// Swaps in the member's real order book, as read from `app."order"` —
  /// called once at sign-in / launch (see `AppShell`), the same way
  /// `PatientBook.replaceRemote` seeds the saved-patients list.
  ///
  /// A straight replace, not a merge: every order this service's own
  /// [record] ever creates is written through to the database in the same
  /// checkout call, so there is no local-only order to preserve — the server
  /// is simply the newer, authoritative copy of what [record] already wrote.
  /// Already sorted newest-first by the query this reads.
  void replaceRemote(List<Purchase> remote) {
    _purchases
      ..clear()
      ..addAll(remote);
    notifyListeners();
  }

  @visibleForTesting
  void clear() {
    _purchases.clear();
    notifyListeners();
  }

  /// A representative order book — two active, one delivered, one cancelled,
  /// one filled from a prescription — for tests that exercise the earnings
  /// math and the orders list against something shaped like real use.
  ///
  /// Not used by the app itself: a signed-in member's real order book comes
  /// from `OrderRepository.listForMember` via [replaceRemote] (see
  /// `AppShell.initState`), and a fresh install with nothing recorded yet
  /// shows an empty list, not this. Call it explicitly from a test's own
  /// setup rather than reaching for it through [clear] — nothing here does
  /// that on this class's behalf.
  ///
  /// Every line carries both prices, so the earnings card has something real
  /// to subtract rather than a percentage applied to a total.
  void seedSampleOrders() {
    if (_purchases.isNotEmpty) {
      return;
    }
    _purchases.addAll(const [
      Purchase(
        id: 'SHD-100482',
        placedOn: '16 Aug 2026',
        itemCount: 4,
        mrpTotal: 1686,
        paidTotal: 1248,
        status: OrderStatus.delivered,
      ),
      Purchase(
        id: 'SHD-100461',
        placedOn: '12 Aug 2026',
        itemCount: 2,
        mrpTotal: 800,
        paidTotal: 640,
        status: OrderStatus.outForDelivery,
      ),
      // Filled from an uploaded prescription, so its tracker runs the longer
      // pharmacist route. Already priced and paid, so it reads like any other
      // order in the list.
      Purchase(
        id: 'SHD-100433',
        placedOn: '04 Aug 2026',
        itemCount: 7,
        mrpTotal: 2820,
        paidTotal: 2115,
        status: OrderStatus.processing,
        kind: OrderKind.prescription,
      ),
      // Cancelled, so it is listed but earns nothing.
      Purchase(
        id: 'SHD-100398',
        placedOn: '27 Jul 2026',
        itemCount: 1,
        mrpTotal: 361,
        paidTotal: 289,
        status: OrderStatus.cancelled,
      ),
    ]);
  }
}
