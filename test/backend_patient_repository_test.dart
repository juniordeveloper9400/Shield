import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:shield/data/backend/backend_http.dart';
import 'package:shield/data/backend/backend_patient_repository.dart';
import 'package:shield/module/patients/patient_book.dart';

void main() {
  BackendHttp signedInHttp(Future<http.Response> Function(http.Request request) handler) {
    final http_ = BackendHttp.test(client: MockClient(handler));
    return http_;
  }

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  group('isAvailable', () {
    test('needs a live session, not just a configured backend', () async {
      final http_ = BackendHttp.test(client: MockClient((_) async => http.Response('', 204)));
      final repo = BackendPatientRepository.test(http: http_);
      expect(repo.isAvailable, isFalse);

      await http_.setSession(accessToken: 'a', refreshToken: 'r');
      expect(repo.isAvailable, isTrue);
    });
  });

  group('upsert', () {
    test('POSTs a new patient with no id', () async {
      Map<String, dynamic>? sent;
      final http_ = signedInHttp((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/member/patients');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return json({'id': 42, 'name': 'Asha'});
      });
      await http_.setSession(accessToken: 'a', refreshToken: 'r');
      final repo = BackendPatientRepository.test(http: http_);

      final id = await repo.upsert(
        name: 'Asha',
        phone: '9876543210',
        address: '1 Main St',
        dob: DateTime(1994, 9, 4),
        gender: PatientGender.female,
        relation: PatientRelation.self,
        abhaId: '123456789012',
      );

      expect(id, '42');
      expect(sent?['dob'], '1994-09-04');
      expect(sent?['gender'], 'FEMALE');
    });

    test('PATCHes when an id is given', () async {
      final http_ = signedInHttp((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/v1/member/patients/42');
        return json({'id': 42, 'name': 'Renamed'});
      });
      await http_.setSession(accessToken: 'a', refreshToken: 'r');
      final repo = BackendPatientRepository.test(http: http_);

      final id = await repo.upsert(
        id: '42',
        name: 'Renamed',
        phone: '9876543210',
        address: '1 Main St',
        dob: DateTime(1994, 9, 4),
        gender: PatientGender.female,
        relation: PatientRelation.self,
        abhaId: '',
      );

      expect(id, '42');
    });

    test('a 404 on update falls through to a fresh insert rather than losing the patient', () async {
      var calls = 0;
      final http_ = signedInHttp((request) async {
        calls++;
        if (request.method == 'PATCH') {
          return json({'error': {'code': 'NOT_FOUND', 'message': 'gone'}}, 404);
        }
        expect(request.method, 'POST');
        return json({'id': 99, 'name': 'Recreated'});
      });
      await http_.setSession(accessToken: 'a', refreshToken: 'r');
      final repo = BackendPatientRepository.test(http: http_);

      final id = await repo.upsert(
        id: 'stale-id',
        name: 'Recreated',
        phone: '9876543210',
        address: '1 Main St',
        dob: DateTime(1994, 9, 4),
        gender: PatientGender.female,
        relation: PatientRelation.self,
        abhaId: '',
      );

      expect(id, '99');
      expect(calls, 2);
    });

    test('does nothing without a live session', () async {
      final repo = BackendPatientRepository.test(
        http: BackendHttp.test(client: MockClient((_) async => http.Response('', 204))),
      );
      final id = await repo.upsert(
        name: 'Asha',
        phone: '9876543210',
        address: '1 Main St',
        dob: DateTime(1994, 9, 4),
        gender: PatientGender.female,
        relation: PatientRelation.self,
        abhaId: '',
      );
      expect(id, isNull);
    });
  });

  group('listForMember', () {
    test('maps the signed-in member\'s own patients', () async {
      final http_ = signedInHttp((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/member/patients');
        return json([
          {
            'id': 7,
            'name': 'Asha',
            'phone': '9876543210',
            'address': '1 Main St',
            'dob': '1994-09-04',
            'gender': 'FEMALE',
            'relation': 'SELF',
            'abhaId': '123456789012',
          },
        ]);
      });
      await http_.setSession(accessToken: 'a', refreshToken: 'r');
      final repo = BackendPatientRepository.test(http: http_);

      final patients = await repo.listForMember();

      expect(patients, hasLength(1));
      expect(patients!.first.remoteId, '7');
      expect(patients.first.id, 'remote-7');
      expect(patients.first.gender, PatientGender.female);
    });
  });

  group('softDelete', () {
    test('sends the delete once signed in', () async {
      var called = false;
      final http_ = signedInHttp((request) async {
        called = true;
        expect(request.method, 'DELETE');
        expect(request.url.path, '/v1/member/patients/7');
        return http.Response('', 204);
      });
      await http_.setSession(accessToken: 'a', refreshToken: 'r');
      final repo = BackendPatientRepository.test(http: http_);

      await repo.softDelete('7');

      expect(called, isTrue);
    });
  });
}
