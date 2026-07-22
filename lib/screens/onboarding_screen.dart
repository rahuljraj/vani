// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../services/permission_service.dart';
import '../services/tts_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {

  int  _step          = 0; // 0=welcome 1=mic 2=accessibility 3=ready
  bool _micGranted    = false;
  bool _accGranted    = false;
  bool _isChecking    = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPermissions();
  }

  Future<void> _checkExistingPermissions() async {
    final perms = await PermissionService.instance.checkAllPermissions();
    setState(() {
      _micGranted  = perms['microphone']    ?? false;
      _accGranted  = perms['accessibility'] ?? false;
    });
  }

 Future<void> _requestMic() async {
    setState(() => _isChecking = true);
    final granted = await PermissionService.instance.requestMicrophone();
    // Phone asked alongside mic. Denial is NOT a blocker — VANI degrades to
    // dialer pre-fill — so the step gate stays on the mic result only.
    await PermissionService.instance.requestPhone();
    setState(() {
      _micGranted  = granted;
      _isChecking  = false;
      if (granted) _step = 2;
    });
  }

  Future<void> _openAccessibility() async {
    await PermissionService.instance.openAccessibilitySettings();
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final ok = await PermissionService.instance.hasAccessibility;
      if (ok) {
        setState(() { _accGranted = true; _step = 3; });
        return;
      }
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    await TtsService.instance.speak('VANI ready hai! Bataiye kya karein?');

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaniColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              _buildStep(),
              const Spacer(),
              _buildButton(),
              const SizedBox(height: 16),
              _buildStepDots(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        // Honest privacy line — matches the README: understanding is
        // on-device; speech-to-text is the one online piece in v1.0.
        return _stepContent(
          emoji:    '🎙️',
          title:    'Namaste!\nMain hoon VANI',
          subtitle: 'Aapka personal voice assistant.\nSirf aapka. Sirf aapke phone pe.',
          detail:   'Aapki baat phone pe hi samjhi jaati hai.\n'
                    'Sirf speech-to-text online hota hai —\nbaaki kuch bhi bahar nahi jaata.',
        );
      case 1:
        return _stepContent(
          emoji:    '🎤',
          title:    'Microphone Access',
          subtitle: 'VANI ko aapki awaaz sunne ki\nizazat chahiye.',
          detail:   'Sirf tab recording hoti hai jab\naap button dabate hain.',
          granted:  _micGranted,
        );
      case 2:
        // Prominent disclosure (Play accessibility policy): say exactly what
        // the service does and does not do, before sending to settings.
        return _stepContent(
          emoji:    '♿',
          title:    'Accessibility Access',
          subtitle: 'VANI accessibility ka istemaal sirf\naapke bole hue commands se apps\nkholne aur chalane ke liye karta hai.',
          detail:   'VANI aapki screen ka content kabhi\nstore ya share nahi karta.\n'
                    'Settings mein VANI Assistant "On" karein.',
          granted:  _accGranted,
        );
      case 3:
        // First-use prompt: hand the user a command that works on try #1.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepContent(
              emoji:    '✅',
              title:    'Sab ready hai!',
              subtitle: 'Button dabaiye aur boliye —',
              detail:   '"Blinkit pe doodh dhundho"\n'
                        '"Mummy ko call karo"\n'
                        '"Station ka rasta dikhao"',
            ),
            const SizedBox(height: 24),
            // Optional: set VANI as the long-press assistant. Skippable —
            // VANI works fully without it.
            TextButton(
              onPressed: () =>
                  PermissionService.instance.openAssistantSettings(),
              child: const Text(
                'Power button se VANI kholni hai?\n'
                "Settings → 'Default digital assistant app' → VANI",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:    VaniColors.accent,
                  fontSize: 13,
                  height:   1.5,
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _stepContent({
    required String emoji,
    required String title,
    required String subtitle,
    required String detail,
    bool? granted,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VaniColors.surfaceLight,
            border: Border.all(
              color: granted == true
                ? VaniColors.speaking
                : VaniColors.border,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 32),

        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color:      VaniColors.primary,
            fontSize:   28,
            fontWeight: FontWeight.bold,
            height:     1.3,
          ),
        ),
        const SizedBox(height: 16),

        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color:    VaniColors.textSecondary,
            fontSize: 16,
            height:   1.5,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color:        VaniColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color:    VaniColors.textHint,
              fontSize: 13,
              height:   1.5,
            ),
          ),
        ),

        if (granted == true) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check_circle, color: VaniColors.speaking, size: 18),
              SizedBox(width: 6),
              Text(
                'Permission granted ✓',
                style: TextStyle(color: VaniColors.speaking, fontSize: 13),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildButton() {
    String label;
    VoidCallback? onTap;
    Color color = VaniColors.primary;

    switch (_step) {
      case 0:
        label = 'Shuru Karein';
        onTap = () => setState(() => _step = _micGranted ? 2 : 1);
      case 1:
        label = _micGranted ? 'Aage Badhein ›' : 'Microphone Allow Karein';
        onTap = _isChecking ? null : (_micGranted
          ? () => setState(() => _step = 2)
          : _requestMic);
      case 2:
        label = _accGranted ? 'Aage Badhein ›' : 'Accessibility Enable Karein';
        onTap = _accGranted
          ? () => setState(() => _step = 3)
          : _openAccessibility;
      case 3:
        label = 'VANI Shuru Karein 🎙️';
        onTap = _finish;
        color = VaniColors.accent;
      default:
        label = '';
        onTap = null;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isChecking
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
      ),
    );
  }

  Widget _buildStepDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) => Container(
        width:  i == _step ? 20 : 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: i == _step
            ? VaniColors.primary
            : VaniColors.textHint,
          borderRadius: BorderRadius.circular(3),
        ),
      )),
    );
  }
}
