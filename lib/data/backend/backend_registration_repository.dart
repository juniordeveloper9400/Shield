import 'package:flutter/foundation.dart';

import '../../module/registration/registration_service.dart';
import 'backend_http.dart';

/// Backend-mediated registration save/fetch — `PATCH`/`GET /v1/member/me`,
/// see `identity.service.ts`'s `updateProfile`/`getMemberProfile`.
///
/// Requires a live backend session ([BackendHttp.isSignedIn]) — both routes
/// are member-authenticated, unlike the pre-OTP `phoneExists` route.
/// `lib/module/registration/member_repository.dart` (the class
/// `RegistrationService` actually calls) is a thin pass-through to this —
/// there is no direct-Neon fallback any more (see that file's own doc).
///
/// Ported from `shield agent_invester/lib/data/backend/registration_repository.dart`,
/// trimmed to what `Registration`'s simpler, non-nullable-throwing contract
/// here needs — that app's own `RegistrationLookupStatus`/
/// `RegistrationSaveException` distinctions are handled by the wrapper
/// class instead, so this app's existing, simpler `MemberRepository`
/// interface doesn't have to change shape for every call site.
class BackendRegistrationRepository {
  BackendRegistrationRepository._({BackendHttp? http}) : _http = http ?? BackendHttp.instance;

  static final BackendRegistrationRepository instance = BackendRegistrationRepository._();

  /// Test-only: an instance wired to an injected [BackendHttp].
  @visibleForTesting
  factory BackendRegistrationRepository.test({required BackendHttp http}) =>
      BackendRegistrationRepository._(http: http);

  final BackendHttp _http;

  /// Whether a call would actually reach the backend as this member —
  /// both "backend configured" and "signed in" have to hold, since both
  /// routes are member-authenticated.
  bool get isAvailable => _http.isEnabled && _http.isSignedIn;

  /// Saves [registration]. Throws on any failure (network, refused,
  /// unauthenticated) — the caller's job to catch, not this method's.
  Future<void> upsertRegistration(Registration registration) async {
    await _http.request(
      'PATCH',
      '/v1/member/me',
      body: {
        'name': registration.name,
        if (registration.email.isNotEmpty) 'email': registration.email,
        'gender': registration.gender.name.toUpperCase(),
        'dob': _isoDate(registration.dob),
        'address': registration.address,
        'place': registration.place,
        'pincode': registration.pincode,
        'state': registration.state,
        // A blank PAN is sent as '' — clears it server-side the same way a
        // blank email/address would, rather than leaving a typed-then-
        // deleted value stuck on the account.
        'pan': registration.pan,
        if (registration.storeId.isNotEmpty) 'homeStoreCode': registration.storeId,
      },
    );
  }

  /// Reads the signed-in member's registration back. Returns null when the
  /// backend cleanly says "not registered yet" or the profile is missing a
  /// field the form requires (mirrors
  /// `lib/module/registration/member_repository.dart`'s own `fetchByPhone`
  /// contract exactly) — throws, rather than returning null, on a request
  /// failure, so the wrapper can tell "confirmed not registered" (trust it)
  /// apart from "could not ask" (the wrapper reports not-registered either
  /// way, but the distinction is here to use if a caller ever needs it).
  Future<Registration?> fetchByPhone(String phone) async {
    final me = await _http.request('GET', '/v1/member/me') as Map<String, dynamic>;
    if (me['registrationCompletedAt'] == null) {
      return null;
    }

    final storeCode = (me['homeStoreCode'] as String?)?.trim();
    final dob = me['dob'] as String?;
    // Both are required by the form; either missing means the row is not
    // a usable registration, not something worth surfacing as one.
    if (storeCode == null || storeCode.isEmpty || dob == null) {
      return null;
    }
    final genderName = (me['gender'] as String?)?.toUpperCase();

    return Registration(
      name: (me['name'] as String?) ?? '',
      phone: phone,
      email: (me['email'] as String?) ?? '',
      gender: Gender.values.firstWhere(
        (gender) => gender.name.toUpperCase() == genderName,
        orElse: () => Gender.other,
      ),
      dob: DateTime.parse(dob),
      address: (me['address'] as String?) ?? '',
      place: (me['place'] as String?) ?? '',
      pincode: (me['pincode'] as String?) ?? '',
      state: (me['state'] as String?) ?? '',
      pan: (me['pan'] as String?) ?? '',
      storeId: storeCode,
    );
  }

  /// `1994-09-04` — an unambiguous value for the backend's `dob` field.
  static String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
