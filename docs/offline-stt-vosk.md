# Offline STT (Vosk) — v1.1 item 5 integration recipe

Goal: full pipeline works in **airplane mode** (YC demo). This is the last
v1.1 item and is **device-gated** — it was deliberately not wired in from the
cloud session (no Flutter toolchain there to validate the plugin API/compile;
a blind integration risks a broken build). Everything below is ready to
execute in one device session.

## Decisions already made

- **Engine**: Vosk (Kaldi) via the `vosk_flutter` plugin. On-device, streams
  partials, Apache-2.0.
- **Model**: `vosk-model-small-en-in-0.4` (~36 MB) from
  https://alphacephei.com/vosk/models — Indian English. Hinglish-in-Latin-
  script matches what FastIntentEngine already normalizes (v1.0 STT is
  online `en_IN`, same script).
- **Model storage**: first-run download/unzip to
  `getApplicationDocumentsDirectory()/vosk-model-small-en-in-0.4`.
  App-private → zero new permissions, consistent with the Play plan
  (docs/play-paperwork.md). Do NOT add it to `/sdcard/Download/`.
- **Rollout**: behind a flag, default OFF. Online STT stays the fallback
  until the airplane-mode demo passes 3×.

## Steps (one evening)

1. `pubspec.yaml` → check the latest version on pub.dev first:

   ```yaml
   vosk_flutter: ^0.3.48
   ```

2. Add `lib/core/stt_config.dart`:

   ```dart
   class SttConfig {
     /// v1.1 item 5 — flip after the airplane-mode demo passes 3×.
     static const useOfflineStt = false;
   }
   ```

3. Add `lib/services/vosk_stt_service.dart`. Skeleton (⚠️ verify method names
   against the installed plugin version before trusting — written from docs,
   not compiled):

   ```dart
   import 'dart:async';
   import 'dart:convert';
   import 'package:vosk_flutter/vosk_flutter.dart';

   class VoskSttService {
     VoskFlutterPlugin? _vosk;
     SpeechService? _speech;
     bool _ready = false;

     Future<bool> init(String modelPath) async {
       if (_ready) return true;
       _vosk = VoskFlutterPlugin.instance();
       final model = await _vosk!.createModel(modelPath);
       final recognizer = await _vosk!.createRecognizer(
         model: model, sampleRate: 16000);
       _speech = await _vosk!.initSpeechService(recognizer);
       _ready = true;
       return true;
     }

     /// Streams transcripts; Vosk emits JSON: {"partial": "..."} /
     /// {"text": "..."} — surface both like speech_to_text partials.
     Future<void> listen(void Function(String text, bool isFinal) onText) async {
       _speech!.onPartial().listen((p) =>
           onText(jsonDecode(p)['partial'] ?? '', false));
       _speech!.onResult().listen((r) =>
           onText(jsonDecode(r)['text'] ?? '', true));
       await _speech!.start();
     }

     Future<void> stop() async => _speech?.stop();
   }
   ```

4. Seam in `audio_service.dart`: at the top of `startSttListening` /
   `stopSttListening`, branch on `SttConfig.useOfflineStt`. Keep the existing
   speech_to_text path byte-identical — it is the shipped, working path.

5. Model fetch: zip from alphacephei → unzip with `archive` package into the
   documents dir on first enable; show the same progress UI the Gemma
   download uses.

## Device test checklist (the actual acceptance bar)

- [ ] Airplane mode ON → "blinkit pe doodh dhundho" → Blinkit opens with search
- [ ] Airplane mode ON → "mummy ko call karo" → dialer pre-filled
- [ ] Partials appear while speaking (UI transcript updates)
- [ ] End-of-speech auto-stop still fires (2–4 s silence)
- [ ] Latency: final transcript ≤ 1.5 s after silence on the Nord CE 2 Lite
- [ ] 3× repeat of each command — same-command-fails-3× = blocker rule
- [ ] OnePlus quirk: verify session re-use; the speech_to_text re-init
      workaround may not be needed for Vosk (it owns the mic via `record`)

## Known risks

- vosk_flutter pulls its own mic capture — conflicts with the `record`
  package holding the mic. Don't run both; raw-recording path in
  AudioService stays unused while Vosk listens.
- 16 kHz mono is mandatory; the small en-IN model degrades on heavy Hindi
  vocabulary — if accuracy disappoints, try `vosk-model-small-hi-0.22`
  (Hindi, Devanagari output) + transliteration, or keep en-IN and lean on
  FastIntentEngine normalization.
