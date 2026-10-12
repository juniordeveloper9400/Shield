import '../neon/persona_repository.dart' show PersonaSnapshot, RemoteAgent, RemoteInvestor;
import 'backend_http.dart';

/// Reads a signed-in member's persona through `backend/api` — whether the
/// Super Admin has made them an agent (`GET /v1/agent/me`) or an investor
/// (`GET /v1/investor/me`) — never a direct Neon connection. This used to
/// run three raw queries against `app.users`/`app.agent`/`app.investor`
/// with the compiled-in database credential (see
/// `lib/data/neon/persona_repository.dart`'s own doc); that credential is
/// gone now.
///
/// The "has an admin deleted this account" check reads `GET /v1/member/me`
/// directly: the backend 404s once `deleted_at` is set
/// (`identity.service.ts`'s `getMemberProfile`), checked first, same as
/// the old direct-Neon `_isDeleted`, since a deleted account is blocked
/// regardless of any agent/investor row still sitting under it.
///
/// Best-effort like every other backend repository: an unconfigured
/// backend, a signed-out member, or a network failure all answer
/// [PersonaSnapshot.none] — never a thrown error, so a blip never looks
/// like a deleted account.
class BackendPersonaRepository {
  const BackendPersonaRepository._();

  static const BackendPersonaRepository instance = BackendPersonaRepository._();

  bool get isAvailable => BackendHttp.isConfigured;

  /// The signed-in member's persona. [phone] is accepted for parity with
  /// the old direct-Neon signature and used only to fill [RemoteAgent.phone]
  /// / [RemoteInvestor.phone] when the backend's own row is somehow blank —
  /// every lookup itself is scoped to the signed-in session, not [phone].
  Future<PersonaSnapshot> loadFor(String phone) async {
    if (!BackendHttp.isConfigured || !BackendHttp.instance.isSignedIn) {
      return PersonaSnapshot.none;
    }
    try {
      try {
        await BackendHttp.instance.request('GET', '/v1/member/me');
      } on BackendHttpException catch (error) {
        // A confirmed-gone account (identity.service.ts's getMemberProfile
        // 404s once deleted_at is set) — not a transport failure, so this
        // alone is trusted, same as the old direct-Neon `_isDeleted` was.
        if (error.isNotFound) {
          return PersonaSnapshot.deletedAccount;
        }
        rethrow;
      }
      final agent = await _agentFor(phone);
      final investor = await _investorFor(phone);
      return PersonaSnapshot(agent: agent, investor: investor);
    } catch (error) {
      BackendHttp.log('BackendPersonaRepository.loadFor failed', error: error);
      return PersonaSnapshot.none;
    }
  }

  Future<RemoteAgent?> _agentFor(String phone) async {
    try {
      final r = await BackendHttp.instance.request('GET', '/v1/agent/me') as Map<String, dynamic>;
      return RemoteAgent(
        code: (r['code'] ?? '').toString(),
        name: (r['name'] ?? '').toString(),
        phone: (r['phone'] ?? phone).toString(),
        level: (r['level'] ?? 'ward').toString().toLowerCase(),
        active: _bool(r['active'], true),
        area: (r['area'] ?? '').toString(),
        earned: _int(r['earned']),
        redeemed: _int(r['redeemed']),
        personalSales: _int(r['personalSales']),
        parentCode: (r['parentCode'] as Object?)?.toString(),
      );
    } on BackendHttpException catch (error) {
      if (error.isForbidden || error.isNotFound) {
        return null;
      }
      rethrow;
    }
  }

  Future<RemoteInvestor?> _investorFor(String phone) async {
    try {
      final r = await BackendHttp.instance.request('GET', '/v1/investor/me') as Map<String, dynamic>;
      return RemoteInvestor(
        code: (r['code'] ?? '').toString(),
        name: (r['name'] ?? '').toString(),
        phone: (r['phone'] ?? phone).toString(),
        totalUnits: _int(r['totalUnits']),
        unitPrice: _int(r['unitPrice'], 150000),
        investedSince: _date(r['investedSince']) ?? DateTime.now(),
        roiPercent: _double(r['roiPercent']),
        planType: (r['planType'] ?? 'yearly').toString().toLowerCase(),
        storeCode: (r['storeCode'] as Object?)?.toString(),
      );
    } on BackendHttpException catch (error) {
      if (error.isForbidden || error.isNotFound) {
        return null;
      }
      rethrow;
    }
  }

  static int _int(Object? v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return num.tryParse(v?.toString() ?? '')?.toInt() ?? fallback;
  }

  static double _double(Object? v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static bool _bool(Object? v, bool fallback) {
    if (v is bool) return v;
    final s = v?.toString().toLowerCase();
    if (s == 'true' || s == 't' || s == '1') return true;
    if (s == 'false' || s == 'f' || s == '0') return false;
    return fallback;
  }

  static DateTime? _date(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
