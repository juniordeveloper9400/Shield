import 'package:flutter_test/flutter_test.dart';
import 'package:shield/data/neon/wallet_repository.dart';
import 'package:shield/module/privilege/privilege_tier.dart';
import 'package:shield/module/wallet/wallet_service.dart';
import 'package:shield/module/wallet/wallet_allowance.dart';

void main() {
  final load = PrivilegeProgramme.loadFor(10000)!;
  final card = WalletCard(load: load, issuedOn: DateTime(2026, 8, 15), rechargedOn: DateTime(2026, 8, 15));
  test('unused allowance remains before next due day and accumulates on due day', () {
    expect(card.releasedBy(DateTime(2026, 8, 14)), 0);
    expect(card.releasedBy(DateTime(2026, 8, 15)), 916);
    expect(card.releasedBy(DateTime(2026, 9, 14)), 916);
    expect(card.releasedBy(DateTime(2026, 9, 15)), 1832);
    expect(card.releasedBy(DateTime(2026, 11, 15)), 3664);
  });
  test('prior plan spending is deducted once; commission spending is separate', () {
    final entries = [
      (kind: 'SPEND', amount: -400, occurredOn: DateTime(2026, 8, 20)),
      (kind: 'REFERRAL_EARNINGS', amount: 200, occurredOn: DateTime(2026, 9, 1)),
      (kind: 'SPEND', amount: -300, occurredOn: DateTime(2026, 9, 16)),
    ];
    final date = DateTime(2026, 9, 20);
    expect(planDebitsThrough(entries, date), 500);
    expect(card.releasedBy(date) - planDebitsThrough(entries, date), 1332);
  });
  test('releases stop after 12 instalments without losing unused allowance', () {
    expect(card.releasedBy(DateTime(2027, 7, 15)), 10992);
    expect(card.releasedBy(DateTime(2028, 8, 15)), 10992);
  });
  test('31st release is clamped to February; no early next-month release', () {
    final endMonth = WalletCard(load: load, issuedOn: DateTime(2026, 1, 31), rechargedOn: DateTime(2026, 1, 31));
    expect(endMonth.releasedBy(DateTime(2026, 2, 27)), 916);
    expect(endMonth.releasedBy(DateTime(2026, 2, 28)), 1832);
    expect(endMonth.releasedBy(DateTime(2026, 3, 1)), 1832);
  });
  test('wallet includes unused prior months and respects actual balance', () {
    final wallet = WalletService.instance;
    wallet.reset();
    wallet.activate(load, on: DateTime(2026, 8, 15));
    expect(wallet.availableAllowanceOn(DateTime(2026, 9, 15)), 1832);
    wallet.reset();
  });

  group('Redeemable shows carry-forward even before the card\'s next due day', () {
    final wallet = WalletService.instance;
    setUp(wallet.reset);
    tearDown(wallet.reset);

    test('a card two months in, not yet due again this cycle, still shows '
        'what it released earlier', () {
      wallet.activate(load, on: DateTime(2026, 8, 15));
      // Before this fix, Redeemable asked "has a FRESH twelfth opened up
      // today" (monthlyRedeemableOn, still correct for its own purpose) —
      // 03 Oct falls between the Sep 15 and Oct 15 instalments, so that
      // question's answer is "no, nothing new yet" and the card read ₹0
      // redeemable despite the Aug/Sep instalments (₹1,832) never having
      // been touched.
      expect(
        wallet.monthlyRedeemableOn(DateTime(2026, 10, 3)),
        0,
        reason: "the narrower question this isn't answering any more",
      );
      expect(wallet.redeemableAllowanceOn(DateTime(2026, 10, 3)), 1832);
    });

    test('spending in an earlier month is carried into the next, not double '
        'counted against this one', () {
      wallet.activate(load, on: DateTime(2026, 8, 15));
      // A real, server-sourced debit — same as checkout or an OTP-collected
      // bill actually writes to app.wallet_entry — dated the month before,
      // via applyRemoteWallet the same way wallet_ledger_sync_test.dart does.
      wallet.applyRemoteWallet(const RemoteWallet(balance: 100000), [
        RemoteWalletEntry(
          kind: 'SPEND',
          label: 'Order SHD-1',
          amount: -400,
          occurredOn: DateTime(2026, 9, 20),
        ),
      ]);
      // ₹1,832 released by early October (Aug + Sep instalments), ₹400 of it
      // already spent in September — ₹1,432 of carry-forward walks into
      // October, before anything this month has touched it.
      expect(wallet.redeemableAllowanceOn(DateTime(2026, 10, 3)), 1432);
    });

    test('floors at zero rather than going negative when past spending '
        'outran what was ever released', () {
      wallet.activate(load, on: DateTime(2026, 8, 15));
      wallet.applyRemoteWallet(const RemoteWallet(balance: 100000), [
        RemoteWalletEntry(
          kind: 'SPEND',
          label: 'Order SHD-1',
          amount: -1832,
          occurredOn: DateTime(2026, 9, 20),
        ),
      ]);
      expect(wallet.redeemableAllowanceOn(DateTime(2026, 10, 3)), 0);
    });
  });
}
