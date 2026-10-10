import 'package:flutter/foundation.dart';

import '../../data/backend/backend_http.dart';
import '../auth/auth_service.dart' show OtpError;
import '../auth/msg91_widget_otp.dart' as widget_otp;

/// Proves the agent-registration form's recruit owns the phone number they
/// gave, via `backend/api`'s MSG91-backed `/v1/agent/otp/*` endpoints
/// (member-authenticated — the recruiting agent's own session carries the
/// call) — never signs anyone in, same contract as the Firebase-based
/// version this replaces.
///
/// Delegates the actual network calls to an [AgentOtpTransport] so tests can
/// inject [AgentOtpTransport] fakes with [useTransport] instead of a live
/// backend.
class AgentPhoneVerifier {
  AgentPhoneVerifier._();

  static final AgentPhoneVerifier instance = AgentPhoneVerifier._();

  AgentOtpTransport _transport = _defaultAgentOtpTransport();

  /// Whether a code has been sent and not yet confirmed or discarded.
  bool _pending = false;

  bool get hasPendingCode => _pending;

  /// The backend's own `reason` string behind the most recent failure, or
  /// null — appended to the "not set up" line so a support screenshot names
  /// the exact thing to fix.
  String? _lastDiagnostic;

  String? get lastDiagnostic => _lastDiagnostic;

  String? _phone;

  /// Sends an SMS code to [e164Phone] (`+91XXXXXXXXXX`). Returns null once it
  /// is on its way, otherwise the reason it did not go out.
  Future<OtpError?> sendCode(String e164Phone) async {
    _lastDiagnostic = null;
    final result = await _transport.sendCode(e164Phone);
    if (result.failure == null) {
      _phone = e164Phone;
      _pending = true;
    } else {
      _lastDiagnostic = result.diagnostic;
    }
    return result.failure;
  }

  /// Checks [code] against the last [sendCode]. Returns null when it
  /// matches.
  Future<OtpError?> confirmCode(String code) async {
    final phone = _phone;
    if (!_pending || phone == null) {
      return OtpError.noPendingRequest;
    }
    final result = await _transport.confirmCode(phone, code.trim());
    if (result.failure == null) {
      _pending = false;
      _phone = null;
    } else {
      _lastDiagnostic = result.diagnostic;
    }
    return result.failure;
  }

  /// Drops the half-finished check — the recruiter went back to edit details.
  void discard() {
    _pending = false;
    _phone = null;
  }

  /// Test hook: run send/confirm against [transport] — an in-memory fake —
  /// instead of the real backend.
  @visibleForTesting
  void useTransport(AgentOtpTransport transport) {
    _transport = transport;
  }

  /// Test hook: forget any injected transport and pending state.
  @visibleForTesting
  void reset() {
    _transport = _defaultAgentOtpTransport();
    _pending = false;
    _phone = null;
    _lastDiagnostic = null;
  }
}

/// On web, MSG91's JS widget; everywhere else, the backend-direct calls
/// that currently cannot send a code at all — see
/// `auth_service.dart`'s `_defaultTransport` for the member-login
/// equivalent of this same split and why.
AgentOtpTransport _defaultAgentOtpTransport() =>
    kIsWeb ? WidgetAgentOtpTransport() : BackendAgentOtpTransport();

/// A send or confirm attempt's outcome: null [failure] on success, otherwise
/// the [OtpError] category plus the raw-ish [diagnostic] line to show
/// alongside it.
@immutable
class AgentOtpOutcome {
  final OtpError? failure;
  final String? diagnostic;

  const AgentOtpOutcome.success() : failure = null, diagnostic = null;

  const AgentOtpOutcome.failed(this.failure, [this.diagnostic]);
}

/// The send/verify half of [AgentPhoneVerifier], swapped between the real
/// backend call and an in-memory stand-in for tests.
abstract class AgentOtpTransport {
  Future<AgentOtpOutcome> sendCode(String e164Phone);
  Future<AgentOtpOutcome> confirmCode(String e164Phone, String code);
}

/// Calls `backend/api`'s `/v1/agent/otp/send-msg91` and `/verify-msg91` —
/// see `backend/api/src/modules/otp/agent-otp.controller.ts` and
/// `otp.service.ts` for the MSG91 side of this.
class BackendAgentOtpTransport implements AgentOtpTransport {
  BackendAgentOtpTransport({BackendHttp? http}) : _http = http ?? BackendHttp.instance;

  final BackendHttp _http;

