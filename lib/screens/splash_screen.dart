// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../services/tts_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    // Init TTS
    await TtsService.instance.initialize();

    // Wait for animation
    await Future.delayed(VaniDurations.splashDelay);

    if (!mounted) return;

    // Check if onboarding done
    final prefs    = await SharedPreferences.getInstance();
    final isDone   = prefs.getBool('onboarding_done') ?? false;

    if (!mounted) return;

    if (isDone) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaniColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glow circle
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:       VaniColors.accent.withValues(alpha: 0.4),
                        blurRadius:  60,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    size:  56,
                    color: VaniColors.primary,
                  ),
                ),

                const SizedBox(height: 24),

                // App name
                const Text(
                  VaniStrings.appName,
                  style: TextStyle(
                    color:       VaniColors.primary,
                    fontSize:    52,
                    fontWeight:  FontWeight.w800,
                    letterSpacing: 12,
                  ),
                ),

                const SizedBox(height: 8),

                // Tagline
                const Text(
                  VaniStrings.tagline,
                  style: TextStyle(
                    color:       VaniColors.textSecondary,
                    fontSize:    14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
