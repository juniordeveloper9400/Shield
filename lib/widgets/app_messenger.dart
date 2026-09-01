import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A [ScaffoldMessenger] anchored at the app root.
///
/// The sign-in gate and the registration form both close their own route the
/// instant they succeed. A SnackBar shown through `ScaffoldMessenger.of(context)`
/// in that moment is attached to the route being torn down, so it flashes for a
/// frame or never appears. Routed through this key instead, the confirmation
/// lands on whatever screen the member ends up on.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Shows [message] on the root messenger. [celebratory] swaps in the positive
/// green fill used for sign-in and registration confirmations; [icon] is drawn
/// ahead of the text when given.
void showAppSnackBar(
  String message, {
  bool celebratory = false,
  IconData? icon,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = rootMessengerKey.currentState;
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        backgroundColor: celebratory ? AppColors.brandGreenDeep : null,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
