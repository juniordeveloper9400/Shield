import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:shield/data/backend/backend_http.dart';
import 'package:shield/data/backend/backend_store_repository.dart';

void main() {
  BackendStoreRepository repoFor(
    Future<http.Response> Function(http.Request request) handler,
  ) => BackendStoreRepository.test(http: BackendHttp.test(client: MockClient(handler)));

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  final melattur = {
    'code': 'SHD-MEL',
    'name': 'Sahakar 360 Pharmacy Melattur',
    'area': 'Melattur',
    'city': 'Malappuram',
    'state': 'Kerala',
    'pincode': '679326',
    'phone': '',
    'hours': '8:00 AM – 10:00 PM',
    'offersLabCollection': true,
    'latitude': '10.988000',
    'longitude': '76.216000',
    'mapsUrl': '',
  };

  group('fetchAll', () {
    test('maps the public list, unauthenticated, with no bank fields', () async {
      final repo = repoFor((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/public/catalogue/stores');
        expect(request.headers['Authorization'], isNull);
        return json([melattur]);
      });

      final stores = await repo.fetchAll();

      expect(stores, hasLength(1));
      expect(stores!.first.id, 'SHD-MEL');
      expect(stores.first.latitude, 10.988);
      expect(stores.first.bankAccountNumber, isEmpty); // never carried publicly
    });

    test('returns null (not an empty list) when the backend answers with nothing', () async {
      final repo = repoFor((_) async => json([]));
      expect(await repo.fetchAll(), isNull);
    });

    test('returns null on a request failure', () async {
      final repo = repoFor((_) async => http.Response('server error', 500));
      expect(await repo.fetchAll(), isNull);
    });

    test('with no backend configured there is nothing to read', () async {
      expect(await BackendStoreRepository.instance.fetchAll(), isNull);
    });
  });

  group('fetchBankDetails', () {
    test('does nothing without a live session, even if the backend is configured', () async {
      final repo = repoFor((_) async {
        fail('must not call the backend with no session');
      });
      expect(await repo.fetchBankDetails('SHD-MEL'), isNull);
    });

    test('gets one branch’s bank details once signed in', () async {
      final http_ = BackendHttp.test(client: MockClient((request) async {
        expect(request.url.path, '/v1/public/catalogue/stores/SHD-MEL/bank-details');
        expect(request.headers['Authorization'], 'Bearer access-1');
        return json({
          'bankAccountName': 'Sahakar 360',
          'bankAccountNumber': '1234567890',
          'bankIfsc': 'SBIN0001234',
          'bankName': 'State Bank of India',
        });
      }));
      await http_.setSession(accessToken: 'access-1', refreshToken: 'refresh-1');
      final repo = BackendStoreRepository.test(http: http_);

      final details = await repo.fetchBankDetails('SHD-MEL');

      expect(details, {
        'bankAccountName': 'Sahakar 360',
        'bankAccountNumber': '1234567890',
        'bankIfsc': 'SBIN0001234',
        'bankName': 'State Bank of India',
      });
    });

    test('returns null (not a throw) on a 404 for an unknown or inactive code', () async {
      final http_ = BackendHttp.test(client: MockClient(
        (_) async => json({
          'error': {'code': 'NOT_FOUND', 'message': 'No active branch with that code'},
        }, 404),
      ));
      await http_.setSession(accessToken: 'access-1', refreshToken: 'refresh-1');
      final repo = BackendStoreRepository.test(http: http_);

      expect(await repo.fetchBankDetails('SHD-NOPE'), isNull);
    });
  });
}
