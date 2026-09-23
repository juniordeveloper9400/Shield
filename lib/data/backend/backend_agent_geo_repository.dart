import 'package:flutter/foundation.dart';

import '../../module/agent/agent_model.dart' show AgentLevel;
import '../neon/agent_geo_repository.dart' show GeoNode;
import 'backend_http.dart';

/// Reads the agent geographic hierarchy from the backend
/// (`GET /v1/public/geo/tree`) — a public, unauthenticated, cached read (see
/// `geo.service.ts`'s `listTree`).
///
/// Ported from `shield agent_invester/lib/data/backend/agent_geo_repository.dart`,
/// mapped onto this app's own [GeoNode] (which carries no `type` field —
/// the agent app's own copy added one for LSGD-tier filtering this app has
/// no equivalent screen for yet; dropped here rather than widening
/// [GeoNode] for a field nothing reads).
///
/// `lib/data/neon/agent_geo_repository.dart` (the class `AgentGeo` actually
/// calls) tries this first and falls back to its own direct-Neon path when
/// the backend is unavailable or this fails — including on a transport
/// failure, which (like the Neon path) is deliberately **not** swallowed
/// here: the caller ([AgentGeo._load]) records the reason so "My Team" can
/// show why the tree is empty instead of silently rendering nothing.
class BackendAgentGeoRepository {
  BackendAgentGeoRepository._({BackendHttp? http}) : _http = http ?? BackendHttp.instance;

  static final BackendAgentGeoRepository instance = BackendAgentGeoRepository._();

  /// Test-only: an instance wired to an injected [BackendHttp].
  @visibleForTesting
  factory BackendAgentGeoRepository.test({required BackendHttp http}) =>
      BackendAgentGeoRepository._(http: http);

  final BackendHttp _http;

  bool get isAvailable => _http.isEnabled;

  static const Map<String, AgentLevel> _levels = {
    'region': AgentLevel.region,
    'state': AgentLevel.state,
    'district': AgentLevel.district,
    'assembly': AgentLevel.assembly,
    'lsgd': AgentLevel.lsgd,
    'ward': AgentLevel.ward,
  };

  /// Every geo node, ordered so a parent always precedes deeper tiers, or
  /// null when the backend is not configured or the response is empty.
  Future<List<GeoNode>?> fetchAll() async {
    if (!isAvailable) {
      return null;
    }
    final rows = await _http.request('GET', '/v1/public/geo/tree', auth: false) as List<dynamic>;
    final nodes = rows
        .cast<Map<String, dynamic>>()
        .map(_fromRow)
        .whereType<GeoNode>()
        .toList(growable: false);
    return nodes.isEmpty ? null : nodes;
  }

  /// Builds a node from one row of `GET /v1/public/geo/tree` (camelCase),
  /// or null when a required field is missing or `level` is not one of the
  /// six recognised tiers — mirrors [GeoNode.fromRow]'s own Neon-row logic.
  static GeoNode? _fromRow(Map<String, dynamic> row) {
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
    final parent = str(row['parentId'].toString().isNotEmpty ? row['parentId'] : row['parent_id']);
    return GeoNode(
      id: id,
      parentId: parent.isEmpty ? null : parent,
      level: level,
      name: name,
      code: code,
      type: str(row['type']),
      sort: row['sort'] is int ? row['sort'] as int : int.tryParse(str(row['sort'])) ?? 0,
    );
  }
}
