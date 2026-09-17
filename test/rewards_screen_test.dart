import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/categories/categories_screen.dart';
import 'package:shield/module/refer/refer_earn_screen.dart';
import 'package:shield/module/refer/referral_service.dart';
import 'package:shield/module/rewards/rewards_screen.dart';

void main() {
  Future<void> pumpRewards(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RewardsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('coins are framed as a checkout discount, not cash', (
    tester,
  ) async {
    await pumpRewards(tester);

    expect(find.text('Spent at checkout'), findsOneWidget);
    expect(
      find.text(
        'Coins come off your bill at checkout. They can’t be withdrawn '
        'as cash or moved to your wallet.',
      ),
      findsOneWidget,
    );

    // No cash-out affordance: the old rate line and pay-out button are gone,
    // and the action is a way into the shop.
    expect(find.text('Redeem for wallet cash'), findsNothing);
    expect(find.textContaining('cash'), findsOneWidget); // only the disclaimer
    final shopButton = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data == 'Shop and use coins' || w.data == 'Shop to earn coins'),
    );
    expect(shopButton, findsOneWidget);
  });

  testWidgets('the exclusive offers section carries the milestone coupon, '
      'not a flat referral one', (tester) async {
    await pumpRewards(tester);

    expect(find.text('EXCLUSIVE OFFERS'), findsOneWidget);
    expect(find.text('JUST FOR YOU'), findsOneWidget);

    // The referral reward is level-based (see the Refer & Earn card below),
    // so the flat "Win flat 10,000" coupon that used to overstate it here is
    // gone — only the order-milestone coupon remains.
    expect(find.text('Win flat'), findsOneWidget);
    expect(find.text('Refer now'), findsNothing);
    expect(find.text('Start now'), findsOneWidget);
  });

  testWidgets('the refer & earn card shows real level progress and opens '
      'the refer journey', (tester) async {
    ReferralService.instance.debugReset();
    addTearDown(ReferralService.instance.debugReset);
    await pumpRewards(tester);

    expect(find.text('Refer & Earn'), findsOneWidget);
    expect(find.text('Climb levels, unlock reward points'), findsOneWidget);
    expect(find.text('Level 0 of 5'), findsOneWidget);
    expect(find.text('Refer 2 more for 100 points'), findsOneWidget);

    await tester.ensureVisible(find.text('Refer & Earn'));
    await tester.tap(find.text('Refer & Earn'));
    await tester.pumpAndSettle();

    expect(find.byType(ReferEarnScreen), findsOneWidget);
  });

  testWidgets('"Shop and use coins" opens the shop-by-category browser', (
    tester,
  ) async {
    await pumpRewards(tester);

    final shopButton = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data == 'Shop and use coins' || w.data == 'Shop to earn coins'),
    );
    await tester.ensureVisible(shopButton);
    await tester.tap(shopButton);
    await tester.pumpAndSettle();

    expect(find.byType(CategoriesScreen), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
  });

  testWidgets('the "Start now" offer coupon opens the same browser', (
    tester,
  ) async {
    await pumpRewards(tester);

    await tester.ensureVisible(find.text('Start now'));
    await tester.tap(find.text('Start now'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoriesScreen), findsOneWidget);
  });
}
