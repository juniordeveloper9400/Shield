import 'package:flutter/material.dart';

import '../module/auth/auth_service.dart';
import '../theme/app_colors.dart';

/// Shown in place of the whole app when an admin has deleted the signed-in
/// member's account from the console's Users section.
///
/// Unlike [PersonaWebOnlyScreen] (agent/investor — redirected, not shut out),
/// there is nowhere else for this member to go: the account itself has been
/// removed, so the only action offered is signing out of this device.
class AccountDeletedScreen extends StatelessWidget {
  const AccountDeletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/logos/shield_logo.png',
                  height: 64,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 36),
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.pageTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    size: 38,
                    color: AppColors.brandBlue,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'This account has been deactivated',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Your SHIELD account is no longer active and can't be used "
                  'on the app. If you think this is a mistake, contact SHIELD '
                  'support.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: AuthService.instance.logOut,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Log out',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
