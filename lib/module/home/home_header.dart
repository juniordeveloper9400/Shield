import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../cart/cart_badge.dart';
import '../location/address_book.dart';
import '../location/location_sheet.dart';
import '../wallet/wallet_screen.dart';

/// Top app chrome: menu, wordmark, the wallet and cart actions, and the
/// delivery location selector beneath them.
///
/// This is the only cart in the app's chrome. The home screen pins this header,
/// so it stays on screen while the feed scrolls.
class HomeHeader extends StatefulWidget {
  /// The home screen draws the cart itself, at a fixed position, so it can
  /// hold still while everything else here collapses away. It passes false.
  final bool showCart;

  const HomeHeader({super.key, this.showCart = true});

  /// Height of the action row. Fixed so that a cart drawn outside this
  /// widget can be centred against the wallet without guessing at font metrics.
  static const double rowHeight = 42;

  static const String defaultPincode = AddressBook.defaultPincode;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  /// The location is not held here. [AddressBook] owns it, so an address
  /// saved from the form — which this widget never sees — shows up in the
  /// header the moment it is saved, and so does a pincode from the sheet.
  Future<void> _chooseLocation() async {
    final book = AddressBook.instance;
    final chosen = await LocationSheet.show(context, book.pincode);
    if (chosen != null) {
      book.setPincode(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: HomeHeader.rowHeight,
          child: Row(
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
              const SizedBox(width: 4),
              // Matched to the menu glyph beside it rather than the button's
              // 40px tap target, so the two read as the same size.
              Image.asset(
                'assets/logos/shield_logo.png',
                height: 26,
                fit: BoxFit.contain,
              ),
              // The wordmark that used to fill this slot was also what pinned
              // the trailing actions right; a Spacer now does that job.
              const Spacer(),
              _CircleAction(
                icon: Icons.account_balance_wallet_outlined,
                tooltip: 'Wallet',
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const WalletScreen())),
              ),
              if (widget.showCart) ...[
                const SizedBox(width: 10),
                const CartBadge(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: _chooseLocation,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rebuilds on its own whenever the delivery location changes,
                // including from the address form on another route.
                Flexible(
                  child: ListenableBuilder(
                    listenable: AddressBook.instance,
                    builder: (context, _) => Text(
                      AddressBook.instance.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.brandBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
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
