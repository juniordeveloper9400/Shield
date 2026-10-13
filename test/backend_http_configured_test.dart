import 'package:flutter_test/flutter_test.dart';

import 'package:shield/data/backend/backend_http.dart';

void main() {
  test('the app is built without a BACKEND_API_BASE_URL under test', () {
    expect(BackendHttp.isConfigured, isFalse);
  });
}
