import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/backend/backend_http.dart';
import '../../data/backend/referral_repository.dart';
import '../auth/auth_service.dart';
import '../wallet/wallet_service.dart';
import 'referral_level.dart';

enum ReferralStatus { idle, loading, ready, error }

/// The signed-in member's refer-and-earn standing, read through
/// `backend/api`'s `/v1/member/referrals/*` routes (see [ReferralRepository]).
///
/// Mirrors [RewardsService]: one figure kept once, so the home card and the
/// refer & earn screen read the same real numbers rather than each carrying
/// its own guess. [attach] wires it to the auth session; call it once from
/// `main()`.
class ReferralService extends ChangeNotifier {
  ReferralService._();

  static final ReferralService instance = ReferralService._();

  ReferralStatus _status = ReferralStatus.idle;
  ReferralStatus get status => _status;
  bool get isLoading => _status == ReferralStatus.loading;
  bool get isConfigured => BackendHttp.isConfigured;

  ReferralProgress _progress = const ReferralProgress(directReferrals: 0);

  /// The member's real standing. Zeroed while signed out or before the first
  /// load — never the sample fixture, which is for tests and the widget
  /// gallery only.
  ReferralProgress get progress => _progress;

  String? _code;

  /// The member's real invite code once it has loaded; empty until then, and
  /// on a build with no database. Never a stand-in that looks real: a
  /// placeholder, once shared or shown as the member's ID, belongs to nobody.
  /// The code card and the Invite button read an empty code as "not ready".
  String get code => _code ?? '';

  String? _phone;
  bool _attached = false;
  Future<void>? _inFlight;

  /// Follow the auth session: (re)load on sign-in, clear on sign-out. Safe to
  /// call more than once.
  void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    AuthService.instance.currentUser.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final phone = AuthService.instance.currentUser.value?.phone;
    if (phone == _phone) {
      return;
    }
    _phone = phone;
    if (phone == null) {
      _progress = const ReferralProgress(directReferrals: 0);
      _code = null;
      _status = ReferralStatus.idle;
      _inFlight = null;
      notifyListeners();
    } else {
      unawaited(refresh());
    }
  }

  /// Loads the standing for the signed-in member if not already loaded. A
  /// no-op while signed out.
  Future<void> ensureLoaded() {
    if (_phone == null || _status == ReferralStatus.ready) {
      return Future.value();
    }
    return _inFlight ??= _load();
  }

  /// Re-reads the standing now (after a referral lands, or pull-to-refresh).
  Future<void> refresh() {
    _inFlight = null;
    return _inFlight ??= _load();
  }

  Future<void> _load() async {
    final phone = _phone;
    if (phone == null) {
      _status = ReferralStatus.idle;
      _inFlight = null;
      notifyListeners();
      return;
    }
    if (!BackendHttp.isConfigured) {
      _status = ReferralStatus.error;
      _inFlight = null;
      notifyListeners();
      return;
    }
    _status = ReferralStatus.loading;
    notifyListeners();
    try {
      final code = await ReferralRepository.instance.ensureCodeFor(phone);
      final progress = await ReferralRepository.instance.progressFor(phone);
      final earnedBefore = _progress.sahakarMoney;
      if (code != null) _code = code;
      if (progress != null) _progress = progress;
      // Sahakar money is credited to the wallet on the server the moment a
      // friend's plan is approved; when the figure moves, bring the wallet's
      // balance and ledger up to date so the two screens agree.
      if (progress != null && progress.sahakarMoney != earnedBefore) {
        unawaited(WalletService.instance.refreshFromDatabase(phone));
      }
      _status = progress == null ? ReferralStatus.error : ReferralStatus.ready;
    } catch (error) {
      BackendHttp.log('ReferralService load failed', error: error);
      _status = ReferralStatus.error;
    } finally {
      _inFlight = null;
      notifyListeners();
    }
  }

  // ---- writes ------------------------------------------------------

  /// Resolves a code entered into the "Referral ID" field on the
  /// registration form — right after [RegistrationService.save], on a
  /// first-time registration or an edit alike. One backend call now covers
  /// both the member-referral and the agent-direct-sale path a code could
  /// resolve to (see [ReferralRepository.applyCode]'s own doc); this used
  /// to be two separate direct-Neon writes (this, plus
  /// `AgentCustomerRepository.linkCustomer`), tried alongside each other
  /// from the registration screen.
  ///
  /// Best-effort and silent either way: a bad, self-used or already-spent
  /// code must not stop the registration it rode in on.
  Future<void> applyCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await ReferralRepository.instance.applyCode(trimmed);
  }

  // ---- test hooks --------------------------------------------------

  /// Puts [progress] (and, optionally, [code]) straight in, as if a load had
  /// completed — for widget tests, which have no database.
  @visibleForTesting
  void debugSet(ReferralProgress progress, {String? code}) {
    _phone = AuthService.instance.currentUser.value?.phone ?? 'test';
    _progress = progress;
    if (code != null) {
      _code = code;
    }
    _status = ReferralStatus.ready;
    _inFlight = null;
    notifyListeners();
  }

  /// Back to the unloaded state.
  @visibleForTesting
  void debugReset() {
    _phone = null;
    _progress = const ReferralProgress(directReferrals: 0);
    _code = null;
    _status = ReferralStatus.idle;
    _inFlight = null;
    notifyListeners();
  }
}
