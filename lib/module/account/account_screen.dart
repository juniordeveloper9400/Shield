import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../cart/cart_screen.dart';
import '../wallet/wallet_screen.dart';

/// Profile summary plus the account menu.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Account',
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
          const _ProfileCard(),
          const SizedBox(height: 18),
          _MenuGroup(
            items: [
              _MenuItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'My Wallet',
                trailing: '₹3,472',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.shopping_cart_outlined,
                label: 'My Cart',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.location_on_outlined,
                label: 'Saved Addresses',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.description_outlined,
                label: 'My Prescriptions',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MenuGroup(
            items: [
              _MenuItem(
                icon: Icons.card_giftcard_rounded,
                label: 'Refer & Earn',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.headset_mic_outlined,
                label: 'Help & Support',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MenuGroup(
            items: [
              _MenuItem(
                icon: Icons.logout_rounded,
                label: 'Log out',
                isDestructive: true,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: AppColors.pageTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'RN',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.brandBlue,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rahul Nair',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '+91 90000 00002',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandBlue,
              side: const BorderSide(color: AppColors.brandBlue),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Edit',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final List<_MenuItem> items;

  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1)
              const Divider(height: 1, indent: 54, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool isDestructive;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFB4322F) : AppColors.textDark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isDestructive ? color : AppColors.brandBlue,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandGreenDark,
                ),
              ),
            if (!isDestructive) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
