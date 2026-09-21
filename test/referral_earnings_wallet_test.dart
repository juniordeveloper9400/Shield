import 'package:flutter_test/flutter_test.dart';

import 'package:shield/data/neon/wallet_repository.dart';
import 'package:shield/module/wallet/wallet_service.dart';

/// Sahakar money — the commission a friend's plan pays — is credited to the
/// referrer's wallet on the server. These are the app's side of that: it shows
/// up in the balance and the ledger, and only once.
void main() {
  final wallet = WalletService.instance;

  RemoteReferralEarning earning(String id, int amount, [DateTime? on]) =>
      RemoteReferralEarning(
        id: id,
        label: 'Referral commission',
        amount: amount,
        occurredOn: on ?? DateTime(2026, 9, 21),
      );

  setUp(wallet.reset);
  tearDown(wallet.reset);

  test('a credit from the server lands in the balance and the ledger', () {
    expect(wallet.balance, 0);

    wallet.applyReferralEarnings([earning('71', 200)]);

    expect(wallet.balance, 200);
    expect(wallet.entries, hasLength(1));
    expect(wallet.entries.first.label, 'Referral commission');
    expect(wallet.entries.first.amount, 200);
    expect(wallet.entries.first.isCredit, isTrue);
    // A referrer with no plan of their own still has a wallet once paid.
    expect(wallet.isActivated, isTrue);
  });

  test('the same credit read again on the next refresh is not added twice', () {
    wallet.applyReferralEarnings([earning('71', 200)]);
    wallet.applyReferralEarnings([earning('71', 200)]);
    wallet.applyReferralEarnings([earning('71', 200), earning('71', 200)]);

    expect(wallet.balance, 200);
    expect(wallet.entries, hasLength(1));
  });

  test('a later credit adds to it, newest first', () {
    wallet.applyReferralEarnings([earning('71', 200)]);
    wallet.applyReferralEarnings([earning('71', 200), earning('90', 400)]);

    expect(wallet.balance, 600);
    expect(wallet.entries.map((e) => e.amount), [400, 200]);
  });

  test('a zero or negative line is ignored', () {
    wallet.applyReferralEarnings([earning('1', 0), earning('2', -50)]);

    expect(wallet.balance, 0);
    expect(wallet.entries, isEmpty);
  });

  test('listeners hear about a new credit, and only a new one', () {
    var heard = 0;
    void listener() => heard++;
    wallet.addListener(listener);
    addTearDown(() => wallet.removeListener(listener));

    wallet.applyReferralEarnings([earning('71', 200)]);
    expect(heard, 1);

    wallet.applyReferralEarnings([earning('71', 200)]);
    expect(heard, 1);
  });

  test('resetting the wallet forgets what was credited', () {
    wallet.applyReferralEarnings([earning('71', 200)]);
    wallet.reset();
    expect(wallet.balance, 0);

    // A different member signing in on the same device starts from nothing,
    // and their own credit with the same ledger id counts.
    wallet.applyReferralEarnings([earning('71', 200)]);
    expect(wallet.balance, 200);
  });
}
