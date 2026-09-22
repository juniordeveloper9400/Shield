import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:shield/data/backend/backend_address_repository.dart';
import 'package:shield/data/backend/backend_http.dart';
import 'package:shield/module/location/address_book.dart';

void main() {
  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Future<BackendHttp> signedIn(Future<http.Response> Function(http.Request request) handler) async {
    final http_ = BackendHttp.test(client: MockClient(handler));
    await http_.setSession(accessToken: 'a', refreshToken: 'r');
    return http_;
  }

  group('isAvailable', () {
    test('needs a live session, not just a configured backend', () async {
      final http_ = BackendHttp.test(client: MockClient((_) async => http.Response('', 204)));
      final repo = BackendAddressRepository.test(http: http_);
      expect(repo.isAvailable, isFalse);

      await http_.setSession(accessToken: 'a', refreshToken: 'r');
      expect(repo.isAvailable, isTrue);
    });
  });

  group('upsert', () {
    test('POSTs a new address with no id, omitting patientId when there is none', () async {
      Map<String, dynamic>? sent;
      final http_ = await signedIn((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/member/addresses');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return json({'id': 5});
      });
      final repo = BackendAddressRepository.test(http: http_);

      final id = await repo.upsert(
        label: 'HOME',
        house: '1 Main St',
        area: 'Melattur',
        landmark: '',
        pincode: '679326',
        firstName: 'Asha',
        lastName: '',
        phone: '9876543210',
      );

      expect(id, '5');
      expect(sent, isNot(contains('patientId')));
    });

    test('unwraps the remote- prefix on patientId before sending', () async {
      Map<String, dynamic>? sent;
      final http_ = await signedIn((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return json({'id': 5});
      });
      final repo = BackendAddressRepository.test(http: http_);

      await repo.upsert(
        label: 'HOME',
        house: '1 Main St',
        area: 'Melattur',
        landmark: '',
        pincode: '679326',
        firstName: 'Asha',
        lastName: '',
        phone: '9876543210',
        patientId: 'remote-42',
      );

      expect(sent?['patientId'], 42);
    });

    test('a device-local patientId (never synced) is treated the same as none', () async {
      Map<String, dynamic>? sent;
      final http_ = await signedIn((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return json({'id': 5});
      });
      final repo = BackendAddressRepository.test(http: http_);

      await repo.upsert(
        label: 'HOME',
        house: '1 Main St',
        area: 'Melattur',
        landmark: '',
        pincode: '679326',
        firstName: 'Asha',
        lastName: '',
        phone: '9876543210',
        patientId: 'p3',
      );

      expect(sent, isNot(contains('patientId')));
    });

    test('PATCHes when an id is given', () async {
      final http_ = await signedIn((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/v1/member/addresses/5');
        return json({'id': 5});
      });
      final repo = BackendAddressRepository.test(http: http_);

      final id = await repo.upsert(
        id: '5',
        label: 'WORK',
        house: '2 Second St',
        area: 'Melattur',
        landmark: '',
        pincode: '679326',
        firstName: 'Asha',
        lastName: '',
        phone: '9876543210',
      );

      expect(id, '5');
    });

    test('a 404 on update falls through to a fresh insert rather than losing the address', () async {
      var calls = 0;
      final http_ = await signedIn((request) async {
        calls++;
        if (request.method == 'PATCH') {
          return json({'error': {'code': 'NOT_FOUND', 'message': 'gone'}}, 404);
        }
        return json({'id': 9});
      });
      final repo = BackendAddressRepository.test(http: http_);

      final id = await repo.upsert(
        id: 'stale',
        label: 'HOME',
        house: '1 Main St',
        area: 'Melattur',
        landmark: '',
        pincode: '679326',
        firstName: 'Asha',
        lastName: '',
        phone: '9876543210',
      );

      expect(id, '9');
      expect(calls, 2);
    });
  });

  group('listForMember', () {
    test('maps the signed-in member\'s own addresses', () async {
      final http_ = await signedIn((request) async {
        expect(request.url.path, '/v1/member/addresses');
        return json([
          {
            'id': 5,
            'label': 'WORK',
            'house': '1 Main St',
            'area': 'Melattur',
            'landmark': '',
            'pincode': '679326',
            'firstName': 'Asha',
            'lastName': '',
            'phone': '9876543210',
            'patientId': 42,
          },
        ]);
      });
      final repo = BackendAddressRepository.test(http: http_);

      final addresses = await repo.listForMember();

      expect(addresses, hasLength(1));
      expect(addresses!.first.remoteId, '5');
      expect(addresses.first.label, AddressLabel.work);
      expect(addresses.first.patientId, 'remote-42');
    });
  });

  group('softDelete', () {
    test('sends the delete once signed in', () async {
      var called = false;
      final http_ = await signedIn((request) async {
        called = true;
        expect(request.method, 'DELETE');
        expect(request.url.path, '/v1/member/addresses/5');
        return http.Response('', 204);
      });
      final repo = BackendAddressRepository.test(http: http_);

      await repo.softDelete('5');

      expect(called, isTrue);
    });
  });
}
