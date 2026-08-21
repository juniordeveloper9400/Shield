import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Opening screen: the shield mark alone on white.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Image(
          image: AssetImage('assets/logos/shield_logo.png'),
          width: 156,
          height: 156,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
