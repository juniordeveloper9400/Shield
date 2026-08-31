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
import 'package:shield/module/patients/patient_book.dart';
import 'package:shield/module/privilege/privilege_screen.dart';
import 'package:shield/module/privilege/privilege_tier.dart';
import 'package:shield/module/registration/registration_service.dart';
import 'package:shield/module/registration/shield_store.dart';
import 'package:shield/module/wallet/wallet_service.dart';
import 'package:shield/money.dart';

void main() {
  void resetAll() {
    AuthService.instance.reset();
    RegistrationService.instance.reset();
    CartService.instance.reset();
    PurchaseService.instance.clear();
    WalletService.instance.reset();
    AddressBook.instance.reset();
    PatientBook.instance.reset();
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

  void givePatient() {
    PatientBook.instance.add(
      name: 'Asha Nair',
      phone: '9000012345',
      dob: DateTime(1994, 9, 4),
      gender: PatientGender.female,
      relation: PatientRelation.self,
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

    // The picture alone does not arm the button — the UTR / transaction ID is
    // mandatory too.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField).first, 'UTR7788990011');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit receipt'));
    await tester.pumpAndSettle();

    expect(receipt?.fileName, 'receipt.jpg');
    expect(receipt?.storeId, 'SHD-MEL');
    expect(receipt?.agentCode, 'AGT42');
    expect(receipt?.bankAccount.id, 'mel-sbi');
    expect(receipt?.bankReference, 'UTR7788990011');
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

    await pump(tester, const CartScreen(), size: const Size(420, 3400));
    await tester.tap(find.text('Proceed to checkout'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'AGT99');
    await tester.pumpAndSettle();

    expect(find.text('DELIVER TO'), findsOneWidget);
    expect(find.text('Add a delivery address'), findsOneWidget);
    expect(find.text('PATIENT'), findsOneWidget);
    expect(find.text('Add a patient'), findsOneWidget);
    expect(
      find.text('A delivery address and a patient are required to continue.'),
      findsOneWidget,
    );
    // The one FilledButton on step one is the action bar; it is dead until an
    // address and a patient are both chosen.
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
    givePatient();
    CartService.instance.add(
      name: 'Test product',
      pack: 'Box',
      price: 450,
      mrp: 500,
    );
    ReceiptPicker.debugOverride = (source) async =>
        const PickedFile(name: 'cart-receipt.jpg', bytes: 100 * 1024);

    await pump(tester, const CartScreen(), size: const Size(420, 3400));

    await tester.tap(find.text('Proceed to checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Order Summary'), findsOneWidget);
    expect(find.text('DELIVER TO'), findsOneWidget);
    expect(find.text('Home (679322)'), findsOneWidget);
    expect(find.text('PATIENT'), findsOneWidget);
    expect(find.text('Asha Nair'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'AGT99');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select payment mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'UTR123456');
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

  testWidgets(
    'a last-minute buy added on the order summary reaches the total and the '
    'placed order',
    (tester) async {
      AuthService.instance.signInAs();
      RegistrationService.instance.dismissPrompt();
      giveAddress();
      givePatient();
      CartService.instance.add(
        name: 'Test product',
        pack: 'Box',
        price: 450,
        mrp: 500,
      );
      ReceiptPicker.debugOverride = (source) async =>
          const PickedFile(name: 'cart-receipt.jpg', bytes: 100 * 1024);

      await pump(tester, const CartScreen(), size: const Size(420, 3400));
      await tester.tap(find.text('Proceed to checkout'));
      await tester.pumpAndSettle();

      // Delivery fee (₹40) on top of the one item's price.
      expect(find.text('₹${formatRupees(490)}'), findsWidgets);

      // What tapping ADD on "Last minute buys" does under the hood: another
      // line lands in the same cart while this screen is still open.
      CartService.instance.add(
        name: 'Dolo 650mg Tablet',
        pack: 'Strip of 15 tablets',
        price: 32,
        mrp: 35,
      );
      await tester.pumpAndSettle();

      // The total on this very screen has already moved to include it.
      expect(find.text('₹${formatRupees(490)}'), findsNothing);
      expect(find.text('₹${formatRupees(522)}'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, 'AGT99');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select payment mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'UTR123456');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      // The placed order counts both lines, not just the one that was in the
      // cart when "Proceed to checkout" was first tapped.
      final placed = PurchaseService.instance.purchases.single;
      expect(placed.itemCount, 2);
      expect(placed.mrpTotal, 535);
      expect(placed.paidTotal, 482);
    },
  );

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
    await tester.enterText(find.byType(TextField).first, 'UTR123456');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit receipt'));
    await tester.pumpAndSettle();

    expect(
      WalletService.instance.balance,
      PrivilegeProgramme.silver.entry.credited,
    );
  });

  testWidgets(
    'holding two plans, checkout offers a plan chooser that moves the branch',
    (tester) async {
      AuthService.instance.signInAs();
      register(storeId: 'SHD-MEL');
      // Two plans activated against different branches.
      WalletService.instance.activate(
        PrivilegeProgramme.silver.entry,
        store: StoreDirectory.byId('SHD-MEL'),
      );
      WalletService.instance.activate(
        PrivilegeProgramme.gold.entry,
        store: StoreDirectory.byId('SHD-ALN'),
      );

      PaymentReceipt? receipt;
      await pump(
        tester,
        CheckoutScreen(
          order: const CheckoutOrder(
            title: 'Medicine order',
            subtitle: '1 item from your cart',
            amount: 450,
            reference: 'SHD-9',
            submitLabel: 'Submit receipt',
          ),
          onComplete: (value) async => receipt = value,
        ),
        size: const Size(420, 2000),
      );

      // The chooser lists both plans, and the branch defaults to the plan on
      // the registration store — Silver, at Melattur.
      expect(
        find.textContaining('Bill this order against one of your active plans'),
        findsOneWidget,
      );
      expect(find.text('Silver Shield'), findsOneWidget);
      expect(find.text('Gold Shield'), findsOneWidget);
      expect(find.text('SHIELD Pharmacy Melattur'), findsWidgets);

      // Pick the Gold plan: the locked branch moves to the one it was
      // activated at, and the note names the plan.
      await tester.tap(find.text('Gold Shield'));
      await tester.pumpAndSettle();
      expect(find.text('SHIELD Pharmacy Alanallur'), findsWidgets);
      expect(
        find.textContaining('Serving branch for your Gold Shield'),
        findsOneWidget,
      );

      // …and that branch is what the submitted receipt carries.
      await tester.enterText(find.byType(TextField).first, 'AGT42');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      ReceiptPicker.debugOverride = (source) async =>
          const PickedFile(name: 'receipt.jpg', bytes: 120 * 1024);
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'UTR7788990011');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit receipt'));
      await tester.pumpAndSettle();

      expect(receipt?.storeId, 'SHD-ALN');
      expect(receipt?.bankAccount.id, 'aln-sbi');
    },
  );

  testWidgets('a single activated plan shows no chooser', (tester) async {
    AuthService.instance.signInAs();
    register(storeId: 'SHD-MJR');
    WalletService.instance.activate(
      PrivilegeProgramme.silver.entry,
      store: StoreDirectory.byId('SHD-MEL'),
    );

    await pump(
      tester,
      CheckoutScreen(
        order: const CheckoutOrder(
          title: 'Medicine order',
          subtitle: '1 item from your cart',
          amount: 450,
          reference: 'SHD-10',
          submitLabel: 'Submit receipt',
        ),
        onComplete: (_) async {},
      ),
    );

    expect(
      find.textContaining('Bill this order against'),
      findsNothing,
    );
    // The branch stays the registration one, locked.
    expect(find.text('SHIELD Pharmacy Manjery'), findsWidgets);
    expect(
      find.textContaining('store you chose during registration'),
      findsOneWidget,
    );
  });
}
