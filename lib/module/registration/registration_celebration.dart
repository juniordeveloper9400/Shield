import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'registration_service.dart';

/// The "you're in" beat after the registration form is submitted.
///
/// A dialog rather than a SnackBar: the reward is the whole reason the form
/// exists, so it earns a moment of its own. [isEditing] drops the reward line
/// for a profile the member is only updating — there is no second reward.
///
/// Resolves once the member dismisses it, so the caller can close the form
/// afterwards rather than racing the animation.
Future<void> showRegistrationCelebration(
  BuildContext context, {
  required bool isEditing,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: const BoxDecoration(
                color: AppColors.greenTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.brandGreenDeep,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isEditing ? 'Profile updated' : "You're registered 🎉",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isEditing
                  ? 'Your details have been saved.'
                  : 'Welcome to SHIELD. '
                        '${RegistrationService.rewardPoints} reward points have '
                        'been added to your wallet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(isEditing ? 'Done' : 'Start exploring'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
