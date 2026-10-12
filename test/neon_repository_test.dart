import 'package:flutter_test/flutter_test.dart';

import 'package:shield/data/neon/neon_database.dart';
import 'package:shield/data/neon/wallet_repository.dart';

void main() {
  test('the app is built without a DATABASE_URL under test', () {
    expect(NeonDatabase.isConfigured, isFalse);
  });

  test('WalletRepository.recordSpend no-ops and returns false unconfigured', () async {
    final result = await WalletRepository.instance.recordSpend(
      memberPhone: '9000000002',
      amount: 500,
      label: 'Order SHD-0001',
      orderId: 1,
    );
    expect(result, isFalse);
  });
}
