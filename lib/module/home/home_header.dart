import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../cart/cart_screen.dart';
import '../wallet/wallet_screen.dart';

/// Top app chrome: menu, wordmark, wallet + cart actions, and the delivery
/// location selector beneath them.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              // maybeOf keeps this safe when the header is hosted by a
              // Scaffold that has no drawer (widget tests, previews).
              onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
              icon: const Icon(Icons.menu_rounded, size: 26),
              color: AppColors.textDark,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              tooltip: 'Menu',
            ),
            const SizedBox(width: 6),
            Image.asset(
              'assets/logos/shield_logo.png',
              height: 34,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            // Expanded (not Flexible + Spacer): a loose-fit Flexible leaves its
            // unused space at the end of the Row, which shifts the trailing
            // actions inward. Expanded keeps them pinned to the right edge.
            const Expanded(
              child: Text(
                'SHIELD',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: AppColors.brandBlue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _CircleAction(
              icon: Icons.account_balance_wallet_outlined,
              tooltip: 'Wallet',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              ),
            ),
            const SizedBox(width: 10),
            _CircleAction(
              icon: Icons.shopping_cart_outlined,
              tooltip: 'Cart',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '400079, Mumbai',
                  style: TextStyle(
                    color: AppColors.brandBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.brandBlue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.searchBorder),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 21, color: AppColors.textDark),
          ),
        ),
      ),
    );
  }
}
