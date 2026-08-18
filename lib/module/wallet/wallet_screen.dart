import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// SHIELD wallet: balance, quick top-up amounts, and ledger history.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static const List<_Txn> _transactions = [
    _Txn('Order SHD-100482', '16 Aug 2026', '-₹1,248', false),
    _Txn('Wallet top-up', '15 Aug 2026', '+₹2,000', true),
    _Txn('Referral reward', '11 Aug 2026', '+₹150', true),
    _Txn('Order SHD-100461', '12 Aug 2026', '-₹640', false),
    _Txn('Cashback · TM28APP', '04 Aug 2026', '+₹210', true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Wallet',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _BalanceCard(),
          const SizedBox(height: 20),
          const Text(
            'Add money',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final amount in const ['₹500', '₹1,000', '₹2,000']) ...[
                Expanded(child: _TopUpChip(label: amount)),
                if (amount != '₹2,000') const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Transaction history',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _transactions.length; i++) ...[
                  _TxnRow(txn: _transactions[i]),
                  if (i != _transactions.length - 1)
                    const Divider(height: 1, color: AppColors.border),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandBlue, AppColors.brandNavy],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Available balance',
                style: TextStyle(fontSize: 14, color: Color(0xFFC9D8F0)),
              ),
              const Spacer(),
              Image.asset(
                'assets/logos/shield_logo.png',
                height: 30,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '₹3,472.00',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: AppColors.textDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Add money',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    side: const BorderSide(color: Color(0x66FFFFFF)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Redeem points',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopUpChip extends StatelessWidget {
  final String label;

  const _TopUpChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.searchBorder),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.brandBlue,
            ),
          ),
        ),
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  final _Txn txn;

  const _TxnRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: txn.isCredit ? AppColors.greenTint : AppColors.pageTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              txn.isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 19,
              color: txn.isCredit
                  ? AppColors.brandGreenDark
                  : AppColors.brandBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  txn.date,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            txn.amount,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: txn.isCredit
                  ? AppColors.brandGreenDark
                  : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _Txn {
  final String label;
  final String date;
  final String amount;
  final bool isCredit;

  const _Txn(this.label, this.date, this.amount, this.isCredit);
}
