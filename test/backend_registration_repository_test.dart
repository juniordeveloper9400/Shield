import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:shield/data/backend/backend_http.dart';
import 'package:shield/data/backend/backend_registration_repository.dart';
import 'package:shield/module/registration/registration_service.dart';

void main() {
  BackendRegistrationRepository repoFor(
    Future<http.Response> Function(http.Request request) handler,
  ) => BackendRegistrationRepository.test(http: BackendHttp.test(client: MockClient(handler)));

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  final registered = <String, dynamic>{
    'name': 'Asha',
    'email': 'asha@example.com',
    'gender': 'FEMALE',
    'dob': '1994-09-04',
    'address': '1 Main St',
    'place': 'Melattur',
    'pincode': '679326',
    'state': 'Kerala',
    'homeStoreCode': 'SHD-MEL',
    'registrationCompletedAt': '2026-09-01T10:00:00.000Z',
  };

  final asha = Registration(
    name: 'Asha',
    phone: '9876543210',
    email: 'asha@example.com',
    gender: Gender.female,
    dob: DateTime(1994, 9, 4),
    address: '1 Main St',
    place: 'Melattur',
    pincode: '679326',
    state: 'Kerala',
    storeId: 'SHD-MEL',
  );

  group('upsertRegistration', () {
    test('PATCHes /v1/member/me with the branch by its stable code', () async {
      Map<String, dynamic>? sent;
      final repo = repoFor((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/v1/member/me');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return json(registered);
      });

      await repo.upsertRegistration(asha);

      expect(sent?['homeStoreCode'], 'SHD-MEL');
      expect(sent?['name'], 'Asha');
      expect(sent?['dob'], '1994-09-04');
      expect(sent?['gender'], 'FEMALE');
      expect(sent?['email'], 'asha@example.com');
    });

    test('omits email when it is empty, rather than sending one the backend would reject', () async {
      Map<String, dynamic>? sent;
      final repo = repoFor((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return json(registered);
      });

      await repo.upsertRegistration(asha.copyWith(email: ''));

      expect(sent, isNot(contains('email')));
    });

    test('throws on a refusal, for the wrapper to catch', () async {
      final repo = repoFor(
        (_) async => json({
          'error': {'code': 'STORE_UNAVAILABLE', 'message': "That branch isn't taking new registrations right now."},
        }, 403),
      );

      await expectLater(repo.upsertRegistration(asha), throwsA(isA<BackendHttpException>()));
    });
  });

  group('fetchByPhone', () {
    test('returns the profile, with the branch by its stable code, even when the branch is inactive', () async {
      final repo = repoFor((_) async => json(registered));

      final result = await repo.fetchByPhone('9876543210');

      expect(result?.name, 'Asha');
      expect(result?.storeId, 'SHD-MEL');
      expect(result?.dob, DateTime(1994, 9, 4));
    });

    test('returns null when the backend says registrationCompletedAt is null', () async {
      final repo = repoFor((_) async => json({...registered, 'registrationCompletedAt': null}));

      expect(await repo.fetchByPhone('9876543210'), isNull);
    });

    test('returns null when the branch or date of birth is missing, rather than a half-usable profile', () async {
      final repo = repoFor((_) async => json({...registered, 'homeStoreCode': null}));
      expect(await repo.fetchByPhone('9876543210'), isNull);
    });

    test('throws on a request failure — the wrapper tells this apart from a clean "not registered"', () async {
      final repo = repoFor((_) async => http.Response('server error', 500));
      await expectLater(repo.fetchByPhone('9876543210'), throwsA(isA<BackendHttpException>()));

      final offline = repoFor((_) async => throw http.ClientException('offline'));
      await expectLater(offline.fetchByPhone('9876543210'), throwsA(isA<http.ClientException>()));
    });
  });

  test('isAvailable is false with no backend session, even if the backend is configured', () async {
    final http_ = BackendHttp.test(client: MockClient((_) async => http.Response('', 204)));
    final repo = BackendRegistrationRepository.test(http: http_);
    expect(repo.isAvailable, isFalse);

    await http_.setSession(accessToken: 'a', refreshToken: 'r');
    expect(repo.isAvailable, isTrue);
  });
}
