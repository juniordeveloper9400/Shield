import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/auth/auth_service.dart';
import 'package:shield/module/cart/cart_screen.dart';
import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/checkout/checkout_order.dart';
import 'package:shield/module/checkout/checkout_screen.dart';
import 'package:shield/module/checkout/payment_receipt.dart';
import 'package:shield/module/checkout/receipt_form.dart';
import 'package:shield/module/location/address_book.dart';
import 'package:shield/module/orders/order_placed_screen.dart';
import 'package:shield/module/orders/purchase_service.dart';
import 'package:shield/module/privilege/privilege_screen.dart';
import 'package:shield/module/privilege/privilege_tier.dart';
import 'package:shield/module/registration/registration_service.dart';
import 'package:shield/module/wallet/wallet_service.dart';

void main() {
  void resetAll() {
    AuthService.instance.reset();
    RegistrationService.instance.reset();
    CartService.instance.reset();
    PurchaseService.instance.clear();
    WalletService.instance.reset();
    AddressBook.instance.reset();
    ReceiptPicker.debugOverride = null;
  }

  void giveAddress() {
    AddressBook.instance.add(
      const Address(
        pincode: '679322',
        house: '12/A',
        area: 'Palm Grove',
        firstName: 'Asha',
        phone: '9000012345',
        label: AddressLabel.home,
      ),
    );
  }

  void register({String storeId = 'SHD-MEL'}) {
    RegistrationService.instance.save(
      Registration(
        name: 'Asha Nair',
        phone: '9000012345',
        email: 'asha@example.com',
        gender: Gender.female,
        dob: DateTime(1994, 9, 4),
        address: '12/A Palm Grove',
        place: 'Perinthalmanna',
        pincode: '679322',
        state: 'Kerala',
        storeId: storeId,
      ),
    );
  }

  setUp(resetAll);
  tearDown(resetAll);

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(420, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  testWidgets('manual checkout shows store bank account and UPI coming soon', (
    tester,
  ) async {
    PaymentReceipt? receipt;
    await pump(
      tester,
      CheckoutScreen(
        order: const CheckoutOrder(
          title: 'Medicine order',
          subtitle: '1 item from your cart',
          amount: 450,
          reference: 'SHD-1',
          submitLabel: 'Submit receipt',
        ),
        onComplete: (value) async => receipt = value,
      ),
    );

    expect(find.text('Your store & agent'), findsOneWidget);
    expect(find.text('SHIELD Pharmacy Melattur'), findsWidgets);
    // The store is fixed to the one on the account — no picker, so no other
    // branch is offered.
    expect(find.byWidgetPredicate((w) => w is DropdownButtonFormField), findsNothing);
    expect(find.text('SHIELD Pharmacy Alanallur'), findsNothing);
    expect(find.text('State Bank of India · Melattur'), findsOneWidget);
    expect(find.text('Google Pay'), findsOneWidget);

    await tester.tap(find.text('Google Pay'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Google Pay is coming soon'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'AGT42');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Transfer to this account'), findsOneWidget);
    expect(find.text('6724 0031 9182'), findsOneWidget);
    expect(find.text('Upload payment receipt'), findsOneWidget);
    expect(find.text('Submit receipt'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    ReceiptPicker.debugOverride = (source) async =>
        const PickedFile(name: 'receipt.jpg', bytes: 120 * 1024);
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(find.text('receipt.jpg'), findsOneWidget);

    await tester.tap(find.text('Submit receipt'));
    await tester.pumpAndSettle();

    expect(receipt?.fileName, 'receipt.jpg');
    expect(receipt?.storeId, 'SHD-MEL');
    expect(receipt?.agentCode, 'AGT42');
    expect(receipt?.bankAccount.id, 'mel-sbi');
  });

  testWidgets('a registered member sees their registration store, fixed', (
    tester,
  ) async {
    AuthService.instance.signInAs();
    register(storeId: 'SHD-MJR');

    await pump(
      tester,
      CheckoutScreen(
        order: const CheckoutOrder(
          title: 'Medicine order',
          subtitle: '1 item from your cart',
          amount: 450,
          reference: 'SHD-2',
          submitLabel: 'Submit receipt',
        ),
        onComplete: (_) async {},
      ),
    );

    expect(find.text('SHIELD Pharmacy Manjery'), findsWidgets);
    expect(find.text('SHIELD Pharmacy Melattur'), findsNothing);
    expect(
      find.textContaining('store you chose during registration'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField),
      findsNothing,
    );
  });

  testWidgets('cart checkout will not advance without a delivery address', (
    tester,
  ) async {
    AuthService.instance.signInAs();
    RegistrationService.instance.dismissPrompt();
    CartService.instance.add(
      name: 'Test product',
      pack: 'Box',
      price: 450,
      mrp: 500,
    );

    await pump(tester, const CartScreen());
    await tester.tap(find.text('Proceed to checkout'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'AGT99');
    await tester.pumpAndSettle();

    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.text('Add delivery address'), findsOneWidget);
    expect(find.text('Required to place the order.'), findsOneWidget);
    // The one FilledButton on step one is the action bar; it is dead until an
    // address is saved.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('cart checkout places the order and confirms it with a tick', (
    tester,
  ) async {
    AuthService.instance.signInAs();
    RegistrationService.instance.dismissPrompt();
    giveAddress();
    CartService.instance.add(
      name: 'Test product',
      pack: 'Box',
      price: 450,
      mrp: 500,
    );
    ReceiptPicker.debugOverride = (source) async =>
        const PickedFile(name: 'cart-receipt.jpg', bytes: 100 * 1024);

    await pump(tester, const CartScreen());

    await tester.tap(find.text('Proceed to checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'AGT99');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    // The order is filed and the cart cleared…
    expect(CartService.instance.isEmpty, isTrue);
    final placed = PurchaseService.instance.purchases.single;
    expect(placed.mrpTotal, 500);
    expect(placed.paidTotal, 450);
    expect(PurchaseService.instance.savedTotal, 50);

    // …and the checkout is replaced by a tick-marked confirmation.
    expect(find.byType(OrderPlacedScreen), findsOneWidget);
    expect(find.byType(CheckoutScreen), findsNothing);
    expect(find.text('Order placed'), findsOneWidget);
    expect(find.text('Order ${placed.id}'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Track order'), findsOneWidget);
  });

  testWidgets('privilege activation opens checkout before wallet is credited', (
    tester,
  ) async {
    AuthService.instance.signInAs();
    register();
    ReceiptPicker.debugOverride = (source) async =>
        const PickedFile(name: 'plan-receipt.jpg', bytes: 100 * 1024);

    await pump(tester, const PrivilegeScreen(), size: const Size(420, 1800));

    await tester.tap(
      find.text(PrivilegeProgramme.silver.entry.amountLabel).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activate'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(WalletService.instance.isActivated, isFalse);

    await tester.enterText(find.byType(TextField).first, 'AGT11');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit receipt'));
    await tester.pumpAndSettle();

    expect(
      WalletService.instance.balance,
      PrivilegeProgramme.silver.entry.credited,
    );
  });
}
