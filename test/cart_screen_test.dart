import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/cart/cart_control.dart';
import 'package:shield/module/cart/cart_screen.dart';
import 'package:shield/module/cart/cart_service.dart';
import 'package:shield/module/prescription/upload_prescription_screen.dart';
import 'package:shield/widgets/app_image.dart';

void main() {
  setUp(CartService.instance.reset);
  tearDown(CartService.instance.reset);

  Future<void> pumpCart(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CartScreen()));
    await tester.pumpAndSettle();
  }

  void seedOne() => CartService.instance.add(
    name: 'Neurobion Forte Tablet 30',
    pack: 'Strip of 30 Units',
    price: 40.4,
    mrp: 47.53,
  );

  group('cart screen — filled', () {
    testWidgets('lays out the item, the helper cards and the bar', (
      tester,
    ) async {
      seedOne();
      await pumpCart(tester);

      expect(find.text('1 Item'), findsOneWidget);
      expect(find.text('Neurobion Forte Tablet 30'), findsOneWidget);
      expect(find.text('15% OFF'), findsOneWidget);
      expect(find.text('Add more medicines'), findsOneWidget);
      expect(find.text('Upload a Prescription'), findsOneWidget);
      expect(find.text('Apply coupon'), findsOneWidget);
      expect(find.text('View bill'), findsOneWidget);
      expect(find.text('Proceed to checkout'), findsOneWidget);
    });

    testWidgets('the line shows the product artwork it was added with', (
      tester,
    ) async {
      CartService.instance.add(
        name: 'Protein Powder Chocolate',
        pack: 'Jar of 1kg',
        price: 1999,
        mrp: 3200,
        image: 'assets/products/protein_chocolate.png',
      );
      await pumpCart(tester);

      final thumb = tester.widget<AppImage>(find.byType(AppImage));
      expect(thumb.image, 'assets/products/protein_chocolate.png');
      expect(thumb.fallbackIcon, Icons.medication_outlined);
    });

    testWidgets('a line with no image falls back to the medicine icon', (
      tester,
    ) async {
      seedOne();
      await pumpCart(tester);

      expect(
        find.descendant(
          of: find.byType(CartScreen),
          matching: find.byIcon(Icons.medication_outlined),
        ),
        findsOneWidget,
      );
    });

    testWidgets('View bill opens the bill breakdown', (tester) async {
      seedOne();
      await pumpCart(tester);

      await tester.tap(find.text('View bill'));
      await tester.pumpAndSettle();

      expect(find.text('Bill summary'), findsOneWidget);
      expect(find.text('Item total'), findsOneWidget);
      expect(find.text('Total payable'), findsOneWidget);
    });

    testWidgets('the quantity field edits the line', (tester) async {
      seedOne();
      await pumpCart(tester);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Select quantity'), findsOneWidget);

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      expect(CartService.instance.lines.single.qty, 3);
    });

    Finder inStepper(Finder matching) =>
        find.descendant(of: find.byType(QuantityStepper), matching: matching);

    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Select quantity'), findsOneWidget);
      expect(find.byType(QuantityStepper), findsOneWidget);
    }

    testWidgets('the stepper raises and lowers the line, capped at the max', (
      tester,
    ) async {
      seedOne();
      await pumpCart(tester);
      await openPicker(tester);

      // Plus adds one and keeps the picker open.
      await tester.tap(inStepper(find.byIcon(Icons.add_rounded)));
      await tester.pump();
      expect(CartService.instance.lines.single.qty, 2);
      expect(find.text('Select quantity'), findsOneWidget);

      // Minus takes it back, and stops at 1.
      await tester.tap(inStepper(find.byIcon(Icons.remove_rounded)));
      await tester.pump();
      await tester.tap(inStepper(find.byIcon(Icons.remove_rounded)));
      await tester.pump();
      expect(CartService.instance.lines.single.qty, 1);
    });

    testWidgets('typing a number sets the quantity and clamps to the max', (
      tester,
    ) async {
      seedOne();
      await pumpCart(tester);
      await openPicker(tester);

      final field = inStepper(find.byType(TextField));
      await tester.enterText(field, '12');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(CartService.instance.lines.single.qty, 12);

      // Over the ceiling is pulled back to it.
      await tester.enterText(field, '99');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(CartService.instance.lines.single.qty, CartService.maxLineQty);
    });

    testWidgets('the picker offers every quantity up to the max', (
      tester,
    ) async {
      seedOne();
      await pumpCart(tester);
      await openPicker(tester);

      final maxChip = find.text('${CartService.maxLineQty}');
      expect(maxChip, findsOneWidget);
      await tester.ensureVisible(maxChip);
      await tester.tap(maxChip);
      await tester.pumpAndSettle();

      expect(CartService.instance.lines.single.qty, CartService.maxLineQty);
    });

    testWidgets('Remove item from the sheet clears the line', (tester) async {
      seedOne();
      await pumpCart(tester);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove item'));
      await tester.pumpAndSettle();

      expect(CartService.instance.isEmpty, isTrue);
      expect(find.text('Your cart is empty'), findsOneWidget);
    });

    testWidgets('the X on the card removes the line', (tester) async {
      seedOne();
      await pumpCart(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(CartService.instance.isEmpty, isTrue);
    });

    testWidgets('Upload a Prescription opens the upload screen', (tester) async {
      seedOne();
      await pumpCart(tester);

      await tester.tap(find.text('Upload a Prescription'));
      await tester.pumpAndSettle();

      expect(find.byType(UploadPrescriptionScreen), findsOneWidget);
    });
  });

  group('cart screen — empty', () {
    testWidgets('shows the empty state and no checkout bar', (tester) async {
      await pumpCart(tester);

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Proceed to checkout'), findsNothing);
      expect(find.text('View bill'), findsNothing);
    });
  });
}
