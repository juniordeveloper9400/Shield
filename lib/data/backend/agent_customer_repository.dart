import '../../module/agent/agent_customer.dart';
import '../../module/privilege/privilege_tier.dart';
import 'backend_http.dart';

/// Reads an agent's own "Direct sale" customers through `backend/api`'s
/// `GET /v1/agent/customers` — see `agent.service.ts`'s `listCustomers` —
/// never a direct Neon connection.
///
/// Deliberately scoped to the signed-in agent's own customers, not the
/// whole company — the old direct-Neon version of this method fetched
/// every agent's every customer, name and phone included, with no scoping
/// at all. [AgentService] only ever displays one agent's own "Direct sale"
/// list at a time, so the broad read was always wasted reach, not a real
/// feature need.
///
/// Best-effort: an unconfigured backend, a signed-out member, or a network
/// blip no-ops and returns null — the agent portal's in-memory demo data
/// is what the UI already shows regardless, and stays correct even when a
/// real read never lands.
class AgentCustomerRepository {
  const AgentCustomerRepository._();

  static const AgentCustomerRepository instance = AgentCustomerRepository._();

  bool get isAvailable => BackendHttp.isConfigured;

  /// The signed-in agent's own direct-sale customers, plans included.
  /// [agentDbId] is their own [Agent.id] (`db-<id>`) — stamped onto every
  /// row returned, since the route itself is already scoped to the caller
  /// and carries no `agentId` of its own to read back. Null when
  /// unavailable or the caller isn't an approved agent.
  Future<List<AgentCustomer>?> fetchMine({required String agentDbId}) =>
      _run('fetchMine', () async {
        final rows = await BackendHttp.instance.request('GET', '/v1/agent/customers')
            as List<dynamic>;
        return rows.cast<Map<String, dynamic>>().map((row) {
          final plans = (row['plans'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>()
              .map(
                (p) => CustomerPlan(
                  id: 'db-${p['id']}',
                  tier: _tierForKind((p['tierKind'] ?? '').toString()),
                  amount: _amount(p['amount']),
                  activatedOn: DateTime.tryParse((p['activatedOn'] ?? '').toString()) ??
                      DateTime.now(),
                ),
              )
              .toList();
          return AgentCustomer(
            id: 'db-${row['id']}',
            name: (row['name'] ?? '').toString(),
            phone: (row['phone'] ?? '').toString(),
            agentId: agentDbId,
            plans: plans,
          );
        }).toList();
      });

  static int _amount(Object? v) =>
      double.tryParse((v ?? '0').toString())?.round() ?? 0;

  static PrivilegeTier _tierForKind(String kind) {
    for (final tier in PrivilegeProgramme.tiers) {
      if (tier.kind.name.toUpperCase() == kind.toUpperCase()) {
        return tier;
      }
    }
    return PrivilegeProgramme.silver;
  }

  /// Runs [action], swallowing everything: an unconfigured backend, not
  /// signed in, a 403 (not an approved agent), a network error. Returns
  /// null on any of them.
  Future<T?> _run<T>(String label, Future<T?> Function() action) async {
    if (!BackendHttp.isConfigured) {
      return null;
    }
    try {
      return await action();
    } on BackendHttpException catch (error) {
      if (!error.isForbidden) {
        BackendHttp.log('AgentCustomerRepository.$label failed', error: error);
      }
      return null;
    } catch (error) {
      BackendHttp.log('AgentCustomerRepository.$label failed', error: error);
      return null;
    }
  }
}
