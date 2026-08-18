import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Slide-in navigation menu opened from the header hamburger.
///
/// Mirrors the reference layout: a titled bar with a close affordance, a
/// tinted account strip, the browse links, and a shaded account group pinned
/// to the end of the list.
class MenuDrawer extends StatelessWidget {
  /// Switches the shell to one of the bottom-navigation destinations.
  final ValueChanged<int> onSelectTab;

  const MenuDrawer({super.key, required this.onSelectTab});

  static const int _categoriesTab = 1;
  static const int _ordersTab = 2;
  static const int _accountTab = 3;

  static const List<String> _browseLinks = [
    'Medicines',
    'Personal Care',
    'Health Conditions',
    'Diabetes Care',
    'Healthcare Devices',
    'Vitamins & Supplements',
    'Homeopathic Medicine',
    'Health Articles',
    'Diseases & Health Conditions',
    'Health Stories',
    'Ayurveda',
    'Health Library',
  ];

  void _go(BuildContext context, int tab) {
    Navigator.of(context).pop();
    onSelectTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.white,
      width: MediaQuery.sizeOf(context).width * 0.86,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _MenuHeader(onClose: () => Navigator.of(context).pop()),
            const _AccountStrip(phone: '9400525063'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final label in _browseLinks)
                    _MenuRow(
                      label: label,
                      onTap: () => _go(context, _categoriesTab),
                    ),
                  Container(
                    color: const Color(0xFFF3F4F6),
                    child: Column(
                      children: [
                        _MenuRow(
                          label: 'Refer & earn',
                          transparent: true,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        _MenuRow(
                          label: 'My orders',
                          transparent: true,
                          onTap: () => _go(context, _ordersTab),
                        ),
                        _MenuRow(
                          label: 'Account',
                          transparent: true,
                          showDivider: false,
                          onTap: () => _go(context, _accountTab),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _MenuHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Menu',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          Material(
            color: AppColors.white,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.searchBorder),
            ),
            child: InkWell(
              onTap: onClose,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountStrip extends StatelessWidget {
  final String phone;

  const _AccountStrip({required this.phone});

  @override
  Widget build(BuildContext context) {
    // Blue-to-green sweep, taken from the two logo colours at low opacity.
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFCFE4F7), Color(0xFFE2F4E4)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            phone,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () {},
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Add more user details >',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool transparent;
  final bool showDivider;

  const _MenuRow({
    required this.label,
    required this.onTap,
    this.transparent = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: transparent ? AppColors.transparent : AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: showDivider
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border),
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
