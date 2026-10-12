import 'package:flutter/foundation.dart';

import '../../module/agent/agent_model.dart' show AgentLevel;
import '../backend/backend_agent_geo_repository.dart';

/// One row of `app.agent_geo_node` — a single slot on the agent hierarchy
/// shape ("My Team"): a region, a state, a district, an assembly segment, an
/// LSGD or a ward, joined to its parent by [parentId] (null only for the six
/// regions).
@immutable
class GeoNode {
  final String id;
  final String? parentId;
  final AgentLevel level;
  final String name;

  /// The printed tag the slot carries — `AC136`, `TVC`, `AC136-L1`,
  /// `AC136-L1-W005`. Empty for the tiers with no code (region, state,
  /// district).
  final String code;
  final String type;
  final int sort;

  const GeoNode({
    required this.id,
    required this.parentId,
    required this.level,
    required this.name,
    this.code = '',
    this.type = '',
    this.sort = 0,
  });

  static const Map<String, AgentLevel> _levels = {
    'region': AgentLevel.region,
    'state': AgentLevel.state,
    'district': AgentLevel.district,
    'assembly': AgentLevel.assembly,
    'lsgd': AgentLevel.lsgd,
    'ward': AgentLevel.ward,
  };

  /// Builds a node from a `/sql` row, or null when a required field is missing
  /// or the `level` is not one of the six recognised tiers.
  static GeoNode? fromRow(Map<String, dynamic> row) {
    String str(Object? v) => (v ?? '').toString().trim();
    final level = _levels[str(row['level']).toLowerCase()];
    final id = str(row['id']);
    var name = str(row['name']);
    final code = str(row['code']);
    if (name.isEmpty) {
      if (code.isNotEmpty) {
        name = code;
      } else if (level == AgentLevel.ward) {
        name = 'Ward';
      }
    }
    if (level == null || id.isEmpty || name.isEmpty) {
      return null;
    }
    final rawParent = row['parent_id'] ?? row['parentId'];
    final parent = rawParent != null ? str(rawParent) : '';
    return GeoNode(
      id: id,
      parentId: parent.isEmpty ? null : parent,
      level: level,
      name: name,
      code: code,
      type: str(row['type']),
      sort: int.tryParse(str(row['sort'])) ?? 0,
    );
  }
}

/// Reads the agent geographic hierarchy, through `backend/api`
/// (`BackendAgentGeoRepository`, `GET /v1/public/geo/tree`) — never a
/// direct Neon connection. This used to also hold a direct-Neon fallback
/// for when the backend call failed; that path is gone now, along with the
/// compiled-in database credential it depended on (see `docs/security.md`
/// and `backend/docs/migration-plan.md`'s Phase 5).
///
/// [GeoNode.fromRow] still parses the same flattened
/// `(id, parent_id, level, name, code, sort)` shape — [BackendAgentGeoRepository]
/// maps the backend's own response onto it, so this app's one `GeoNode`
/// type and `AgentGeo`'s tree-building logic didn't have to change at all.
class AgentGeoRepository {
  const AgentGeoRepository._();

  static const AgentGeoRepository instance = AgentGeoRepository._();

  bool get isAvailable => BackendAgentGeoRepository.instance.isAvailable;

  /// Every geo node, ordered so a parent always precedes deeper tiers, or
  /// null when the backend couldn't answer, or the tables are empty.
  /// Rethrows on failure so the caller ([AgentGeo._load]) can record the
  /// reason and show why the tree is empty instead of silently rendering
  /// nothing.
  Future<List<GeoNode>?> fetchAll() => BackendAgentGeoRepository.instance.fetchAll();
}
