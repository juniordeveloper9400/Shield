import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/neon/persona_repository.dart';
import 'auth_service.dart';

/// Where the persona check has got to for the signed-in member.
enum PersonaStatus {
  /// Nobody is signed in, or the check has not started.
  unknown,

  /// A look-up is in flight.
  checking,

  /// Checked — a plain member. The app is theirs to use.
  member,

  /// Checked — the admin console has made them an agent.
  agent,

  /// Checked — the admin console has made them an investor.
  investor,
}

/// Decides whether the signed-in member may use the mobile app at all.
///
/// The admin console (`shieldweb`) can convert a member into an **agent**
/// (`app.agent`) or an **investor** (`app.investor`). Those two personas run
/// their business from the web portal, not the phone — so once a member has
/// been converted the app stops showing them the shop and points them at the
/// web app instead (see `RootScreen` → `PersonaWebOnlyScreen`).
///
/// The check is one best-effort read of [PersonaRepository] per sign-in. It
/// **fails open**: a missing `DATABASE_URL`, a slow network or any error
/// resolves to [PersonaStatus.member], because a transient blip must never
/// lock a real member out of the app.
class PersonaGate extends ChangeNotifier {
  PersonaGate._() {
    AuthService.instance.currentUser.addListener(_onUserChanged);
  }

  static final PersonaGate instance = PersonaGate._();

  /// How long to wait on the look-up before assuming "plain member".
  static const Duration _deadline = Duration(seconds: 6);

  PersonaStatus _status = PersonaStatus.unknown;
  PersonaStatus get status => _status;

  PersonaSnapshot _snapshot = PersonaSnapshot.none;

  /// The agent / investor row behind an [isBlocked] session, for the web-only
  /// screen to name the persona.
  PersonaSnapshot get snapshot => _snapshot;

  /// True once the persona is known — the loading state can end.
  bool get isSettled =>
      _status == PersonaStatus.member ||
      _status == PersonaStatus.agent ||
      _status == PersonaStatus.investor;

  /// True when the signed-in member is an agent or investor and must be sent
  /// to the web app rather than shown the shell.
  bool get isBlocked =>
      _status == PersonaStatus.agent || _status == PersonaStatus.investor;

  /// The phone the current [_status] was resolved for, so a rebuild does not
  /// fire the look-up again and a returning member is re-checked.
  String? _checkedPhone;
  Future<void>? _inFlight;

  /// Bumped whenever the resolved persona is replaced out from under an
  /// in-flight look-up — a sign-out, or a test's [debugSet]. A stale [_check]
  /// compares against this and drops its result instead of overwriting.
  int _generation = 0;

  void _onUserChanged() {
    final user = AuthService.instance.currentUser.value;
    if (user == null) {
      _generation++;
      _checkedPhone = null;
      _inFlight = null;
      _snapshot = PersonaSnapshot.none;
      _set(PersonaStatus.unknown);
      return;
    }
    if (user.phone == _checkedPhone) {
      return;
    }
    unawaited(ensureChecked());
  }

  /// Runs the persona look-up for the signed-in member once. Safe to call from
  /// `main()` and from `RootScreen` — concurrent calls share one request and a
  /// finished check for the same member is a no-op.
  Future<void> ensureChecked() {
    final user = AuthService.instance.currentUser.value;
    if (user == null || user.phone == _checkedPhone) {
      return Future.value();
    }
    return _inFlight ??= _check(user.phone);
  }

  Future<void> _check(String phone) async {
    final generation = _generation;
    _set(PersonaStatus.checking);
    var snapshot = PersonaSnapshot.none;
    try {
      snapshot =
          await PersonaRepository.instance.loadFor(phone).timeout(_deadline);
    } catch (error) {
      // Fail open — a real member must not be shut out by a network blip.
      debugPrint('PersonaGate: check failed, treating as member — $error');
      snapshot = PersonaSnapshot.none;
    } finally {
      _inFlight = null;
    }

    // The member signed out or swapped, or a test forced a persona, while the
    // read was in flight — drop this result rather than overwriting.
    if (_generation != generation ||
        AuthService.instance.currentUser.value?.phone != phone) {
      return;
    }

    _checkedPhone = phone;
    _snapshot = snapshot;
    _set(
      snapshot.isAgent
          ? PersonaStatus.agent
          : snapshot.isInvestor
              ? PersonaStatus.investor
              : PersonaStatus.member,
    );
  }

  void _set(PersonaStatus status) {
    if (_status == status) {
      return;
    }
    _status = status;
    notifyListeners();
  }

  /// Test hook: force a resolved persona for the signed-in member without a
  /// database round trip.
  @visibleForTesting
  void debugSet(
    PersonaStatus status, {
    PersonaSnapshot snapshot = PersonaSnapshot.none,
  }) {
    _generation++;
    _checkedPhone = AuthService.instance.currentUser.value?.phone;
    _inFlight = null;
    _snapshot = snapshot;
    _set(status);
  }

  /// Test hook: back to the unchecked state.
  @visibleForTesting
  void debugReset() {
    _generation++;
    _checkedPhone = null;
    _inFlight = null;
    _snapshot = PersonaSnapshot.none;
    _status = PersonaStatus.unknown;
  }
}
