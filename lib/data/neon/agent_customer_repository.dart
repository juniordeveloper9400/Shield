import '../../module/agent/agent_customer.dart';
import '../../module/privilege/privilege_tier.dart';
import 'neon_http.dart';

/// Reads an agent's "Direct sale" customers from `app.agent_customer` /
/// `app.agent_customer_plan`.
///
/// Linking a customer at registration — formerly this class's own
/// `linkCustomer`, tried alongside the ordinary member-to-member referral
/// attempt whenever the "Referral code" field held an agent's own code
/// instead — moved to `backend/api`'s `POST /v1/member/referrals/apply-code`
/// (see `ReferralRepository.applyCode`'s own doc): one call now resolves
/// either kind of code the field can hold. Every Health Pass plan approved
/// for a linked member (`shieldweb`'s `approveActivation`, on the admin
/// console) writes a matching `app.agent_customer_plan` row itself — this
/// repository's [fetchAll] just reads what has already accumulated there.
///
/// Best-effort, the same contract as the other Neon repositories: a missing
/// `DATABASE_URL` or a network blip no-ops / returns null rather than
/// throwing — the agent portal's in-memory demo data is what the UI already
/// shows regardless, and stays correct even when a real write or read never
/// lands.
class AgentCustomerRepository {
  const AgentCustomerRepository._();

  static const AgentCustomerRepository instance = AgentCustomerRepository._();

  bool get isAvailable => NeonHttp.isConfigured;

  /// Every agent's direct-sale customers, plans included — [AgentService]
  /// folds these into its in-memory roster the same way it already folds in
  /// [AgentRepository.fetchAll]'s real agents on top of the seed demo data.
  /// Null when the database is unreachable.
  Future<List<AgentCustomer>?> fetchAll() => _run('fetchAll', () async {
        final rows = await NeonHttp.instance.query(r'''
          SELECT ac.id::text AS customer_id, ac.agent_id::text AS agent_id,
                 ac.name, ac.phone,
                 acp.id::text AS plan_id, acp.amount, acp.activated_on::text,
                 mt.kind::text AS tier_kind
          FROM app.agent_customer ac
          JOIN app.agent_customer_plan acp ON acp.agent_customer_id = ac.id
          JOIN app.membership_tier mt      ON mt.id = acp.tier_id
          ORDER BY ac.id, acp.activated_on
        ''');

        final byCustomer = <String, ({String agentId, String name, String phone, List<CustomerPlan> plans})>{};
        for (final row in rows) {
          final customerId = row['customer_id'].toString();
          final entry = byCustomer.putIfAbsent(
            customerId,
            () => (
              agentId: 'db-${row['agent_id']}',
              name: (row['name'] ?? '').toString(),
              phone: (row['phone'] ?? '').toString(),
              plans: <CustomerPlan>[],
            ),
          );
          final tier = _tierForKind((row['tier_kind'] ?? '').toString());
          final activatedOn = DateTime.tryParse(
                (row['activated_on'] ?? '').toString(),
              ) ??
              DateTime.now();
          final amount = double.tryParse((row['amount'] ?? '0').toString())
                  ?.round() ??
              0;
          entry.plans.add(
            CustomerPlan(
              id: 'db-${row['plan_id']}',
              tier: tier,
              amount: amount,
              activatedOn: activatedOn,
            ),
          );
        }

        return [
          for (final id in byCustomer.keys)
            AgentCustomer(
              id: 'db-$id',
              name: byCustomer[id]!.name,
              phone: byCustomer[id]!.phone,
              agentId: byCustomer[id]!.agentId,
              plans: byCustomer[id]!.plans,
            ),
        ];
      });

  static PrivilegeTier _tierForKind(String kind) {
    for (final tier in PrivilegeProgramme.tiers) {
      if (tier.kind.name.toUpperCase() == kind.toUpperCase()) {
        return tier;
      }
    }
    return PrivilegeProgramme.silver;
  }

  /// Runs [action], swallowing everything: a missing `DATABASE_URL`, a
  /// network error, a SQL error. Returns null on any of them.
  Future<T?> _run<T>(String label, Future<T?> Function() action) async {
    if (!NeonHttp.isConfigured) {
      return null;
    }
    try {
      return await action();
    } catch (error) {
      NeonHttp.log('AgentCustomerRepository.$label failed', error: error);
      return null;
    }
  }
}
