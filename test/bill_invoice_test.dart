import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/orders/bill_invoice.dart';
import 'package:shield/module/orders/bills_screen.dart';
import 'package:shield/module/orders/order_bill_screen.dart';
import 'package:shield/module/orders/purchase_service.dart';

/// A real 1×1 PNG, standing in for the picture the console attaches.
const _picture =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

const _lines = [
  InvoiceLine(name: 'Paracetamol 500mg', pack: 'Strip of 15', qty: 2, unitPaise: 3050),
  InvoiceLine(name: 'Cetirizine 10mg', qty: 1, unitPaise: 12000),
];

BillInvoice _invoice({bool paid = false, List<InvoiceLine> lines = _lines}) =>
    BillInvoice.compose(
      number: 'RX-MU8BWHGBD56A',
      billedAt: DateTime(2026, 9, 19, 12, 0),
      placedAt: DateTime(2026, 9, 18, 9, 30),
      customerName: 'Asaruuuu',
      customerPhone: '8137922524',
      storeName: 'Sahakar 360 Melattur',
      storeAddress: 'Melattur, Malappuram, Kerala, 679325',
      storePhone: '9000000001',
      deliveryAddress: 'hhha, jaja, Kerala, 679325',
      orderStatus: 'In progress',
      paid: paid,
      lines: lines,
      billPaise: 18100,
    );

Purchase _order({
  String? image,
  int? amount = 181,
  OrderPaymentStatus? billStatus = OrderPaymentStatus.pending,
  OrderKind kind = OrderKind.prescription,
}) => Purchase(
  id: 'RX-MU8BWHGBD56A',
  placedOn: '19 Sep 2026, 12:00 AM',
  itemCount: 2,
  mrpTotal: 0,
  paidTotal: 0,
  status: OrderStatus.processing,
  kind: kind,
  billImage: image,
  billedAt: DateTime(2026, 9, 19),
  billAmount: amount,
  billStatus: billStatus,
);

