import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:shield/data/backend/backend_http.dart';
import 'package:shield/data/backend/backend_member_repository.dart';

void main() {
  BackendMemberRepository repoFor(
    Future<http.Response> Function(http.Request request) handler,
  ) => BackendMemberRepository.test(http: BackendHttp.test(client: MockClient(handler)));

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  group('phoneExists', () {
    test('posts the phone and returns the exists flag', () async {
      Map<String, dynamic>? sent;
      final repo = repoFor((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/member/auth/phone-lookup');
        expect(request.headers['Authorization'], isNull); // unauthenticated — pre-OTP
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return json({'exists': true});
      });

      final result = await repo.phoneExists('9876543210');

      expect(result, isTrue);
      expect(sent, {'phone': '9876543210'});
    });

    test('returns false, not null, when the backend cleanly says no account', () async {
      final repo = repoFor((_) async => json({'exists': false}));
      expect(await repo.phoneExists('9876543211'), isFalse);
    });

    test('returns null (not false) on a server error, so the caller falls back rather than assuming no account', () async {
      final repo = repoFor(
        (_) async => json({
          'error': {'code': 'INTERNAL', 'message': 'x'},
        }, 500),
      );
      expect(await repo.phoneExists('9876543212'), isNull);
    });

    test('returns null on a network failure', () async {
      final repo = repoFor((_) async => throw http.ClientException('offline'));
      expect(await repo.phoneExists('9876543213'), isNull);
    });

    test('with no backend configured there is nothing to ask', () async {
      // The singleton in a `flutter test` run is unconfigured.
      expect(await BackendMemberRepository.instance.phoneExists('9876543210'), isNull);
    });
  });

  group('deleteAccount', () {
    test('sends the delete once a session exists, and reports success', () async {
      var called = false;
      final http_ = BackendHttp.test(client: MockClient((request) async {
        called = true;
        expect(request.method, 'DELETE');
        expect(request.url.path, '/v1/member/me');
        expect(request.headers['Authorization'], 'Bearer access-1');
        return http.Response('', 204);
      }));
      await http_.setSession(accessToken: 'access-1', refreshToken: 'refresh-1');
      final repo = BackendMemberRepository.test(http: http_);

      final result = await repo.deleteAccount();

      expect(result, isTrue);
      expect(called, isTrue);
    });

    test('does nothing and reports false when there is no backend session to delete', () async {
      final repo = repoFor((_) async {
        fail('must not call the backend with no session');
      });
      expect(await repo.deleteAccount(), isFalse);
    });

    test('reports false, not a throw, when the delete call itself fails', () async {
      final http_ = BackendHttp.test(client: MockClient((_) async => http.Response('server error', 500)));
      await http_.setSession(accessToken: 'access-1', refreshToken: 'refresh-1');
      final repo = BackendMemberRepository.test(http: http_);

      expect(await repo.deleteAccount(), isFalse);
    });
  });
}
