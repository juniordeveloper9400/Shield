import 'package:flutter/foundation.dart';

import '../../module/registration/shield_store.dart';
import 'backend_http.dart';

/// Reads the Sahakar 360 branch list, and one branch's live bank details,
/// from `backend/api` — see `catalogue.controller.ts`'s `v1/public/catalogue`
/// routes.
///
/// Split into two gates deliberately: [fetchAll] is a public route (no
/// session needed, matches every visitor browsing the storefront before
/// sign-in), while [fetchBankDetails] requires a live member session — see
/// that route's own doc on why (it would otherwise let a script loop every
/// known branch code and reconstruct the exact bulk bank-details dump
/// [fetchAll] deliberately never carries).
class BackendStoreRepository {
  BackendStoreRepository._({BackendHttp? http}) : _http = http ?? BackendHttp.instance;

  static final BackendStoreRepository instance = BackendStoreRepository._();

  /// Test-only: an instance wired to an injected [BackendHttp].
  @visibleForTesting
  factory BackendStoreRepository.test({required BackendHttp http}) =>
      BackendStoreRepository._(http: http);

  final BackendHttp _http;

  /// Whether [fetchAll] would actually reach the backend.
  bool get isConfigured => _http.isEnabled;

  /// Whether [fetchBankDetails] would actually reach the backend — needs a
  /// live session on top of [isConfigured].
  bool get canFetchBankDetails => _http.isEnabled && _http.isSignedIn;

  /// Every active branch, in the console's display order. `null` when the
  /// backend is unconfigured, unreachable, or the read failed — never an
  /// empty list, so `StoreCatalog` keeps whatever it already has (the seed,
  /// or a Neon-sourced copy) rather than blanking the store picker.
  Future<List<ShieldStore>?> fetchAll() async {
    if (!isConfigured) {
      return null;
    }
    try {
      final rows = await _http.request('GET', '/v1/public/catalogue/stores', auth: false) as List<dynamic>;
      final stores = rows
          .cast<Map<String, dynamic>>()
          .map(ShieldStore.fromJson)
          .whereType<ShieldStore>()
          .toList(growable: false);
      return stores.isEmpty ? null : stores;
    } catch (error) {
      BackendHttp.log('BackendStoreRepository.fetchAll failed', error: error);
      return null;
    }
  }

  /// One active branch's settlement bank account, by its stable [code].
  /// Null when there is no session yet, the backend refused (unknown or
  /// inactive code), or the read failed — the caller falls back to
  /// whatever it already has rather than treating this as "the branch has
  /// no bank details on file" (that's a blank string, not null, on a
  /// successful read).
  Future<Map<String, String>?> fetchBankDetails(String code) async {
    if (!canFetchBankDetails) {
      return null;
    }
    try {
      final result = await _http.request('GET', '/v1/public/catalogue/stores/$code/bank-details') as Map<String, dynamic>;
      return {
        'bankAccountName': (result['bankAccountName'] as String?) ?? '',
        'bankAccountNumber': (result['bankAccountNumber'] as String?) ?? '',
        'bankIfsc': (result['bankIfsc'] as String?) ?? '',
        'bankName': (result['bankName'] as String?) ?? '',
      };
    } catch (error) {
      BackendHttp.log('BackendStoreRepository.fetchBankDetails failed', error: error);
      return null;
    }
  }
}
