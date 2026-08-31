import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import '../../module/investor/investor_model.dart';
import 'neon_database.dart';

/// Writes an investor's return-plan-change request to the `app.investor` and
/// `app.investor_plan_change_request` tables on Neon.
///
/// Mirrors [MemberRepository] / [PatientRepository]: every method is
/// best-effort. When the app was built without a `DATABASE_URL` (tests, a
/// public release, Flutter web) or the database is unreachable, the call
/// no-ops and returns rather than throwing. Requesting a switch must never
/// fail because the database is down.
///
/// `app.investor_plan_change_request.investor_id` is `NOT NULL`, so
/// [requestPlanChange] upserts the `app.investor` row (keyed on its unique
/// `code`) before recording the request against it.
class InvestorRepository {
  const InvestorRepository._();

  static const InvestorRepository instance = InvestorRepository._();

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
    await _run('requestPlanChange', (conn) async {
      final since = investedSince.toIso8601String().split('T').first;

      await conn.runTx((tx) async {
        // 1 · The investor row this request belongs to. Linked to the member
        // row for the same phone when one exists; keyed on the unique code so
        // a repeat request updates rather than duplicates.
        final investorRows = await tx.execute(
          Sql.named('''
            INSERT INTO app.investor
              (member_id, code, name, phone, invested_store_id, total_units,
               unit_price, invested_since, roi_percent, plan_type)
            VALUES
              ((SELECT id FROM app.member WHERE phone = @phone),
               @code, @name, @phone,
               (SELECT id FROM app.shield_store WHERE code = @store),
               @units, @price, @since::date, @roi,
               @current::app.investor_plan_type)
            ON CONFLICT (code) DO UPDATE SET
              name      = EXCLUDED.name,
              phone     = EXCLUDED.phone,
              member_id = COALESCE(app.investor.member_id, EXCLUDED.member_id),
              updated_at = now()
            RETURNING id
          '''),
          parameters: {
            'phone': investorPhone,
            'code': investorCode,
            'name': investorName,
            'store': investedStoreCode,
            'units': totalUnits,
            'price': unitPrice,
            'since': since,
            'roi': roiPercent,
            'current': currentPlanType.name.toUpperCase(),
          },
        );
        final investorId = investorRows.first.first as int;

        // 2 · The request itself; status defaults to 'REQUESTED'.
        await tx.execute(
          Sql.named('''
            INSERT INTO app.investor_plan_change_request
              (investor_id, requested_plan_type)
            VALUES (@investor_id, @requested::app.investor_plan_type)
          '''),
          parameters: {
            'investor_id': investorId,
            'requested': requestedPlanType.name.toUpperCase(),
          },
        );
      });
      return null;
    });
  }

  /// Runs [action] against the shared connection, swallowing everything: a
  /// missing `DATABASE_URL`, a socket error, a SQL error. Returns null on any
  /// of them.
  Future<T?> _run<T>(
    String label,
    Future<T?> Function(Connection conn) action,
  ) async {
    if (!NeonDatabase.isConfigured) {
      return null;
    }
    try {
      final conn = await NeonDatabase.instance.connection();
      return await action(conn);
    } catch (error) {
      debugPrint('InvestorRepository.$label: $error');
      return null;
    }
  }
}
