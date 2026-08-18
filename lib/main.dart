import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(const ShieldApp());
}

class ShieldApp extends StatelessWidget {
  const ShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHIELD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandBlue,
          primary: AppColors.brandBlue,
        ),
        splashFactory: InkRipple.splashFactory,
      ),
      home: const AppShell(),
    );
  }
}
