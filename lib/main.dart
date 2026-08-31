import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'module/auth/auth_service.dart';
import 'screens/root_screen.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Member sign-in is Firebase Phone Auth with no demo or offline fallback.
  // Bring Firebase up before the app starts; if the current platform has no
  // configured options (only Android is wired today — see FIREBASE_SETUP.md)
  // the app still starts so the UI is reachable, and the sign-in step reports
  // that verification is unavailable instead of white-screening here.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stack) {
    debugPrint('Firebase init failed — member sign-in will be unavailable: '
        '$error');
    debugPrintStack(stackTrace: stack);
  }

  // Bring back a member who has signed in before, so they land in the app
  // rather than on the login screen. Best-effort — a failure here must not
  // hold up launch.
  try {
    await AuthService.instance.restoreSession();
  } catch (error) {
    debugPrint('restoreSession failed — starting signed out: $error');
  }

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
      home: const RootScreen(),
    );
  }
}
