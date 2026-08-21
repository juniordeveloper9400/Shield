import 'package:flutter/foundation.dart';

/// A signed-in member.
///
/// Identity is the mobile number: it is what the code was sent to, and it is
/// what a real backend would key the account on. The name is what the member
/// typed on the way in and is only ever used for display.
@immutable
class AuthUser {
  final String name;
  final String phone;

  const AuthUser({required this.name, required this.phone});

  /// One or two letters for the avatar circle.
  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }

  /// `+91 9876543210` — the form the account and menu screens show.
  String get displayPhone => '+91 $phone';
}

/// Why a step of the OTP flow was rejected.
enum OtpError { invalidName, invalidPhone, noPendingRequest, wrongOtp }

/// In-memory, OTP-based authentication.
///
/// SECURITY: [demoOtp] is compiled into the app bundle and accepts every
/// verification, so this class must never stand in for a real gateway. It
/// exists so the sign-in flow can be exercised before an SMS provider is
/// wired in, and it is expected to be replaced wholesale by API calls —
/// [requestOtp] becoming the send call and [verifyOtp] the verify call.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// The only code the stand-in gateway accepts.
  static const String demoOtp = '123456';

  /// Digits in a code. The OTP field draws this many boxes.
  static const int otpLength = 6;

  /// How long the member waits before a resend is offered.
  static const Duration resendCooldown = Duration(seconds: 30);

  /// Null while signed out. Widgets listen to this to decide what to show.
  final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);

  /// Set between [requestOtp] and [verifyOtp] — the half-finished sign-in.
  _PendingLogin? _pending;

  bool get isSignedIn => currentUser.value != null;

  /// True once a code has been sent and not yet verified or abandoned.
  bool get hasPendingOtp => _pending != null;

  String? get pendingName => _pending?.name;

  String? get pendingPhone => _pending?.phone;

  /// Null when [value] is usable as a name, otherwise the reason it is not.
  static String? validateName(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Name is required';
    }
    if (text.length < 2) {
      return 'Enter at least 2 characters';
    }
    if (!RegExp(r"^[A-Za-z][A-Za-z .'-]*$").hasMatch(text)) {
      return 'Use letters only';
    }
    return null;
  }

  /// Null when [value] is a plausible Indian mobile number.
  static String? validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Mobile number is required';
    }
    if (text.length != 10 || int.tryParse(text) == null) {
      return 'Enter a valid 10-digit number';
    }
    if (!RegExp(r'^[6-9]').hasMatch(text)) {
      return 'Mobile numbers start with 6-9';
    }
    return null;
  }

  /// "Sends" a code to [phone] and holds the details until it is verified.
  /// Returns null when the code went out.
  OtpError? requestOtp({required String name, required String phone}) {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    if (validateName(cleanName) != null) {
      return OtpError.invalidName;
    }
    if (validatePhone(cleanPhone) != null) {
      return OtpError.invalidPhone;
    }

    _pending = _PendingLogin(name: cleanName, phone: cleanPhone);
    return null;
  }

  /// Signs the pending member in when [code] matches. Returns null on success.
  OtpError? verifyOtp(String code) {
    final pending = _pending;
    if (pending == null) {
      return OtpError.noPendingRequest;
    }
    if (code.trim() != demoOtp) {
      return OtpError.wrongOtp;
    }

    _pending = null;
    currentUser.value = AuthUser(name: pending.name, phone: pending.phone);
    return null;
  }

  /// Drops the half-finished sign-in — the member went back to edit details.
  void cancelOtp() => _pending = null;

  void logOut() {
    _pending = null;
    currentUser.value = null;
  }

  /// Test hook: puts a member straight into the session, skipping the round
  /// trip, so tests of other screens do not have to drive the whole flow.
  @visibleForTesting
  void signInAs({String name = 'Rahul Nair', String phone = '9000000002'}) {
    _pending = null;
    currentUser.value = AuthUser(name: name.trim(), phone: phone.trim());
  }

  /// Test hook: back to a signed-out session with nothing pending.
  @visibleForTesting
  void reset() {
    _pending = null;
    currentUser.value = null;
  }
}

class _PendingLogin {
  final String name;
  final String phone;

  const _PendingLogin({required this.name, required this.phone});
}