  @override
  Future<AgentOtpOutcome> sendCode(String e164Phone) async {
    if (!_http.isEnabled) {
      return const AgentOtpOutcome.failed(OtpError.unavailable);
    }
    try {
      final result = await _http.request(
        'POST',
        '/v1/agent/otp/send-msg91',
        body: {'phone': e164Phone},
      ) as Map<String, dynamic>;
      if (result['ok'] == true) {
        return const AgentOtpOutcome.success();
      }
      return AgentOtpOutcome.failed(OtpError.configError, result['reason'] as String?);
    } on BackendHttpException catch (error) {
      BackendHttp.log('AgentPhoneVerifier.sendCode failed', error: error);
      return AgentOtpOutcome.failed(
        error.isTooManyRequests ? OtpError.tooManyRequests : OtpError.network,
      );
    } catch (error) {
      BackendHttp.log('AgentPhoneVerifier.sendCode failed', error: error);
      return const AgentOtpOutcome.failed(OtpError.network);
    }
  }

  @override
  Future<AgentOtpOutcome> confirmCode(String e164Phone, String code) async {
    if (!_http.isEnabled) {
      return const AgentOtpOutcome.failed(OtpError.unavailable);
    }
    try {
      final result = await _http.request(
        'POST',
        '/v1/agent/otp/verify-msg91',
        body: {'phone': e164Phone, 'code': code},
      ) as Map<String, dynamic>;
      if (result['ok'] == true) {
        return const AgentOtpOutcome.success();
      }
      return AgentOtpOutcome.failed(OtpError.wrongOtp, result['reason'] as String?);
    } on BackendHttpException catch (error) {
      BackendHttp.log('AgentPhoneVerifier.confirmCode failed', error: error);
      return AgentOtpOutcome.failed(
        error.isTooManyRequests ? OtpError.tooManyRequests : OtpError.network,
      );
    } catch (error) {
      BackendHttp.log('AgentPhoneVerifier.confirmCode failed', error: error);
      return const AgentOtpOutcome.failed(OtpError.network);
    }
  }
}

/// Runs MSG91's own JS widget (web only — see `msg91_widget_otp.dart`'s own
/// doc on the native gap) to send/verify the code, then has the backend
/// confirm the resulting access-token server-side
/// (`/v1/agent/otp/verify-widget`) before treating the recruit's phone as
/// proven — the token alone, client-side, proves nothing. Used instead of
/// [BackendAgentOtpTransport] because MSG91's Widget product has no real
/// server-to-server "send": see
/// `backend/api/src/modules/otp/otp.service.ts`'s own doc on why
/// `sendMsg91Otp`/`verifyMsg91Otp` (what [BackendAgentOtpTransport] calls)
/// turned out not to be a supported flow at all.
class WidgetAgentOtpTransport implements AgentOtpTransport {
  WidgetAgentOtpTransport({BackendHttp? http}) : _http = http ?? BackendHttp.instance;

  final BackendHttp _http;

  /// MSG91 identifiers are plain digits, country-code-prefixed, no `+`.
  String _identifierFor(String e164Phone) => e164Phone.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Future<AgentOtpOutcome> sendCode(String e164Phone) async {
    try {
      await widget_otp.sendWidgetOtp(_identifierFor(e164Phone));
      return const AgentOtpOutcome.success();
    } on UnsupportedError catch (error) {
      BackendHttp.log('AgentPhoneVerifier.sendCode (widget) failed', error: error);
      return const AgentOtpOutcome.failed(OtpError.unavailable);
    } catch (error) {
      BackendHttp.log('AgentPhoneVerifier.sendCode (widget) failed', error: error);
      return AgentOtpOutcome.failed(OtpError.unknown, error is StateError ? error.message : null);
    }
  }

  @override
  Future<AgentOtpOutcome> confirmCode(String e164Phone, String code) async {
    final String accessToken;
    try {
      accessToken = await widget_otp.verifyWidgetOtp(code);
    } on UnsupportedError catch (error) {
      BackendHttp.log('AgentPhoneVerifier.confirmCode (widget) failed', error: error);
      return const AgentOtpOutcome.failed(OtpError.unavailable);
    } catch (error) {
      BackendHttp.log('AgentPhoneVerifier.confirmCode (widget) failed', error: error);
      return AgentOtpOutcome.failed(OtpError.wrongOtp, error is StateError ? error.message : null);
    }

    if (!_http.isEnabled) {
      return const AgentOtpOutcome.failed(OtpError.unavailable);
    }
    try {
      final result = await _http.request(
        'POST',
        '/v1/agent/otp/verify-widget',
        body: {'accessToken': accessToken, 'expectedPhone': e164Phone},
      ) as Map<String, dynamic>;
      if (result['ok'] == true) {
        return const AgentOtpOutcome.success();
      }
      return AgentOtpOutcome.failed(OtpError.wrongOtp, result['reason'] as String?);
    } on BackendHttpException catch (error) {
      BackendHttp.log('AgentPhoneVerifier.confirmCode (widget) failed', error: error);
      return AgentOtpOutcome.failed(
        error.isTooManyRequests ? OtpError.tooManyRequests : OtpError.network,
      );
    } catch (error) {
      BackendHttp.log('AgentPhoneVerifier.confirmCode (widget) failed', error: error);
      return const AgentOtpOutcome.failed(OtpError.network);
    }
  }
}
