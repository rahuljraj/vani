// lib/app.dart

import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/apps_screen.dart';
import 'screens/miss_log_screen.dart';

class VaniApp extends StatelessWidget {
  const VaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:        VaniStrings.appName,
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        brightness:       Brightness.dark,
        scaffoldBackgroundColor: VaniColors.background,
        colorScheme: const ColorScheme.dark(
          primary:   VaniColors.accent,
          surface:   VaniColors.surface,
          onPrimary: VaniColors.primary,
          onSurface: VaniColors.textPrimary,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),

      initialRoute: '/splash',

      routes: {
        '/splash':     (_) => const SplashScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/home':       (_) => const HomeScreen(),
        '/apps':       (_) => const AppsScreen(),
        '/misslog':    (_) => const MissLogScreen(),
      },
    );
  }
}
