// lib/screens/labs_screen.dart
//
// Labs — experimental features behind flags, ALL default OFF.
// Each row is honest about its verification status: features here have NOT
// passed device/Play checks yet (see docs/future-device-checklist.md).

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/feature_flags.dart';
import '../services/share_target_service.dart';

class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaniColors.background,
      appBar: AppBar(
        backgroundColor: VaniColors.background,
        elevation: 0,
        title: const Text(
          'Labs',
          style: TextStyle(
            color: VaniColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        iconTheme: const IconThemeData(color: VaniColors.textSecondary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 16),
            child: Text(
              'Experimental features — abhi device test pending hai. '
              'Kuch ajeeb lage toh band kar dein.',
              style: TextStyle(
                color: VaniColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          _flagTile(
            flag:     FeatureFlags.shareTarget,
            emoji:    '📤',
            title:    'Share karke bhejo',
            subtitle: 'Kisi bhi app se Share → VANI → boliye kisko bhejna '
                      'hai. WhatsApp draft banta hai — send aap dabate hain.',
            status:   '⏳ device test pending',
            onChanged: _toggleShareTarget,
          ),
          _flagTile(
            flag:     FeatureFlags.floatingBubble,
            emoji:    '🫧',
            title:    'Floating bubble',
            subtitle: 'Screen pe hamesha ek VANI button — tap karte hi '
                      'sunna shuru. Quick Settings tile bhi chalta rahega.',
            status:   '⏳ Play review + battery test pending',
            onChanged: _toggleBubble,
          ),
          _flagTile(
            flag:     FeatureFlags.wakeWord,
            emoji:    '🗣️',
            title:    '"Hey VANI" wake word',
            subtitle: 'App khula ho toh bina button dabaye "Hey VANI" '
                      'boliye. Mic sirf app ke andar sunta hai.',
            status:   '⏳ accuracy + battery measurement pending',
            onChanged: _toggleWakeWord,
          ),
        ],
      ),
    );
  }

  // ── Toggle handlers (feature commits wire real side-effects here) ──

  Future<void> _toggleShareTarget(bool on) async {
    // Flip the native share-sheet alias first; only persist the flag if the
    // component state actually changed.
    final ok = await ShareTargetService.instance.setEnabled(on);
    if (!ok) {
      _snack('Share target set nahi ho paya — dobara try karein.');
      return;
    }
    await FeatureFlags.setShareTarget(on);
  }

  Future<void> _toggleBubble(bool on) async {
    await FeatureFlags.setFloatingBubble(on);
  }

  Future<void> _toggleWakeWord(bool on) async {
    await FeatureFlags.setWakeWord(on);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ──────────────────────────────────────────────────────────────

  Widget _flagTile({
    required ValueNotifier<bool> flag,
    required String emoji,
    required String title,
    required String subtitle,
    required String status,
    required Future<void> Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: VaniColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VaniColors.border),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: flag,
        builder: (_, value, __) => Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: VaniColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: VaniColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status,
                    style: const TextStyle(
                      color: VaniColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: (v) => onChanged(v),
            ),
          ],
        ),
      ),
    );
  }
}
