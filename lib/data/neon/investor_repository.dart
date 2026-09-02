import '../../module/investor/investor_model.dart';
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
