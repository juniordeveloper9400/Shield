import 'package:flutter/foundation.dart';

import 'backend_http.dart';

/// Backend-mediated identity operations that the compiled-in Neon
/// credential used to answer directly — see
/// `lib/data/neon/member_repository.dart`'s own doc for the path this is
/// replacing, method by method, as each gets a safe backend equivalent.
///
/// Every method here follows that same best-effort contract: a missing
/// `BACKEND_API_BASE_URL` or an unreachable backend never throws out to the
/// caller, it degrades to "answer unknown" (`null`) or "did nothing"
/// (`false`), exactly like `NeonHttp`-backed repositories already do for a
/// missing `DATABASE_URL`.
class BackendMemberRepository {
  BackendMemberRepository._({BackendHttp? http}) : _http = http ?? BackendHttp.instance;

  static final BackendMemberRepository instance = BackendMemberRepository._();

  /// Test-only: an instance wired to an injected [BackendHttp] (typically
  /// [BackendHttp.test] around a `MockClient`), so `phoneExists`/
  /// `deleteAccount`'s own logic can be exercised without a live backend.
  @visibleForTesting
  factory BackendMemberRepository.test({required BackendHttp http}) =>
      BackendMemberRepository._(http: http);

  final BackendHttp _http;

  bool get isAvailable => _http.isEnabled;

  /// Whether [phone] already has a live account — the login screen's
  /// pre-OTP "sign in" vs. "create account" check (see
  /// `AuthService.hasAccount`'s own doc). This has to run *before* an OTP
  /// is ever requested, so unlike every other identity operation in this
  /// app it cannot wait for Firebase verification first — it is
  /// deliberately the one auth route that answers an unauthenticated
  /// caller's question about a phone number.
  ///
  /// `member-auth.controller.ts`'s `AuthThrottle` (10/min/IP) is what makes
  /// that an acceptable trade rather than an open enumeration endpoint: it
  /// is strictly *tighter* than what the compiled-in Neon credential this
  /// replaces already allowed — unlimited, unthrottled raw SQL to the same
  /// question, from anyone who extracted it from the binary.
  ///
  /// Null when the backend could not answer (not configured at build time,
  /// unreachable, or a genuine server error) — never a guess.
  Future<bool?> phoneExists(String phone) async {
    if (!isAvailable) {
      return null;
    }
    try {
      final result = await _http.request(
        'POST',
        '/v1/member/auth/phone-lookup',
        body: {'phone': phone},
        auth: false,
      ) as Map<String, dynamic>;
      return result['exists'] as bool?;
    } catch (error) {
      BackendHttp.log('phoneExists failed', error: error);
      return null;
    }
  }

  /// Permanently deletes the signed-in member's account server-side — see
  /// `identity.service.ts`'s `deleteAccount` for exactly what gets cleared
  /// (soft-deleted, personal fields wiped, every live session revoked).
  /// Requires a live backend session ([BackendHttp.isSignedIn]); returns
  /// `false` without throwing when there is none — `AuthService.deleteAccount`
  /// falls back to the Neon-direct delete in that case rather than leaving
  /// the member stuck on a request that can never succeed.
  Future<bool> deleteAccount() async {
    if (!_http.isSignedIn) {
      return false;
    }
    try {
      await _http.request('DELETE', '/v1/member/me');
      return true;
    } catch (error) {
      BackendHttp.log('deleteAccount failed', error: error);
      return false;
    }
  }
}
