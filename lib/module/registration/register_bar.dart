import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'registration_flow.dart';
import 'registration_service.dart';

/// Sticky strip directly above the bottom navigation, offering the reward.
///
/// It replaced a coupon promo in this slot. A discount the app cannot actually
/// apply is noise; the reward points are real state that this strip can move,
/// so the most persistent surface in the app now carries something that
/// happens when it is tapped.
///
/// Removes itself once the member registers or waves it away, so the slot
/// gives its height back to the app rather than nagging from it forever.
class RegisterBar extends StatelessWidget {
  const RegisterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RegistrationService.instance,
      builder: (context, _) {
        final service = RegistrationService.instance;
        if (!service.shouldPrompt) {
          return const SizedBox.shrink();
        }

        return Material(
          color: AppColors.brandGreenDark,
          child: InkWell(
            onTap: () => RegistrationFlow.show(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
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
                  // Pinned chrome has to be refusable, or it is just in the
                  // way on every screen for the rest of the session.
                  IconButton(
                    onPressed: service.dismissPrompt,
                    icon: const Icon(Icons.close_rounded, size: 17),
                    color: AppColors.white,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Not now',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
