import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/home/product_showcase.dart';
import 'package:shield/screens/home_screen.dart';

void main() {
  // A tall surface forces every home section to lay out in one pass, including
  // the ones a normal viewport would leave unbuilt. Any RenderFlex overflow or
  // missing asset surfaces as a test failure.
  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // HomeScreen is always hosted by AppShell's Scaffold in production, which
    // is what supplies the Material ancestor its InkWells need.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeScreen())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home renders every section without overflow', (tester) async {
    await pumpHome(tester, const Size(400, 4200));

    expect(find.text('Say GoodBye to high medicine prices'), findsOneWidget);
    expect(find.text('Shop by categories'), findsOneWidget);
    expect(find.text('New on SHIELD'), findsOneWidget);
    expect(find.text('Best Sellers'), findsOneWidget);
    expect(find.text('Deals of the Day'), findsOneWidget);
    expect(find.text('What our customers say'), findsOneWidget);
  });

  testWidgets('review avatars and product cards are laid out', (tester) async {
    await pumpHome(tester, const Size(400, 4200));

    expect(find.text('Anjali Sharma'), findsOneWidget);
    expect(find.text('Verified purchase'), findsWidgets);
    expect(find.text('SHIELD Immunity Plus'), findsOneWidget);
    expect(find.text('ADD'), findsWidgets);
  });

  testWidgets('narrow viewport still lays out product cards', (tester) async {
    await pumpHome(tester, const Size(320, 4200));

    expect(find.text('New on SHIELD'), findsOneWidget);
    expect(find.byType(ProductShowcase), findsNWidgets(3));
  });

  testWidgets('wallet and cart actions are pinned to the right edge', (
    tester,
  ) async {
    const width = 400.0;
    await pumpHome(tester, const Size(width, 1200));

    final cart = find.byIcon(Icons.shopping_cart_outlined);
    final wallet = find.byIcon(Icons.account_balance_wallet_outlined);
    expect(cart, findsOneWidget);
    expect(wallet, findsOneWidget);

    final cartRight = tester.getTopRight(cart).dx;
    final walletRight = tester.getTopRight(wallet).dx;

    // Cart is the last action: its edge sits within the header's 8px right
    // padding plus the circle button's own inset.
    expect(width - cartRight, lessThan(24));
    // Wallet sits immediately left of the cart, not floating mid-header.
    expect(cartRight - walletRight, lessThan(80));
    expect(walletRight, greaterThan(width / 2));
  });
}
