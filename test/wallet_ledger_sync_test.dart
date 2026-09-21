import 'package:flutter_test/flutter_test.dart';

import 'package:shield/data/neon/wallet_repository.dart';
import 'package:shield/module/wallet/wallet_service.dart';

/// The wallet's balance and "Transaction history" are read back from the real
/// `app.wallet_entry` ledger, not kept as a running local total — see
/// `WalletService.applyRemoteWallet`'s own doc. A row for an order only
/// exists there once the database has actually moved money for it: at
/// checkout for a standard order paid by wallet, or, for a prescription
/// order, only once the store has billed it and staff have collected it with
/// the member's OTP. These tests exercise the app's side of that: applying
/// whatever the ledger read back says, the same way `MemberEarnings` is
/// always read fresh off the real order list rather than kept locally.
void main() {
  final wallet = WalletService.instance;

  RemoteWalletEntry entry({
    String kind = '',
    required String label,
    required int amount,
    DateTime? on,
  }) => RemoteWalletEntry(
    kind: kind,
    label: label,
    amount: amount,
    occurredOn: on ?? DateTime(2026, 9, 21),
  );

  setUp(wallet.reset);
  tearDown(wallet.reset);

  test('an order the wallet paid at checkout is a debit line', () {
    wallet.applyRemoteWallet(const RemoteWallet(balance: 1600), [
      entry(kind: 'SPEND', label: 'Order SHD-100512', amount: -400),
    ]);

    expect(wallet.balance, 1600);
    expect(wallet.entries, hasLength(1));
    expect(wallet.entries.first.label, 'Order SHD-100512');
    expect(wallet.entries.first.amount, -400);
    expect(wallet.entries.first.isCredit, isFalse);
  });

  test(
    'a prescription order is not a wallet transaction until the ledger actually carries it',
    () {
      // The order exists and is being processed, but nothing has been billed
      // or OTP-collected yet — the real ledger has nothing for it, so nothing
      // shows in the wallet.
      wallet.applyRemoteWallet(const RemoteWallet(balance: 2000), []);
      expect(wallet.entries, isEmpty);

      // The store bills it and staff collect it with the member's OTP — the
      // database has now written the SPEND row, and the next refresh shows it.
      wallet.applyRemoteWallet(const RemoteWallet(balance: 1550), [
        entry(kind: 'SPEND', label: 'Order SHD-100513', amount: -450),
      ]);

      expect(wallet.balance, 1550);
      expect(wallet.entries.single.label, 'Order SHD-100513');
      expect(wallet.entries.single.amount, -450);
    },
  );

  test('every kind the ledger carries is shown: activation, bonus, referral, agent, spend', () {
    wallet.applyRemoteWallet(const RemoteWallet(balance: 12100), [
      entry(kind: 'SPEND', label: 'Order SHD-100514', amount: -900),
      entry(kind: 'AGENT_EARNINGS', label: 'Commission moved in', amount: 500),
      entry(kind: 'REFERRAL_EARNINGS', label: 'Referral commission', amount: 200),
      entry(kind: 'BONUS', label: 'Silver bonus · 10%', amount: 1000),
      entry(kind: 'ACTIVATION', label: 'Silver activation', amount: 10000),
      entry(kind: 'AGENT_EARNINGS', label: 'Commission moved in', amount: 1300),
    ]);

    expect(wallet.balance, 12100);
    expect(wallet.entries.map((e) => e.kind), [
      'SPEND',
      'AGENT_EARNINGS',
      'REFERRAL_EARNINGS',
      'BONUS',
      'ACTIVATION',
      'AGENT_EARNINGS',
    ]);
  });

  test('a refresh replaces the ledger rather than appending to it', () {
    wallet.applyRemoteWallet(const RemoteWallet(balance: 1000), [
      entry(label: 'First refresh', amount: 1000),
    ]);
    expect(wallet.entries, hasLength(1));

    // The next refresh is the whole truth again, not an addition to what was
    // already shown — a page reload or a restart must read the same total
    // either way.
    wallet.applyRemoteWallet(const RemoteWallet(balance: 600), [
      entry(label: 'Order SHD-100515', amount: -400),
      entry(label: 'First refresh', amount: 1000),
    ]);

    expect(wallet.balance, 600);
    expect(wallet.entries, hasLength(2));
  });

  test('local activity is superseded once the real ledger is read back', () {
    // A card is approved while the member is looking at the screen: the
    // optimistic local credit shows straight away…
    wallet.creditEarnings(amount: 500, label: 'Agent earnings added');
    expect(wallet.balance, 500);

    // …then the next refresh reconciles to whatever the database actually
    // holds — here, the same 500 plus an order already paid from it.
    wallet.applyRemoteWallet(const RemoteWallet(balance: 100), [
      entry(kind: 'SPEND', label: 'Order SHD-100516', amount: -400),
      entry(kind: 'AGENT_EARNINGS', label: 'Agent earnings added', amount: 500),
    ]);

    expect(wallet.balance, 100);
    expect(wallet.entries, hasLength(2));
  });

  test('a failed or unconfigured read changes nothing', () {
    wallet.applyRemoteWallet(const RemoteWallet(balance: 900), [
      entry(label: 'Order SHD-100517', amount: -100),
    ]);

    wallet.applyRemoteWallet(null, null);
    wallet.applyRemoteWallet(const RemoteWallet(balance: 900), null);
    wallet.applyRemoteWallet(null, const []);

    expect(wallet.balance, 900);
    expect(wallet.entries, hasLength(1));
  });

  test('listeners hear about a real refresh, and not about a no-op one', () {
    var heard = 0;
    void listener() => heard++;
    wallet.addListener(listener);
    addTearDown(() => wallet.removeListener(listener));

    wallet.applyRemoteWallet(const RemoteWallet(balance: 100), const []);
    expect(heard, 1);

    wallet.applyRemoteWallet(null, null);
    expect(heard, 1);
  });

  test('resetting the wallet forgets what the ledger said', () {
    wallet.applyRemoteWallet(const RemoteWallet(balance: 500), [
      entry(label: 'Order SHD-100518', amount: -500),
    ]);
    wallet.reset();

    expect(wallet.balance, 0);
    expect(wallet.entries, isEmpty);

    // A different member signing in on the same device starts from their own
    // ledger, read back the same way.
    wallet.applyRemoteWallet(const RemoteWallet(balance: 300), [
      entry(label: 'Order SHD-100519', amount: -300),
    ]);
    expect(wallet.balance, 300);
  });
}
