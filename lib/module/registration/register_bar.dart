import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'registration_flow.dart';
import 'registration_service.dart';

/// Sticky strip directly above the bottom navigation.
///
/// Before registration it offers the reward and stays put — there is no
/// dismiss here, because a nag that can be waved away stops being a
/// reminder. Once the member is registered it disappears and gives its height
/// back to the screen; editing the saved details lives on the Account page and
/// in the menu. [RegistrationService] restores the profile from Neon on
/// sign-in, so a member who registered earlier never sees the offer again.
class RegisterBar extends StatelessWidget {
  const RegisterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RegistrationService.instance,
      builder: (context, _) {
        if (RegistrationService.instance.isRegistered) {
          return const SizedBox.shrink();
        }
        return const _PromptStrip();
      },
    );
  }
}

/// The reward offer, pinned until the member actually registers.
class _PromptStrip extends StatelessWidget {
  const _PromptStrip();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandGreenDark,
      child: InkWell(
        onTap: () => RegistrationFlow.show(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  size: 16,
                  color: AppColors.brandGreenDark,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Register now & get '
                  '${RegistrationService.rewardPoints} reward points',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => RegistrationFlow.show(context),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.brandBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Register',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
