import 'dart:async';

import 'package:flutter/material.dart';

import 'registration_screen.dart';
import 'registration_service.dart';

/// Entry points into the registration form.
class RegistrationFlow {
  const RegistrationFlow._();

  /// Opens the form and resolves to whether the member completed it.
  static Future<bool> show(
    BuildContext context, {
    bool isEditing = false,
  }) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RegistrationScreen(isEditing: isEditing),
      ),
    );
    return done ?? false;
  }

  /// Offers registration once, then runs [action] either way.
  ///
  /// Used at checkout. It is an offer, not a gate: the form has a skip, and a
  /// member who declines still gets to pay — refusing to take their money
  /// because they would not give an email is not a trade-off worth making.
  static Future<void> offerThen(
    BuildContext context,
    FutureOr<void> Function() action,
  ) async {
    if (!RegistrationService.instance.shouldPrompt) {
      await action();
      return;
    }

    await show(context);
    if (context.mounted) {
      await action();
    }
  }
}
