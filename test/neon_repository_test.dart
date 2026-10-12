import 'package:flutter_test/flutter_test.dart';

import 'package:shield/data/neon/neon_database.dart';
import 'package:shield/data/neon/wallet_repository.dart';
import 'package:shield/module/privilege/privilege_tier.dart';

void main() {
  test('the app is built without a DATABASE_URL under test', () {
    expect(NeonDatabase.isConfigured, isFalse);
  });

  test('WalletRepository.submitCardForApproval no-ops and returns null unconfigured', () async {
    final result = await WalletRepository.instance.submitCardForApproval(
      memberPhone: '9000000002',
      memberName: 'Rahul Nair',
      tierKind: PrivilegeCardKind.silver,
      amount: 10000,
      bonus: 1000,
      cardNumber: '9010 8801 0010 4821',
      storeCode: 'SHD-MEL',
    );
    expect(result, isNull);
  });
}
