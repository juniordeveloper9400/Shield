import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:shield/data/backend/backend_category_repository.dart';
import 'package:shield/data/backend/backend_http.dart';

void main() {
  BackendCategoryRepository repoFor(
    Future<http.Response> Function(http.Request request) handler,
  ) => BackendCategoryRepository.test(http: BackendHttp.test(client: MockClient(handler)));

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  group('fetchAll', () {
    test('joins categories with their own subcategories, one call per category', () async {
      final calledPaths = <String>[];
      final repo = repoFor((request) async {
        calledPaths.add(request.url.path);
        if (request.url.path == '/v1/public/catalogue/categories') {
          return json([
            {
              'id': 1,
              'title': 'Personal Care',
              'tabLabel': 'Personal\nCare',
              'iconName': 'spa_outlined',
              'image': null,
              'bannerImage': null,
              'panelTint': 'panelGreen',
            },
          ]);
        }
        expect(request.url.path, '/v1/public/catalogue/categories/1/subcategories');
        return json([
          {'label': 'Skin Care', 'iconName': 'face_outlined', 'image': null, 'offer': null},
        ]);
      });

      final groups = await repo.fetchAll();

      expect(groups, hasLength(1));
      expect(groups!.first.title, 'Personal Care');
      expect(groups.first.tabLabel, 'Personal\nCare');
      expect(groups.first.items, hasLength(1));
      expect(groups.first.items.first.label, 'Skin Care');
      expect(groups.first.items.first.offer, 'Up to 50% off'); // blank falls back
      expect(calledPaths, ['/v1/public/catalogue/categories', '/v1/public/catalogue/categories/1/subcategories']);
    });

    test('tabLabel falls back to title when the backend sends none', () async {
      final repo = repoFor((request) async {
        if (request.url.path == '/v1/public/catalogue/categories') {
          return json([
            {'id': 1, 'title': 'Wellness', 'tabLabel': '', 'iconName': '', 'panelTint': ''},
          ]);
        }
        return json([]);
      });

      final groups = await repo.fetchAll();
      expect(groups!.first.tabLabel, 'Wellness');
    });

    test('returns null (not an empty list) when the backend has no categories', () async {
      final repo = repoFor((_) async => json([]));
      expect(await repo.fetchAll(), isNull);
    });

    test('returns null on a request failure', () async {
      final repo = repoFor((_) async => http.Response('server error', 500));
      expect(await repo.fetchAll(), isNull);
    });

    test('with no backend configured there is nothing to read', () async {
      expect(await BackendCategoryRepository.instance.fetchAll(), isNull);
    });
  });
}
