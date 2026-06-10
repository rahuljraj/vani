// lib/screens/share_forward_screen.dart
//
// "Ye raju ko bhejo" — voice flow for content shared TO VANI.
// Asks who to send to, resolves the spoken name against on-device contacts,
// then:
//   - text/links → existing wa.me DRAFT path (user taps send in WhatsApp)
//   - media      → forwards the stream into WhatsApp's own picker, with
//                  honest copy: WhatsApp can't pre-target a chat for media.

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/audio_service.dart';
import '../services/contacts_service.dart';
import '../services/share_target_service.dart';
import '../services/tts_service.dart';
import '../services/actions/whatsapp_action.dart';

enum _ShareState { asking, listening, working, done, failed }

class ShareForwardScreen extends StatefulWidget {
  final SharePayload payload;
  const ShareForwardScreen({super.key, required this.payload});

  @override
  State<ShareForwardScreen> createState() => _ShareForwardScreenState();
}

class _ShareForwardScreenState extends State<ShareForwardScreen> {
  final _whatsapp = WhatsAppAction();
  final _textCtrl = TextEditingController();

  _ShareState _state = _ShareState.asking;
  String _transcript = '';
  String _status     = '';
  int    _attempts   = 0;

  @override
  void initState() {
    super.initState();
    _askDestination();
  }

  @override
  void dispose() {
    AudioService.instance.stopSttListening();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _askDestination() async {
    setState(() {
      _state      = _ShareState.asking;
      _transcript = '';
      _status     = '';
    });

    await TtsService.instance.speak('Kisko bhejna hai?');
    await Future.delayed(VaniDurations.speechStartDelay);
    if (!mounted) return;

    final ok = await AudioService.instance.startSttListening(
      onResult: (text) {
        if (mounted && text.isNotEmpty) setState(() => _transcript = text);
      },
      onAutoStop: () {
        if (_state == _ShareState.listening) _onSpoken();
      },
    );

    if (mounted) {
      setState(() =>
          _state = ok ? _ShareState.listening : _ShareState.failed);
      if (!ok) {
        setState(() => _status = 'Mic nahi chala — naam type kar dein.');
      }
    }
  }

  Future<void> _onSpoken() async {
    final text = await AudioService.instance.stopSttListening();
    if (!mounted) return;
    if (text.trim().isEmpty) {
      _retryOrGiveUp('Kuch sunai nahi diya.');
      return;
    }
    await _sendTo(text);
  }

  /// Strip command filler so "raju bhaisa ko bhej do" → "raju bhaisa".
  String _cleanName(String raw) => raw
      .toLowerCase()
      .replaceAll(
          RegExp(r'\b(ko|ye|yeh|isko|bhejo|bhej\s*do|bhejna|share|forward|'
              r'karo|kar\s*do|whatsapp|pe|par|please)\b'),
          ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> _sendTo(String spoken) async {
    final name = _cleanName(spoken);
    if (name.isEmpty) {
      _retryOrGiveUp('Naam samajh nahi aaya.');
      return;
    }

    setState(() {
      _state  = _ShareState.working;
      _status = '"$name" dhundh raha hoon...';
    });

    final number = await ContactsService.instance.resolveNumber(name);
    if (!mounted) return;

    if (number == null) {
      _retryOrGiveUp('$name contacts mein nahi mila.');
      return;
    }

    bool ok;
    if (widget.payload.hasMedia) {
      // Media can't be pre-targeted to a WhatsApp chat — be honest about it.
      await TtsService.instance
          .speak('WhatsApp khol raha hoon — $name ko wahan select karke bhej dena.');
      ok = await ShareTargetService.instance
          .forwardMediaToWhatsApp(widget.payload);
    } else {
      // Text/link → wa.me draft in $name's chat; user taps send.
      await TtsService.instance.speak('$name ko draft bhej raha hoon.');
      ok = await _whatsapp.sendMessage(name, widget.payload.text);
    }

    if (!mounted) return;
    setState(() {
      _state  = ok ? _ShareState.done : _ShareState.failed;
      _status = ok
          ? (widget.payload.hasMedia
              ? 'WhatsApp khul gaya — $name ko wahan chunein.'
              : 'Draft taiyaar — WhatsApp mein send dabayein.')
          : 'WhatsApp nahi khul paya. Install hai kya?';
    });
    if (!ok) await TtsService.instance.speak('WhatsApp nahi khul paya.');
  }

  void _retryOrGiveUp(String reason) {
    _attempts++;
    if (_attempts < 3) {
      setState(() => _status = '$reason Dobara boliye.');
      TtsService.instance.speak('$reason Dobara boliye?');
      _askDestination();
    } else {
      setState(() {
        _state  = _ShareState.failed;
        _status = '$reason Naam type kar dein, ya cancel karein.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload;
    return Scaffold(
      backgroundColor: VaniColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text(
                'VANI · Share',
                style: TextStyle(
                  color: VaniColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 28),

              // What's being shared
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: VaniColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: VaniColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.hasMedia ? '📎 Media' : '🔗 Text / link',
                      style: const TextStyle(
                          color: VaniColors.textHint, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.summary,
                      style: const TextStyle(
                        color: VaniColors.primary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Icon(
                _state == _ShareState.listening
                    ? Icons.mic_rounded
                    : _state == _ShareState.done
                        ? Icons.check_circle_rounded
                        : Icons.record_voice_over_rounded,
                size: 56,
                color: _state == _ShareState.listening
                    ? VaniColors.listening
                    : _state == _ShareState.done
                        ? VaniColors.speaking
                        : VaniColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                _state == _ShareState.listening
                    ? (_transcript.isEmpty ? 'Sun raha hoon...' : _transcript)
                    : (_status.isEmpty ? 'Kisko bhejna hai?' : _status),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VaniColors.primary,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),

              const Spacer(),

              // Typed fallback — same contract, just no voice.
              TextField(
                controller: _textCtrl,
                style: const TextStyle(color: VaniColors.primary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ya contact ka naam type karein...',
                  hintStyle: const TextStyle(
                      color: VaniColors.textHint, fontSize: 14),
                  filled: true,
                  fillColor: VaniColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: VaniColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) _sendTo(v);
                },
                textInputAction: TextInputAction.send,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _state == _ShareState.done ? 'Done' : 'Cancel',
                        style: const TextStyle(
                            color: VaniColors.textSecondary, fontSize: 15),
                      ),
                    ),
                  ),
                  if (_state != _ShareState.done &&
                      _state != _ShareState.listening)
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          _attempts = 0;
                          _askDestination();
                        },
                        child: const Text(
                          '🎤 Dobara bolein',
                          style: TextStyle(
                              color: VaniColors.accent, fontSize: 15),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
