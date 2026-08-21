import 'package:flutter/material.dart';

import '../../money.dart';
import '../../theme/app_colors.dart';
import '../privilege/privilege_screen.dart';
import '../privilege/privilege_tier.dart';
import 'wallet_service.dart';

/// Filter options for transaction ledger.
enum TransactionFilter { all, inTxn, outTxn }

/// SHIELD wallet: balance, privilege card head, points redemption,
/// quick top-ups, and filtered transaction history (All / In / Out).
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  TransactionFilter _selectedFilter = TransactionFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
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
      body: ListenableBuilder(
        listenable: WalletService.instance,
        builder: (context, _) {
          final allEntries = WalletService.instance.entries;
          final balance = WalletService.instance.balance;
          final rewardPoints = WalletService.instance.rewardPoints;

          final filteredEntries = switch (_selectedFilter) {
            TransactionFilter.all => allEntries,
            TransactionFilter.inTxn =>
              allEntries.where((e) => e.isCredit).toList(),
            TransactionFilter.outTxn =>
              allEntries.where((e) => !e.isCredit).toList(),
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              // Main Privilege Wallet Card
              _BalanceCard(
                balance: balance,
                rewardPoints: rewardPoints,
                onAddMoney: () => _showAddMoneySheet(context),
                onRedeemPoints: () => _showRedeemPointsSheet(context),
              ),
              const SizedBox(height: 18),

              // Privilege Programme Banner
              const _PrivilegeBanner(),
              const SizedBox(height: 20),

              // Quick Add Money section
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
                  for (final amount in const [500, 1000, 2000]) ...[
                    Expanded(child: _TopUpChip(amount: amount)),
                    if (amount != 2000) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // Transaction History Section with All / In / Out filter
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Transaction history',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterSegment(
                    selected: _selectedFilter,
                    onChanged: (filter) {
                      setState(() => _selectedFilter = filter);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Ledger Transactions List
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textDark.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: filteredEntries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 38,
                                color: AppColors.textMuted.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _emptyTextForFilter(_selectedFilter),
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < filteredEntries.length; i++) ...[
                            _TxnRow(entry: filteredEntries[i]),
                            if (i != filteredEntries.length - 1)
                              const Divider(height: 1, color: AppColors.border),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _emptyTextForFilter(TransactionFilter filter) {
    switch (filter) {
      case TransactionFilter.all:
        return 'No transactions yet';
      case TransactionFilter.inTxn:
        return 'No incoming transactions';
      case TransactionFilter.outTxn:
        return 'No outgoing transactions';
    }
  }

  void _showAddMoneySheet(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Money to Wallet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  hintText: 'Enter amount (e.g. 500)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.searchBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.brandBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final val in [500, 1000, 2000, 5000]) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: OutlinedButton(
                          onPressed: () {
                            controller.text = val.toString();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '₹${formatRupees(val)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final amount = int.tryParse(controller.text.trim());
                    if (amount != null && amount > 0) {
                      WalletService.instance.topUp(amount: amount);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '₹${formatRupees(amount)} added to wallet successfully',
                          ),
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Proceed to Pay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRedeemPointsSheet(BuildContext context) {
    final rewardPoints = WalletService.instance.rewardPoints;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Redeem Shield Points',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.greenTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.brandGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      size: 34,
                      color: AppColors.brandGreenDark,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$rewardPoints Points Available',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '1 Point = ₹1.00 wallet credit',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (rewardPoints <= 0)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'You currently have no reward points to redeem.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final redeemed = WalletService.instance.redeemPoints();
                      Navigator.pop(ctx);
                      if (redeemed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '₹$rewardPoints credited to your wallet from Shield Points!',
                            ),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandGreenDeep,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Redeem ₹$rewardPoints to Wallet',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The Main Privilege Header Balance Card with Shield badge, Available
/// balance, Redeem Points capsule, and quick actions.
class _BalanceCard extends StatelessWidget {
  final int balance;
  final int rewardPoints;
  final VoidCallback onAddMoney;
  final VoidCallback onRedeemPoints;

  const _BalanceCard({
    required this.balance,
    required this.rewardPoints,
    required this.onAddMoney,
    required this.onRedeemPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF284E94), Color(0xFF1B3564), Color(0xFF132545)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF132545).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Available balance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFBACDE8),
                ),
              ),
              const Spacer(),
              // Shield badge icon with subtle check/accent
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 26,
                  color: AppColors.brandGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${formatRupees(balance)}.00',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 8),
          // Shield Redeem Points indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.stars_rounded,
                  size: 16,
                  color: AppColors.brandGreen,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Shield Points: $rewardPoints pts (₹$rewardPoints)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE3EDFC),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onAddMoney,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: AppColors.textDark,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
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
                  onPressed: onRedeemPoints,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    side: const BorderSide(color: Color(0x66FFFFFF)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
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

/// All / In / Out filter tabs segment for transaction ledger.
class _FilterSegment extends StatelessWidget {
  final TransactionFilter selected;
  final ValueChanged<TransactionFilter> onChanged;

  const _FilterSegment({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE2ECF8),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPill(
            label: 'All',
            isActive: selected == TransactionFilter.all,
            onTap: () => onChanged(TransactionFilter.all),
          ),
          _buildPill(
            label: 'In',
            isActive: selected == TransactionFilter.inTxn,
            onTap: () => onChanged(TransactionFilter.inTxn),
          ),
          _buildPill(
            label: 'Out',
            isActive: selected == TransactionFilter.outTxn,
            onTap: () => onChanged(TransactionFilter.outTxn),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.brandBlue.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive ? AppColors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Quick Add Money Top-Up Chip.
class _TopUpChip extends StatelessWidget {
  final int amount;

  const _TopUpChip({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          WalletService.instance.topUp(amount: amount);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              content: Text(
                '₹${formatRupees(amount)} added to wallet successfully',
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.searchBorder),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          child: Text(
            '₹${formatRupees(amount)}',
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

/// Single transaction ledger item row.
class _TxnRow extends StatelessWidget {
  final WalletEntry entry;

  const _TxnRow({required this.entry});

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
              color: entry.isCredit
                  ? AppColors.greenTint
                  : const Color(0xFFEEF3FA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              entry.isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 19,
              color: entry.isCredit
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
                  entry.label,
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
                  entry.date,
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
            '${entry.isCredit ? '+' : '-'}₹${formatRupees(entry.amount.abs())}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: entry.isCredit
                  ? AppColors.brandGreenDark
                  : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Privilege Programme entry banner.
class _PrivilegeBanner extends StatelessWidget {
  const _PrivilegeBanner();

  @override
  Widget build(BuildContext context) {
    final entry = PrivilegeProgramme.tiers.first;

    return Material(
      color: AppColors.greenTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PrivilegeScreen())),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 24,
                color: AppColors.brandGreenDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Privilege Programme',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Load ${entry.amountLabel} or more and we add 10%.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.brandGreenDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
