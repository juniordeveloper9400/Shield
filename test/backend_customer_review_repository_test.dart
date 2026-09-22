import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:shield/data/backend/backend_customer_review_repository.dart';
import 'package:shield/data/backend/backend_http.dart';

void main() {
  BackendCustomerReviewRepository repoFor(
    Future<http.Response> Function(http.Request request) handler,
  ) => BackendCustomerReviewRepository.test(http: BackendHttp.test(client: MockClient(handler)));

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  group('listActive', () {
    test('maps active clips, unauthenticated', () async {
      final repo = repoFor((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/public/catalogue/review-videos');
        expect(request.headers['Authorization'], isNull);
        return json([
          {
            'uuid': 'clip-1',
            'name': 'Asha K.',
            'subtitle': 'Melattur',
            'videoUrl': 'https://example.com/a.mp4',
            'thumbnail': 'https://example.com/a.jpg',
          },
        ]);
      });

      final items = await repo.listActive();

      expect(items, hasLength(1));
      expect(items!.first.id, 'clip-1');
      expect(items.first.name, 'Asha K.');
      expect(items.first.video, 'https://example.com/a.mp4');
      expect(items.first.subtitle, 'Melattur');
    });

    test('falls back to the video URL as the id when uuid is blank', () async {
      final repo = repoFor(
        (_) async => json([
          {'uuid': '', 'name': 'Someone', 'videoUrl': 'https://example.com/b.mp4'},
        ]),
      );
      final items = await repo.listActive();
      expect(items!.first.id, 'https://example.com/b.mp4');
    });

    test('drops a row with no name or no clip to play', () async {
      final repo = repoFor(
        (_) async => json([
          {'uuid': 'x', 'name': '', 'videoUrl': 'https://example.com/c.mp4'},
          {'uuid': 'y', 'name': 'Has no video', 'videoUrl': ''},
        ]),
      );
      final items = await repo.listActive();
      expect(items, isEmpty);
    });

    test('returns null on a request failure', () async {
      final repo = repoFor((_) async => http.Response('server error', 500));
      expect(await repo.listActive(), isNull);
    });

    test('with no backend configured there is nothing to read', () async {
      expect(await BackendCustomerReviewRepository.instance.listActive(), isNull);
    });
  });
}
