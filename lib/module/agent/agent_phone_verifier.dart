import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../auth/auth_service.dart';

/// Real Firebase Phone Auth for the agent-registration form — the same SMS
/// code flow the member sign-in runs, but only to *prove the recruit owns
/// the number*, never to sign anyone in.
///
/// It runs on a **secondary** Firebase app (`agentPhoneVerify`) so
/// `signInWithCredential` — how the client SDK checks an SMS code — lands on
/// an isolated auth instance and leaves the recruiter's own session on the
/// default app untouched. The secondary session is signed straight back out
/// once the code has been confirmed.
///
/// Reuses [FirebaseAuthGateway] for all the reCAPTCHA / timeout / typed-error
/// handling; tests inject a [FakeAuthGateway] with [useGateway] instead.
class AgentPhoneVerifier {
  AgentPhoneVerifier._();

  static final AgentPhoneVerifier instance = AgentPhoneVerifier._();

  /// The name of the isolated Firebase app the phone check runs on.
  static const String _appName = 'agentPhoneVerify';

  AuthGateway? _gateway;
  Future<AuthGateway?>? _buildInFlight;

  /// Whether a code has been sent and not yet confirmed or discarded.
  bool _pending = false;

  bool get hasPendingCode => _pending;

  /// The raw Firebase code behind the most recent config failure, or null —
  /// appended to the "not set up" line so a support screenshot names the
  /// exact console setting to fix.
  String? get lastDiagnostic {
    final gateway = _gateway;
    return gateway is FirebaseAuthGateway ? gateway.lastDiagnostic : null;
  }

  /// Builds (once) the gateway bound to the secondary Firebase app. Returns
  /// null when Firebase is not available on this build — the caller surfaces
  /// that as [OtpError.unavailable].
  Future<AuthGateway?> _activeGateway() {
    final existing = _gateway;
    if (existing != null) {
      return Future<AuthGateway?>.value(existing);
    }
    return _buildInFlight ??= _build();
  }

  Future<AuthGateway?> _build() async {
    try {
      FirebaseApp app;
      try {
        app = Firebase.app(_appName);
      } on FirebaseException {
        app = await Firebase.initializeApp(
          name: _appName,
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final gateway = FirebaseAuthGateway(
        auth: fb.FirebaseAuth.instanceFor(app: app),
      );
      _gateway = gateway;
      return gateway;
    } catch (error) {
      debugPrint('AgentPhoneVerifier: secondary Firebase app unavailable — '
          '$error');
      return null;
    } finally {
      _buildInFlight = null;
    }
  }

  /// Sends an SMS code to [e164Phone] (`+91XXXXXXXXXX`). Returns null once it
  /// is on its way, otherwise the reason it did not go out.
  Future<OtpError?> sendCode(String e164Phone) async {
    final gateway = await _activeGateway();
    if (gateway == null) {
      return OtpError.unavailable;
    }
    final OtpError? failure;
    try {
      failure = await gateway.sendCode(e164Phone);
    } catch (error) {
      debugPrint('AgentPhoneVerifier.sendCode: $error');
      return OtpError.unavailable;
    }
    if (failure == null) {
      _pending = true;
    }
    return failure;
  }

  /// Checks [code] against the last [sendCode]. Returns null when it matches;
  /// signs the isolated session straight back out on success so nothing
  /// lingers on the secondary app.
  Future<OtpError?> confirmCode(String code) async {
    if (!_pending) {
      return OtpError.noPendingRequest;
    }
    final gateway = await _activeGateway();
    if (gateway == null) {
      return OtpError.unavailable;
    }
    final OtpError? failure;
    try {
      failure = await gateway.confirmCode(code.trim());
    } catch (error) {
      debugPrint('AgentPhoneVerifier.confirmCode: $error');
      return OtpError.unavailable;
    }
    if (failure == null) {
      _pending = false;
      unawaited(_signOutQuietly(gateway));
    }
    return failure;
  }

  Future<void> _signOutQuietly(AuthGateway gateway) async {
    try {
      await gateway.signOut();
    } catch (error) {
      debugPrint('AgentPhoneVerifier: secondary sign-out failed — $error');
    }
  }

  /// Drops the half-finished check — the recruiter went back to edit details.
  void discard() {
    _pending = false;
    _gateway?.discard();
  }

  /// Test hook: run send/confirm against [gateway] — an in-memory fake — so
  /// the flow can be exercised without a live Firebase project or a second
  /// Firebase app.
  @visibleForTesting
  void useGateway(AuthGateway gateway) {
    _gateway = gateway;
    _buildInFlight = null;
  }

  /// Test hook: forget any gateway and pending state.
  @visibleForTesting
  void reset() {
    _gateway = null;
    _buildInFlight = null;
    _pending = false;
  }
}
