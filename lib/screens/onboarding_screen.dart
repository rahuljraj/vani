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
  bool _accPolling    = false; // guard: prevent stacking accessibility pollers

  @override
  void initState() {
    super.initState();
    _checkExistingPermissions();
  }

  Future<void> _checkExistingPermissions() async {
    final perms = await PermissionService.instance.checkAllPermissions();
    if (!mounted) return;
    setState(() {
      _micGranted  = perms['microphone']    ?? false;
      _accGranted  = perms['accessibility'] ?? false;
    });
  }

  Future<void> _requestMic() async {
    setState(() => _isChecking = true);
    final granted = await PermissionService.instance.requestMicrophone();
    if (!mounted) return;
    setState(() {
      _micGranted  = granted;
      _isChecking  = false;
      if (granted) _step = 2;
    });
  }

  Future<void> _openAccessibility() async {
    if (_accPolling) return; // don't stack pollers on re-tap
    _accPolling = true;
    await PermissionService.instance.openAccessibilitySettings();
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) { _accPolling = false; return; }
      final ok = await PermissionService.instance.hasAccessibility;
      if (ok) {
        if (!mounted) { _accPolling = false; return; }
        setState(() { _accGranted = true; _step = 3; });
        _accPolling = false;
        return;
      }
    }
    _accPolling = false;
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
              // Centered when content is short (steps 0/1/3), scrolls when the
              // accessibility disclosure (step 2) is taller than the viewport.
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: _step == 2 ? _accessibilityStep() : _buildStep(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
        return _stepContent(
          emoji:    '🎙️',
          title:    'Namaste!\nMain hoon VANI',
          subtitle: 'Aapka personal voice assistant.\nZyaadatar kaam aapke phone pe hi hota hai.',
          // HONEST privacy line — STT is the one exception, disclosed up front.
          detail:   'Aapki awaaz ko text banane ke liye phone ki\nspeech-to-text service use hoti hai. Baaki\nsab kuch aapke phone pe hi rehta hai.',
        );
      case 1:
        return _stepContent(
          emoji:    '🎤',
          title:    'Microphone Access',
          subtitle: 'VANI ko aapki awaaz sunne ki\nizazat chahiye.',
          detail:   'Recording sirf tab hoti hai jab aap\nmic button dabate hain.',
          granted:  _micGranted,
        );
      case 3:
        return _stepContent(
          emoji:    '✅',
          title:    'Sab ready hai!',
          subtitle: 'VANI ab aapke saath kaam\nkarne ke liye taiyaar hai.',
          detail:   'Blinkit, Maps, WhatsApp aur bahut kuch —\nsirf awaaz se. VANI aapke haath hain:\npaisa ya password kabhi nahi maangega.',
        );
      default:
        return const SizedBox();
    }
  }

  // ── Step 2: Accessibility PROMINENT DISCLOSURE ─────────────────
  // Google Play requires an in-app disclosure that states WHAT data the
  // service accesses, HOW it is used, and an AFFIRMATIVE consent action
  // before sending the user to the system Accessibility settings.
  Widget _accessibilityStep() {
    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VaniColors.surfaceLight,
              border: Border.all(
                color: _accGranted ? VaniColors.speaking : VaniColors.border,
                width: 2,
              ),
            ),
            child: const Center(
              child: Text('♿', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            'Accessibility Access',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:      VaniColors.primary,
              fontSize:   26,
              fontWeight: FontWeight.bold,
              height:     1.3,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'VANI aapke kehne par apps control karta hai.\n'
            'Iske liye Android ki Accessibility service\nchahiye. Aage badhne se pehle padhein:',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:    VaniColors.textSecondary,
              fontSize: 15,
              height:   1.5,
            ),
          ),
          const SizedBox(height: 20),

          _disclosureRow(
            icon:  Icons.touch_app_rounded,
            label: 'Kya karta hai',
            text:  'Screen ka content padhta hai aur aapki taraf '
                   'se tap / type karta hai — app kholna, search '
                   'likhna, button dabana.',
          ),
          _disclosureRow(
            icon:  Icons.flag_rounded,
            label: 'Kyun chahiye',
            text:  'Sirf wahi action karne ke liye jo aap bolte '
                   'hain. VANI aapke haath hain — paisa aur '
                   'password aap ke paas rehte hain.',
          ),
          _disclosureRow(
            icon:  Icons.lock_rounded,
            label: 'Aapka data',
            text:  'Screen ka content sirf action poora karne ke '
                   'liye use hota hai. Ye kisi server pe nahi '
                   'bheja jaata.',
          ),

          if (_accGranted) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle, color: VaniColors.speaking, size: 18),
                SizedBox(width: 6),
                Text(
                  'Accessibility on hai ✓',
                  style: TextStyle(color: VaniColors.speaking, fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      );
  }

  Widget _disclosureRow({
    required IconData icon,
    required String label,
    required String text,
  }) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        VaniColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VaniColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: VaniColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color:      VaniColors.primary,
                    fontSize:   14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color:    VaniColors.textSecondary,
                    fontSize: 13,
                    height:   1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        // Affirmative consent action for the prominent disclosure.
        label = _accGranted ? 'Aage Badhein ›' : 'Samajh gaya — Settings kholein';
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
              textAlign: TextAlign.center,
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