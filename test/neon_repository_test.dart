import 'package:flutter_test/flutter_test.dart';

import 'package:shield/data/neon/neon_database.dart';

void main() {
  test('the app is built without a DATABASE_URL under test', () {
    expect(NeonDatabase.isConfigured, isFalse);
  });
}
