import 'dart:async';

import 'package:flutter/material.dart';

import '../module/auth/auth_service.dart';
import '../module/auth/login_screen.dart';
import 'app_shell.dart';
import 'splash_screen.dart';

/// App entry point: the splash, then the sign-in gate, then the shell.
///
/// The gate is a gate, not an offer — nothing below it is reachable without a
/// session. Because it is driven by [AuthService.currentUser] rather than a
/// pushed route, signing out anywhere in the app drops straight back to it.
class RootScreen extends StatefulWidget {
  /// How long the splash stays up.
  final Duration splashDuration;

  const RootScreen({
    super.key,
    this.splashDuration = const Duration(milliseconds: 1600),
  });

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  Timer? _timer;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.splashDuration, () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const SplashScreen();
    }

    return ValueListenableBuilder<AuthUser?>(
      valueListenable: AuthService.instance.currentUser,
      builder: (context, user, _) {
        if (user == null) {
          return const LoginScreen();
        }
        // Keyed on the session so signing out clears the previous member's
        // tab and scroll state instead of carrying it over to the next one.
        return AppShell(key: ValueKey(user.phone));
      },
    );
  }
}
