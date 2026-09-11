import '../../module/investor/investor_model.dart';
import '../../module/registration/shield_store.dart';
import 'neon_http.dart';

/// Writes an investor's return-plan-change request to the `app.investor` and
/// `app.investor_plan_change_request` tables on Neon, over the HTTP SQL
/// endpoint.
///
/// Every method is best-effort: when the app was built without a database URL
/// (tests, a build that left `--dart-define-from-file=.env` off — see
/// [NeonHttp.isConfigured]) or the network is down, the call no-ops rather than
/// throwing. Requesting a switch must never fail because the database is down.
///
/// Goes over [NeonHttp] (HTTPS on 443) so it behaves identically on Android, on
/// Flutter web and in a `--release` build. Neon's `/sql` endpoint runs one
/// statement per request, so the `app.investor` upsert and the request row go
/// in as a single `WITH … INSERT` statement.
///
/// `app.investor_plan_change_request.investor_id` is `NOT NULL`, so
/// [requestPlanChange] upserts the `app.investor` row (keyed on its unique
/// `code`) in the same statement that records the request against it.
class InvestorRepository {
  const InvestorRepository._();

  static const InvestorRepository instance = InvestorRepository._();

  bool get isAvailable => NeonHttp.isConfigured;

  /// Every `app.investor` row — the stakes the admin console has actually
  /// created via "Convert to investor" — or null when the database is
  /// unavailable. [InvestorService.ensureLoaded] swaps these in for the
  /// bundled demo so the home screen's Investor Access card (and "who is
  /// this phone" everywhere else) reflects real conversions.
  Future<List<Investor>?> fetchAll() => _run('fetchAll', () async {
        final rows = await NeonHttp.instance.query(r'''
          SELECT i.id::text, i.code, i.name, i.phone,
                 i.total_units, i.unit_price::text, i.invested_since::text,
                 i.roi_percent::text, i.plan_type::text,
                 s.code AS store_code
          FROM app.investor i
          LEFT JOIN app.shield_store s ON s.id = i.invested_store_id
          ORDER BY i.id
        ''');
        return rows.map(_toInvestor).whereType<Investor>().toList();
      });

  static Investor? _toInvestor(Map<String, dynamic> row) {
    String str(Object? v) => (v ?? '').toString().trim();
    final phone = str(row['phone']);
    final code = str(row['code']);
    if (phone.isEmpty || code.isEmpty) {
      return null;
    }
    final storeCode = str(row['store_code']);
    final store = StoreDirectory.byId(storeCode.isEmpty ? null : storeCode) ??
        StoreDirectory.all.first;
    final since = DateTime.tryParse(str(row['invested_since'])) ?? DateTime.now();
    final planType = str(row['plan_type']).toUpperCase() == 'MONTHLY'
        ? InvestorPlanType.monthly
        : InvestorPlanType.yearly;
    return Investor(
      id: 'db-${str(row['id'])}',
      name: str(row['name']),
      phone: phone,
      investorCode: code,
      investedStore: store,
      totalUnits: int.tryParse(str(row['total_units'])) ?? 0,
      unitPrice: double.tryParse(str(row['unit_price']))?.round() ?? 150000,
      investedSince: since,
      roiPercent: double.tryParse(str(row['roi_percent'])) ?? 0,
      planType: planType,
    );
  }

  /// Records a `REQUESTED` row asking to switch the investor's return plan to
  /// [requestedPlanType], creating or refreshing the `app.investor` row it
  /// hangs off first.
  Future<void> requestPlanChange({
    required String investorCode,
    required String investorName,
    required String investorPhone,
    required InvestorPlanType currentPlanType,
    required InvestorPlanType requestedPlanType,
    String? investedStoreCode,
    required int totalUnits,
    required int unitPrice,
    required DateTime investedSince,
    required double roiPercent,
  }) async {
    await _run('requestPlanChange', () async {
      final since = investedSince.toIso8601String().split('T').first;

      await NeonHttp.instance.query(
        '''
          WITH ins_investor AS (
            INSERT INTO app.investor
              (member_id, code, name, phone, invested_store_id, total_units,
               unit_price, invested_since, roi_percent, plan_type)
            VALUES
              ((SELECT id FROM app.users WHERE phone = \$1),
               \$2, \$3, \$1,
               (SELECT id FROM app.shield_store WHERE code = \$4),
               \$5, \$6, \$7::date, \$8,
               \$9::app.investor_plan_type)
            ON CONFLICT (code) DO UPDATE SET
              name       = EXCLUDED.name,
              phone      = EXCLUDED.phone,
              member_id  = COALESCE(app.investor.member_id, EXCLUDED.member_id),
              updated_at = now()
            RETURNING id
          )
          INSERT INTO app.investor_plan_change_request
            (investor_id, requested_plan_type)
          SELECT id, \$10::app.investor_plan_type FROM ins_investor
        ''',
        [
          investorPhone,
          investorCode,
          investorName,
          investedStoreCode,
          totalUnits,
          unitPrice,
          since,
          roiPercent,
          currentPlanType.name.toUpperCase(),
          requestedPlanType.name.toUpperCase(),
        ],
      );
      return null;
    });
  }

  /// Runs [action], swallowing everything: a missing URL, a network error, a
  /// SQL error. Returns null on any of them.
  Future<T?> _run<T>(String label, Future<T?> Function() action) async {
    if (!NeonHttp.isConfigured) {
      return null;
    }
    try {
      return await action();
    } catch (error) {
      NeonHttp.log('InvestorRepository.$label failed', error: error);
      return null;
    }
  }
}
