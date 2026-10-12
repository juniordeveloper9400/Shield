import 'package:flutter/foundation.dart';

import '../../module/privilege/privilege_tier.dart';
import '../neon/wallet_repository.dart' show RemoteWallet, RemoteWalletCard, RemoteWalletEntry;
import 'backend_http.dart';

/// Submits privilege-card activations to `backend/api` and reads the
/// wallet's balance, ledger and card-approval state back —
/// `POST`/`GET /v1/member/wallet/cards`, `GET /v1/member/wallet`,
/// `GET /v1/member/wallet/entries` (see `wallet.service.ts`).
///
/// Every read/submit method here is best-effort, the same contract as the
/// other backend repositories: an unconfigured backend or an unreachable
/// one makes the call no-op. Submitting a plan must never fail because
/// the backend is down.
///
/// A submitted card lands as `PENDING` and credits nothing. The console
/// approves it — that is where the `ACTIVATION`/`BONUS` ledger lines and
/// the balance move — or rejects it with a note.
///
/// [WalletRepository.recordSpend] (the wallet-side debit at checkout) has
/// no equivalent here: checkout itself (`lib/data/neon/order_repository.dart`)
/// is not migrated to the backend yet, so there is nothing server-side for
/// that one write to call instead — see that method's own doc.
class BackendWalletRepository {
  BackendWalletRepository._({BackendHttp? http}) : _http = http ?? BackendHttp.instance;

  static final BackendWalletRepository instance = BackendWalletRepository._();

  /// Test-only: an instance wired to an injected [BackendHttp].
  @visibleForTesting
  factory BackendWalletRepository.test({required BackendHttp http}) =>
      BackendWalletRepository._(http: http);

  final BackendHttp _http;

  bool get isAvailable => _http.isEnabled;

  /// Set by [submitCardForApproval] right before it returns null for a real
  /// (not unconfigured/unreachable) failure — the backend's own reason,
  /// when it gave one, so the checkout screen can tell "you're being rate
  /// limited, wait an hour" apart from "check your connection and retry
  /// right now," which is actively wrong advice for the first case. Reset
  /// to null at the start of every call, so a stale reason from a previous
  /// attempt can never be read as this one's.
  String? lastSubmitCardError;

  /// The load amounts and bonus rate are already bundled client-side
  /// (`lib/module/privilege/privilege_tier.dart`) — this only needs to
  /// resolve [tierKind] to the numeric id `submitWalletCardSchema`
  /// requires, via the public membership-tiers list (cached — it's
  /// near-static).
  Map<PrivilegeCardKind, int>? _tierIdCache;

  /// Files a privilege-card activation for review.
  ///
  /// [storeCode] is the branch chosen at checkout — the backend resolves
  /// it to a real `app.shield_store` row and stores that on the card, so
  /// the approved plan is served by it (see `wallet.service.ts`'s
  /// `submitCard`). An unknown code is never a reason to fail this
  /// submission — the backend silently drops it, same as an unresolved
  /// [receiptReference]/agent code would be.
  ///
  /// Returns the new card's id (as a string, standing in for the old
  /// row's uuid), or null when nothing was written.
  Future<String?> submitCardForApproval({
    required PrivilegeCardKind tierKind,
    required int amount,
    String? cardNumber,
    String? storeCode,
    String? receiptReference,
    String? receiptFileName,
    String? receiptImage,
  }) async {
    lastSubmitCardError = null;
    if (!isAvailable) {
      return null;
    }
    try {
      final tierId = await _tierIdFor(tierKind);
      if (tierId == null) {
        return null; // reference data not seeded
      }
      final created = await _http.request(
        'POST',
        '/v1/member/wallet/cards',
        body: {
          'tierId': tierId,
          'amount': amount,
          if (cardNumber != null) 'cardNumber': cardNumber,
          if (storeCode != null && storeCode.isNotEmpty) 'storeCode': storeCode,
          if (receiptReference != null) 'receiptReference': receiptReference,
          if (receiptFileName != null) 'receiptFileName': receiptFileName,
          if (receiptImage != null && receiptImage.isNotEmpty) 'receiptImage': receiptImage,
        },
      ) as Map<String, dynamic>;
      return created['id']?.toString();
    } on BackendHttpException catch (error) {
      lastSubmitCardError = error.isTooManyRequests
          ? "You've submitted too many receipts recently — wait an hour "
              'and try again.'
          : null;
      BackendHttp.log('BackendWalletRepository.submitCardForApproval failed', error: error);
      return null;
    } catch (error) {
      BackendHttp.log('BackendWalletRepository.submitCardForApproval failed', error: error);
      return null;
    }
  }

