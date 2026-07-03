# Hinglish Whisper STT (custom ggml model) — verification + integration recipe

Status: model trained and pushed to device, **not yet wired into the app**.
Nothing in the codebase reads `hinglish_stt.bin` yet — the shipped STT path
is still online Google `speech_to_text` (`en_IN`) in
`lib/services/audio_service.dart`. Pushing the file alone changes nothing;
this doc is the plan to (1) prove the model itself is good, then (2) wire it
in behind a flag.

## What's on the device

```
/sdcard/Android/data/com.vani.vani/files/hinglish_stt.bin   (77,691,730 bytes)
```

- 77.7 MB ⇒ whisper **tiny**-class ggml checkpoint (fine-tuned).
- Path = `getExternalFilesDir(null)` for the app — readable by the app with
  **zero new permissions**. Good choice; keep it here (do NOT move to
  `/sdcard/Download/`, consistent with docs/play-paperwork.md).
- ⚠️ This directory is deleted on app uninstall/"clear data" — re-push after
  reinstalls, or add a first-run copy/download later.

## Step 1 — prove the model works BEFORE touching the app (30 min, PC only)

This is the real "is it work proper" gate. If this fails, integration is
pointless. On the training PC (you already have `ggml-model.bin` locally):

```bash
# whisper.cpp CLI (build once)
git clone https://github.com/ggml-org/whisper.cpp && cd whisper.cpp
cmake -B build && cmake --build build -j

# 16 kHz mono WAV is mandatory — convert any test clip:
ffmpeg -i clip.m4a -ar 16000 -ac 1 -c:a pcm_s16le clip.wav

./build/bin/whisper-cli -m /path/to/ggml-model.bin -f clip.wav -l auto
```

Record and test these exact phrases (they map to shipped FastIntentEngine
matchers, so transcript quality here = end-to-end quality later):

- [ ] "blinkit pe doodh dhundho"
- [ ] "mummy ko call karo"
- [ ] "whatsapp kholo"
- [ ] "instagram kholo"
- [ ] "swiggy pe pav bhaji order karo"

Pass bar: output is Hinglish **in Latin script** (that's what
FastIntentEngine + brand normalization expect). If the model emits
Devanagari, decide now: retrain/re-tokenize, or add a transliteration step —
don't discover this after integration.

Also time it: `whisper-cli` prints per-stage timings. Tiny-class on a phone
SoC is roughly 3–6× slower than a desktop CPU core — if a 5 s clip takes
>2 s on the PC, expect painful latency on the Nord CE 2 Lite.

## Step 2 — sanity-check the device copy (2 min)

```bash
adb -s 6d6d9eef shell ls -l /sdcard/Android/data/com.vani.vani/files/hinglish_stt.bin
adb -s 6d6d9eef shell md5sum /sdcard/Android/data/com.vani.vani/files/hinglish_stt.bin
md5sum ggml-model.bin   # on PC — must match
```

## Step 3 — app integration (device-gated, one evening)

Same rule as the Vosk recipe (docs/offline-stt-vosk.md): do this in a session
with the Flutter toolchain + device attached; a blind cloud integration risks
a broken build. Key design constraint that is DIFFERENT from Vosk:

> **Whisper is not a streaming recognizer.** No partials. The flow becomes:
> record 16 kHz mono WAV → user stops (or silence timeout) → transcribe the
> whole clip → final text. UI must show "sun raha hoon…" without a live
> transcript while the flag is on.

1. Plugin: `whisper_ggml` or `whisper_flutter_new` on pub.dev (both bundle
   whisper.cpp for Android). ⚠️ Verify on pub.dev which one accepts a
   **custom local model path** before adding to `pubspec.yaml` — the whole
   point is loading our fine-tune, not their downloaded stock models.

2. `lib/core/stt_config.dart`:

   ```dart
   class SttConfig {
     /// Flip after the device checklist below passes 3×.
     static const useHinglishWhisper = false;

     /// getExternalFilesDir(null)/hinglish_stt.bin — where adb pushed it.
     static const whisperModelFileName = 'hinglish_stt.bin';
   }
   ```

3. Recording: reuse the dormant raw-recording path in `AudioService`
   (`startRecording`/`stopRecording`) but change `RecordConfig` to
   `AudioEncoder.wav` (PCM16), keep `sampleRate: 16000, numChannels: 1` —
   whisper can't eat the current AAC/m4a output.

4. Seam: branch on `SttConfig.useHinglishWhisper` at the top of
   `startSttListening`/`stopSttListening`. The whisper branch: start WAV
   recording; on stop, transcribe file, return text through the same
   `onResult`/return contract. Keep the shipped speech_to_text path
   byte-identical — it stays the default until the checklist passes.

5. End-of-speech: speech_to_text's `pauseFor` auto-stop doesn't exist here.
   v1: rely on the existing 15 s cap + manual stop tap. Silence detection on
   the recorder's amplitude stream is a follow-up, not a blocker.

## Device test checklist (acceptance bar, mirrors Vosk doc)

- [ ] Airplane mode ON → "blinkit pe doodh dhundho" → Blinkit opens with search
- [ ] Airplane mode ON → "mummy ko call karo" → dialer pre-filled
- [ ] Latency: tap-stop → final transcript ≤ 2.5 s on the Nord CE 2 Lite
- [ ] Transcript is Latin-script Hinglish (FastIntentEngine matches fire)
- [ ] 3× repeat of each command — same-command-fails-3× = blocker rule
- [ ] Memory: whisper tiny (~80 MB) + Gemma 3 1B loaded simultaneously —
      watch for LMK kills on 6 GB devices (`adb logcat | grep -i lowmemory`)
- [ ] Model file missing (fresh install) → clean fallback to online STT,
      no crash

## Decision vs. the Vosk plan

Both target the same v1.1 item (offline STT / airplane-mode demo). If the
fine-tune beats `vosk-model-small-en-in-0.4` on the Step-1 phrases, this
supersedes the Vosk recipe; keep exactly one offline engine — don't ship
both. Fill in results:

| Phrase | Google en_IN (shipped) | Hinglish whisper | Vosk small-en-in |
|---|---|---|---|
| blinkit pe doodh dhundho | | | |
| mummy ko call karo | | | |
| swiggy pe pav bhaji order karo | | | |
