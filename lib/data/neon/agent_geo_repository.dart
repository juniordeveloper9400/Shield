import 'package:flutter/foundation.dart';

import '../../module/agent/agent_model.dart' show AgentLevel;
import 'neon_http.dart';

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
  final int sort;

  const GeoNode({
    required this.id,
    required this.parentId,
    required this.level,
    required this.name,
    this.code = '',
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
    final name = str(row['name']);
    if (level == null || id.isEmpty || name.isEmpty) {
      return null;
    }
    final parent = str(row['parent_id']);
    return GeoNode(
      id: id,
      parentId: parent.isEmpty ? null : parent,
      level: level,
      name: name,
      code: str(row['code']),
      sort: int.tryParse(str(row['sort'])) ?? 0,
    );
  }
}

/// Reads the agent geographic hierarchy over the Neon HTTP SQL endpoint.
///
/// The shape is one table per tier — `app.region` / `app.state` /
/// `app.district` / `app.assembly` / `app.lsgd` / `app.ward` (migration
/// 0014), linked child → parent by UUID foreign keys. This flattens all six
/// into the `(id, parent_id, level, name, code, sort)` rows [GeoNode.fromRow]
/// expects, so a region's `parent_id` is null and every deeper tier points at
/// the row above it.
///
/// Read-only and best-effort like the other Neon repositories: a missing
/// `DATABASE_URL`, a network failure, or empty tables return null, and the
/// caller ([AgentGeo]) is left with an empty hierarchy rather than anything
/// bundled.
class AgentGeoRepository {
  const AgentGeoRepository._();

  static const AgentGeoRepository instance = AgentGeoRepository._();

  bool get isAvailable => NeonHttp.isConfigured;

  /// Every geo node, ordered so a parent always precedes deeper tiers, or null
  /// when the endpoint is not configured or the tables are empty.
  ///
  /// A transport / SQL failure is **rethrown**, not swallowed — the caller
  /// ([AgentGeo._load]) records the reason so "My Team" can show why the tree
  /// is empty instead of silently rendering nothing.
  Future<List<GeoNode>?> fetchAll() async {
    if (!NeonHttp.isConfigured) {
      return null;
    }
    final rows = await NeonHttp.instance.query(r'''
        SELECT id::text, NULL::text AS parent_id, 'region' AS level,
               name, code, sort, 1 AS tier
        FROM app.region
        UNION ALL
        SELECT id::text, region_id::text, 'state', name, code, sort, 2
        FROM app.state
        UNION ALL
        SELECT id::text, state_id::text, 'district', name, code, sort, 3
        FROM app.district
        UNION ALL
        SELECT id::text, district_id::text, 'assembly', name, code, sort, 4
        FROM app.assembly
        UNION ALL
        SELECT id::text, assembly_id::text, 'lsgd', name, code, sort, 5
        FROM app.lsgd
        UNION ALL
        SELECT id::text, lsgd_id::text, 'ward', name, code, sort, 6
        FROM app.ward
        ORDER BY tier, sort, name
      ''');
    final nodes = rows
        .map(GeoNode.fromRow)
        .whereType<GeoNode>()
        .toList(growable: false);
    return nodes.isEmpty ? null : nodes;
  }
}
