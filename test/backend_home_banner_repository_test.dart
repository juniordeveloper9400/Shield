import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:shield/data/backend/backend_home_banner_repository.dart';
import 'package:shield/data/backend/backend_http.dart';

void main() {
  BackendHomeBannerRepository repoFor(
    Future<http.Response> Function(http.Request request) handler,
  ) => BackendHomeBannerRepository.test(http: BackendHttp.test(client: MockClient(handler)));

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  group('listActive', () {
    test('maps active banners, unauthenticated', () async {
      final repo = repoFor((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/public/catalogue/banners');
        expect(request.headers['Authorization'], isNull);
        return json([
          {'id': 1, 'title': 'Sale', 'subtitle': 'Up to 50% off', 'image': 'data:image/png;base64,x', 'cta': 'Shop now', 'target': '', 'sort': 0},
        ]);
      });

      final banners = await repo.listActive();

      expect(banners, hasLength(1));
      expect(banners.first.id, '1');
      expect(banners.first.title, 'Sale');
      expect(banners.first.image, 'data:image/png;base64,x');
    });

    test('drops a banner with no image', () async {
      final repo = repoFor(
        (_) async => json([
          {'id': 1, 'title': 'Broken', 'image': '', 'sort': 0},
        ]),
      );
      expect(await repo.listActive(), isEmpty);
    });

    test('returns an empty list, not a throw, on a request failure', () async {
      final repo = repoFor((_) async => http.Response('server error', 500));
      expect(await repo.listActive(), isEmpty);
    });

    test('with no backend configured there is nothing to read', () async {
      expect(await BackendHomeBannerRepository.instance.listActive(), isEmpty);
    });
  });
}
