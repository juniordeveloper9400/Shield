import 'package:shield/module/auth/auth_service.dart';

/// In-memory stand-in for [FirebaseAuthGateway] so unit and widget tests can
/// drive the sign-in flow without a live Firebase project.
///
/// Inject it in `setUp` with
/// `AuthService.instance.useGateway(FakeAuthGateway())`, then verify with
/// [FakeAuthGateway.code].
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.acceptedCode = code, AuthUser? persistedUser})
      : _persisted = persistedUser;

  /// The one code [confirmCode] treats as correct.
  static const String code = '123456';

  final String acceptedCode;
  bool _sent = false;

  /// Stands in for Firebase's on-device session. Set it via the constructor to
  /// test [AuthService.restoreSession]; [saveDisplayName] updates its name.
  AuthUser? _persisted;

  AuthUser? get persistedUser => _persisted;

  @override
  Future<OtpError?> sendCode(String e164Phone) async {
    _sent = true;
    return null;
  }

  @override
  Future<OtpError?> confirmCode(String smsCode) async {
    if (!_sent) {
      return OtpError.noPendingRequest;
    }
    return smsCode == acceptedCode ? null : OtpError.wrongOtp;
  }

  @override
  Future<AuthUser?> restoreUser() async => _persisted;

  @override
  Future<void> saveDisplayName(String name) async {
    final current = _persisted;
    if (current != null) {
      _persisted = AuthUser(name: name.trim(), phone: current.phone);
    }
  }

  @override
  void discard() => _sent = false;

  @override
  Future<void> signOut() async {
    _sent = false;
    _persisted = null;
  }
}
