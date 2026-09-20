import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shield/module/refer/referral_service.dart';
import 'package:shield/module/refer/referral_level.dart';
import 'package:shield/module/refer/refer_earn_screen.dart';
void main() {
  test('unloaded account has no shareable invitation code', () {
    ReferralService.instance.debugReset();
    expect(ReferralService.instance.code, isEmpty);
  });
  testWidgets('invitation stays disabled until a real code is loaded', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReferEarnScreen(code: '', progress: ReferralProgress(directReferrals: 0))));
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Invite'));
    expect(button.onPressed, isNull);
  });
}
