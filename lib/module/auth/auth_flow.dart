import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'login_screen.dart';

/// Entry points into the sign-in flow.
///
/// The app is gated at launch, so in normal use these never fire — every
/// screen below the gate already has a session. They stay as the backstop for
/// the money-moving actions, which must not run against an empty session if a
/// route is ever reached another way.
class AuthFlow {
  const AuthFlow._();

  /// Pushes the login screen over the app and resolves to whether a member is
  /// signed in once it closes.
  static Future<bool> show(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const LoginScreen(),
      ),
    );
    return AuthService.instance.isSignedIn;
  }

  /// Runs [action] when signed in, otherwise opens the login screen first and
  /// only proceeds if the member completed it.
  static Future<void> guard(BuildContext context, VoidCallback action) async {
    if (AuthService.instance.isSignedIn) {
      action();
      return;
    }

    final signedIn = await show(context);
    if (signedIn && context.mounted) {
      action();
    }
  }
}