  /// Every privilege card on the member's wallet, oldest first — pending,
  /// approved and rejected. The app merges this into `WalletService` to
  /// reflect what the console has decided. Returns null when nothing
  /// could be read. [memberPhone] is accepted for parity with the old
  /// direct-Neon signature but unused — the backend resolves identity
  /// from the session.
  Future<List<RemoteWalletCard>?> fetchCards({required String memberPhone}) async {
    if (!isAvailable) {
      return null;
    }
    try {
      final tierKindById = await _tierKindsById();
      final rows = await _http.request('GET', '/v1/member/wallet/cards') as List<dynamic>;
      return [
        for (final row in rows.cast<Map<String, dynamic>>())
          if (tierKindById[(row['tierId'] as num).toInt()] case final kind?)
            RemoteWalletCard(
              uuid: row['id'].toString(),
              status: (row['status'] ?? 'PENDING').toString(),
              tierKind: kind,
              amount: _int(row['amount']),
              bonus: _int(row['bonus']),
              rechargedExtra: _int(row['rechargedExtra']),
              storeCode: row['storeCode']?.toString(),
              issuedOn: _date(row['issuedOn']) ?? DateTime.now(),
              expiresOn: _date(row['expiresOn']) ?? DateTime.now(),
              submittedAt: _date(row['submittedAt']) ?? DateTime.now(),
              reviewerNote: (row['reviewerNote'] ?? '').toString(),
            ),
      ];
    } catch (error) {
      BackendHttp.log('BackendWalletRepository.fetchCards failed', error: error);
      return null;
    }
  }

  /// The wallet's real, server-held balance — the source of truth
  /// [WalletService.refreshFromDatabase] hydrates against, in place of the
  /// figure it would otherwise only ever compute from local activity. Null
  /// when the backend is unconfigured or unreachable, same contract as
  /// every other read here. [memberPhone] is accepted for parity with the
  /// old direct-Neon signature but unused.
  Future<RemoteWallet?> fetchWallet({required String memberPhone}) async {
    if (!isAvailable) {
      return null;
    }
    try {
      final row = await _http.request('GET', '/v1/member/wallet') as Map<String, dynamic>;
      return RemoteWallet(balance: _int(row['balance']));
    } catch (error) {
      BackendHttp.log('BackendWalletRepository.fetchWallet failed', error: error);
      return null;
    }
  }

  /// The full ledger behind [fetchWallet]'s balance, newest first — every
  /// top-up, bonus, referral credit and order spend the backend has ever
  /// posted for this member. [memberPhone] is accepted for parity with
  /// the old direct-Neon signature but unused.
  Future<List<RemoteWalletEntry>?> fetchEntries({required String memberPhone}) async {
    if (!isAvailable) {
      return null;
    }
    try {
      final rows = await _http.request('GET', '/v1/member/wallet/entries') as List<dynamic>;
      return [
        for (final row in rows.cast<Map<String, dynamic>>())
          RemoteWalletEntry(
            kind: (row['kind'] ?? '').toString(),
            label: (row['label'] ?? '').toString(),
            amount: _int(row['amount']),
            occurredOn: _date(row['occurredOn']) ?? DateTime.now(),
          ),
      ];
    } catch (error) {
      BackendHttp.log('BackendWalletRepository.fetchEntries failed', error: error);
      return null;
    }
  }

  Future<int?> _tierIdFor(PrivilegeCardKind kind) async {
    final cache = await _ensureTierIdCache();
    return cache[kind];
  }

  Future<Map<int, PrivilegeCardKind>> _tierKindsById() async {
    final byKind = await _ensureTierIdCache();
    return {for (final entry in byKind.entries) entry.value: entry.key};
  }

  Future<Map<PrivilegeCardKind, int>> _ensureTierIdCache() async {
    final cached = _tierIdCache;
    if (cached != null) {
      return cached;
    }
    final rows = await _http.request(
      'GET',
      '/v1/public/catalogue/membership-tiers',
      auth: false,
    ) as List<dynamic>;
    final map = <PrivilegeCardKind, int>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final kind = _kindFor((row['kind'] ?? '').toString());
      final id = row['id'];
      if (kind != null && id != null) {
        map[kind] = (id as num).toInt();
      }
    }
    _tierIdCache = map;
    return map;
  }

  static PrivilegeCardKind? _kindFor(String? token) => switch (token) {
    'SILVER' => PrivilegeCardKind.silver,
    'GOLD' => PrivilegeCardKind.gold,
    'PLATINUM' => PrivilegeCardKind.platinum,
    _ => null,
  };

  static int _int(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = num.tryParse(value?.toString() ?? '');
    return parsed?.toInt() ?? fallback;
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