void main() {
  tearDown(PurchaseService.instance.clear);

  group('money', () {
    test('reads database text and numbers into exact paise', () {
      expect(paiseFrom('70.00'), 7000);
      expect(paiseFrom('12.5'), 1250);
      expect(paiseFrom(19.99), 1999);
      expect(paiseFrom(null), 0);
      expect(paiseFrom('abc'), 0);
    });

    test('prints rupees with Indian grouping and both decimals', () {
      expect(formatPaise(0), '₹0.00');
      expect(formatPaise(3050), '₹30.50');
      expect(formatPaise(12345600), '₹1,23,456.00');
      expect(formatPaise(-500), '-₹5.00');
    });
  });

  group('BillInvoice.compose', () {
    test('adds the items up and treats the saved bill as the total', () {
      final invoice = _invoice();

      // 2 × 30.50 + 1 × 120.00
      expect(invoice.subtotalPaise, 18100);
      expect(invoice.totalPaise, 18100);
      expect(invoice.adjustmentPaise, 0);
      expect(invoice.deliveryFeePaise, 0);
    });

    test('a saved total below the items is shown as an adjustment', () {
      final invoice = BillInvoice.compose(
        number: 'X',
        lines: _lines,
        billPaise: 17000,
      );

      expect(invoice.adjustmentPaise, -1100);
    });

    test('lists a delivery fee only when it reconciles to the total', () {
      final reconciles = BillInvoice.compose(
        number: 'X',
        lines: _lines,
        billPaise: 18100 + 4000,
        deliveryFeePaise: 4000,
      );
      final doesNot = BillInvoice.compose(
        number: 'X',
        lines: _lines,
        billPaise: 18100,
        deliveryFeePaise: 4000,
      );

      expect(reconciles.deliveryFeePaise, 4000);
      expect(reconciles.adjustmentPaise, 0);
      expect(doesNot.deliveryFeePaise, 0);
    });

    test('with no saved bill it falls back to what was paid, then to the '
        'items', () {
      expect(
        BillInvoice.compose(number: 'X', lines: _lines, paidTotalPaise: 9900)
            .totalPaise,
        9900,
      );
      expect(
        BillInvoice.compose(number: 'X', lines: _lines).totalPaise,
        18100,
      );
    });

    test('a pickup order prints no delivery address', () {
      final invoice = BillInvoice.compose(
        number: 'X',
        homeDelivery: false,
        deliveryAddress: 'somewhere',
      );

      expect(invoice.fulfillment, 'Store pickup');
      expect(invoice.deliveryAddress, isEmpty);
    });

    test('markPaid flips the status and keeps every figure', () {
      final paid = _invoice().markPaid(DateTime(2026, 9, 20));

      expect(paid.paid, isTrue);
      expect(paid.paidAt, DateTime(2026, 9, 20));
      expect(paid.totalPaise, 18100);
      expect(paid.lines.length, 2);
    });

    test('the shareable text names every item, its maths and the total', () {
      final text = _invoice(paid: true).toShareText();

      expect(text, contains('Invoice RX-MU8BWHGBD56A'));
      expect(text, contains('Paracetamol 500mg (Strip of 15)'));
      expect(text, contains('2 × ₹30.50 = ₹61.00'));
      expect(text, contains('Total: ₹181.00'));
      expect(text, contains('Payment: Paid'));
    });
  });

  group('Purchase.hasBill', () {
    test('is true for a picture, or for a priced bill with no picture', () {
      expect(_order(image: _picture, amount: 0).hasBill, isTrue);
      expect(_order(amount: 181).hasBill, isTrue);
    });

    test('is false with no bill row, or a draft still at zero', () {
      expect(_order(amount: null, billStatus: null).hasBill, isFalse);
      expect(_order(amount: 0).hasBill, isFalse);
    });
  });

  group('the bill screen', () {
    Future<void> pump(
      WidgetTester tester,
      Purchase order, {
      BillInvoice? invoice,
    }) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      PurchaseService.instance.replaceRemote([order]);

      await tester.pumpWidget(
        MaterialApp(
          home: OrderBillScreen(
            order: order,
            invoiceLoader: (_) async => invoice,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the store\'s bill picture and the itemised invoice '
        'under it', (tester) async {
      await pump(tester, _order(image: _picture), invoice: _invoice());

      expect(find.text('Bill from the store'), findsOneWidget);
      expect(find.text('INVOICE'), findsOneWidget);
      expect(find.text('RX-MU8BWHGBD56A'), findsOneWidget);
      // Items with quantity, price and amount.
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
      expect(find.text('Strip of 15'), findsOneWidget);
      expect(find.text('₹30.50'), findsOneWidget);
      expect(find.text('₹61.00'), findsOneWidget);
      expect(find.text('Cetirizine 10mg'), findsOneWidget);
      expect(find.text('₹120.00'), findsWidgets);
      // Totals, date, parties.
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('₹181.00'), findsWidgets);
      expect(find.textContaining('19 Sep 2026'), findsWidgets);
      expect(find.text('Sahakar 360 Melattur'), findsOneWidget);
      expect(find.text('Asaruuuu'), findsOneWidget);
      expect(find.text('PAYMENT PENDING'), findsOneWidget);
      expect(find.text('Share invoice'), findsOneWidget);
    });

    testWidgets('a priced bill with no picture shows the invoice alone', (
      tester,
    ) async {
      await pump(tester, _order(), invoice: _invoice());

      expect(find.text('Bill from the store'), findsNothing);
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
    });

    testWidgets('a paid bill is marked PAID', (tester) async {
      await pump(
        tester,
        _order(image: _picture, billStatus: OrderPaymentStatus.paid),
        invoice: _invoice(),
      );

      expect(find.text('PAID'), findsOneWidget);
      expect(find.text('PAYMENT PENDING'), findsNothing);
      expect(find.textContaining('Pay ₹'), findsNothing);
    });

    testWidgets('offers Pay now on a priced prescription bill still owed', (
      tester,
    ) async {
      await pump(tester, _order(image: _picture), invoice: _invoice());

      expect(find.text('Pay ₹181 now'), findsOneWidget);
    });

    testWidgets('with no itemised read it still prints the total and says '
        'the items were not listed', (tester) async {
      await pump(tester, _order(image: _picture));

      expect(find.text('INVOICE'), findsOneWidget);
      expect(find.textContaining('did not list the items'), findsOneWidget);
      expect(find.text('₹181.00'), findsWidgets);
    });

    testWidgets('an order with no bill says so', (tester) async {
      await pump(tester, _order(amount: null, billStatus: null));

      expect(find.text('No bill yet'), findsOneWidget);
      expect(find.text('INVOICE'), findsNothing);
    });
  });

  group('the Bills list', () {
    testWidgets('lists a priced bill that has no picture, and opens it', (
      tester,
    ) async {
      PurchaseService.instance.replaceRemote([_order()]);

      await tester.pumpWidget(const MaterialApp(home: BillsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('RX-MU8BWHGBD56A'), findsOneWidget);
      expect(find.text('₹181'), findsOneWidget);

      await tester.tap(find.text('RX-MU8BWHGBD56A'));
      await tester.pumpAndSettle();

      expect(find.text('INVOICE'), findsOneWidget);
    });
  });
}
