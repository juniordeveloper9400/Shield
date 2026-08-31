import 'package:flutter_test/flutter_test.dart';

import 'package:shield/data/neon/investor_repository.dart';
import 'package:shield/data/neon/neon_database.dart';
import 'package:shield/data/neon/wallet_repository.dart';
import 'package:shield/module/investor/investor_model.dart';
import 'package:shield/module/privilege/privilege_tier.dart';

void main() {
  test('the app is built without a DATABASE_URL under test', () {
    expect(NeonDatabase.isConfigured, isFalse);
  });

  test('WalletRepository.activateCard no-ops and returns null unconfigured', () async {
    final result = await WalletRepository.instance.activateCard(
      memberPhone: '9000000002',
      memberName: 'Rahul Nair',
      tierKind: PrivilegeCardKind.silver,
      amount: 10000,
      bonus: 1000,
      credited: 11000,
      cardNumber: '9010 8801 0010 4821',
      storeCode: 'SHD-MEL',
    );
    expect(result, isNull);
  });

  test('InvestorRepository.requestPlanChange no-ops unconfigured', () async {
    await expectLater(
      InvestorRepository.instance.requestPlanChange(
        investorCode: 'SHD-INV-001',
        investorName: 'Rasheed Koya',
        investorPhone: '9876543210',
        currentPlanType: InvestorPlanType.yearly,
        requestedPlanType: InvestorPlanType.monthly,
        investedStoreCode: 'SHD-MEL',
        totalUnits: 10,
        unitPrice: 150000,
        investedSince: DateTime(2023, 4, 1),
        roiPercent: 18.5,
      ),
      completes,
    );
  });
}
