import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:shield/data/backend/backend_agent_geo_repository.dart';
import 'package:shield/data/backend/backend_http.dart';
import 'package:shield/module/agent/agent_model.dart';

void main() {
  BackendAgentGeoRepository repoFor(
    Future<http.Response> Function(http.Request request) handler,
  ) => BackendAgentGeoRepository.test(http: BackendHttp.test(client: MockClient(handler)));

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  group('fetchAll', () {
    test('maps the flattened tree, unauthenticated', () async {
      final repo = repoFor((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/public/geo/tree');
        expect(request.headers['Authorization'], isNull);
        return json([
          {'id': 'r1', 'parentId': null, 'level': 'region', 'name': 'South', 'code': '', 'sort': 1},
          {'id': 's1', 'parentId': 'r1', 'level': 'state', 'name': 'Kerala', 'code': '', 'sort': 1},
        ]);
      });

      final nodes = await repo.fetchAll();

      expect(nodes, hasLength(2));
      expect(nodes!.first.level, AgentLevel.region);
      expect(nodes.first.parentId, isNull);
      expect(nodes.last.parentId, 'r1');
      expect(nodes.last.level, AgentLevel.state);
    });

    test('drops a row with an unrecognized level rather than crashing', () async {
      final repo = repoFor(
        (_) async => json([
          {'id': 'x', 'level': 'planet', 'name': 'Mars'},
        ]),
      );
      expect(await repo.fetchAll(), isNull);
    });

    test('returns null (not an empty list) for an empty response', () async {
      final repo = repoFor((_) async => json([]));
      expect(await repo.fetchAll(), isNull);
    });

    test('rethrows on a request failure — the caller records why the tree is empty', () async {
      final repo = repoFor((_) async => http.Response('server error', 500));
      await expectLater(repo.fetchAll(), throwsA(isA<BackendHttpException>()));
    });

    test('with no backend configured there is nothing to read', () async {
      expect(await BackendAgentGeoRepository.instance.fetchAll(), isNull);
    });
  });
}
