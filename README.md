# VANI — Voice AI Native Interface for India

> Your phone, your voice, in your language.
> Hinglish-native. Understanding runs on your device.

---

## What is VANI

VANI is a Hinglish-native voice assistant for Android that controls your
everyday apps by voice — open apps, call and message contacts, navigate, and
search groceries and food. It's built for the mid-range phones most Indians
actually carry, not just flagships.

- *"mummy ko call karo"* → finds the contact, pulls up the dialer
- *"Blinkit pe doodh dhundho"* → opens Blinkit with the search ready
- *"Surat railway station navigate karo"* → opens Maps with directions

---

## How it works — a two-tier intent engine

The core bet: most voice commands are patterns, not reasoning — so they
shouldn't pay the cost of a large model.

- **FastIntentEngine** — an on-device rule/pattern matcher resolves ~90% of
  commands in under 50ms, with no model involved ("WhatsApp kholo",
  "papa ko call karo").
- **Gemma 3 1B (on-device)** — the local LLM wakes only for the ambiguous
  ~10%, via `flutter_gemma` (LiteRT, ~530MB).

This keeps VANI fast and light enough for a 6GB-RAM mid-range phone, and means
the mic works the instant it opens — most commands never wait for the model.

A category-aware disambiguator handles the tricky cases: in *"doodh order
karo"* the item word "doodh" (milk) outweighs the generic verb "order", so it
routes to groceries, not food delivery.

---

## Tech stack

| Layer | Technology |
| --- | --- |
| UI | Flutter (Android) |
| Fast path | FastIntentEngine (on-device rule matcher) |
| On-device LLM | Gemma 3 1B via flutter_gemma (LiteRT) |
| Speech-to-text | On-device Whisper base via whisper.cpp/GGML (~148MB) — offline, airplane-mode OK |
| Speech output | Android native TTS (hi-IN / en-IN) |
| App control | Deep links / Android Intents + Accessibility Service |
| State | Riverpod |

---

## Privacy

VANI is privacy-first, and honest about where that line sits today:

- **Intent understanding runs on the device** — the rule engine and Gemma 3 1B
  are local. No cloud LLM.
- **App actions are local** — deep links, intents, and the Accessibility
  Service act on apps you're already signed into.
- **Speech-to-text runs on the device** — Whisper (whisper.cpp, GGML base)
  transcribes locally. The full mic → intent → action pipeline works in
  airplane mode. The online `en_IN` recognizer remains only as a fallback
  during the one-time model download window on first launch.
- No account required. No analytics or tracking servers. No cloud API calls
  for understanding.

---

## Supported commands (v1.0)

| Command | What it does | Status |
| --- | --- | --- |
| Open app | Launch any installed app by name (fuzzy-matched) | ✅ Working |
| Call contact | Resolve contact by name → pre-fill dialer | ✅ Working (auto-call in v1.1) |
| WhatsApp | Resolve contact → open chat, message pre-drafted | ✅ Working (drafts; never auto-sends) |
| Navigate | Open Google Maps with directions | ✅ Working |
| Order food | Swiggy in-app search via verified app-link | ✅ Working |
| Grocery | Blinkit in-app search via verified app-link | ✅ Working |
| Zomato | — | 🔜 v1.1 (deep link being verified) |

---

## Example commands

```
"WhatsApp kholo"
"mummy ko call karo"
"raju bhai sa ko whatsapp karo, late ho jaunga"
"Surat railway station navigate karo"
"Blinkit pe doodh dhundho"
"biryani mangwa do"
```

---

## Project structure

```
lib/
├── core/                     ← constants, inference config
├── models/                   ← intent + app models
├── services/
│   ├── fast_intent_engine.dart   ← ~90% of commands, <50ms
│   ├── gemma_service.dart        ← Gemma 3 1B fallback
│   ├── intent_disambiguator.dart ← category-aware scoring
│   ├── audio_service.dart        ← STT routing (local-first)
│   ├── whisper_stt_service.dart  ← offline Whisper STT + silence VAD
│   ├── tts_service.dart          ← voice output
│   └── actions/                  ← per-app routers (Maps, Blinkit, Swiggy, WhatsApp)
└── screens/                  ← splash, onboarding, home, apps
android/app/src/main/kotlin/com/vani/vani/
├── MainActivity.kt               ← Flutter ⇄ native bridge
├── VaniTileService.kt            ← Quick Settings tile (tap → listen)
└── VaniAccessibilityService.kt   ← app-control fallback
```

---

## Setup (dev)

**Prerequisites:** Flutter SDK 3.19+, Android Studio (SDK + NDK), a physical
Android device with 6GB+ RAM and USB debugging on.

```
flutter pub get
# Place the Gemma 3 1B LiteRT model on the device at /sdcard/Download/
# (see flutter_gemma docs for the model file).
# Optional: side-load the Whisper STT model to skip its one-time download —
#   /sdcard/Download/ggml-base.bin
#   from https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
# Then:
flutter run
```

On first launch, grant microphone and accessibility permissions in onboarding.

---

## Roadmap

| Phase | Focus |
| --- | --- |
| v1.0 | 5 core commands hardened · onboarding · signed APK · closed beta (10–20 users in Surat) |
| v1.1 | ~~Offline STT~~ ✅ shipped (Whisper, airplane-mode) · Zomato · auto-call · share-target ("ye raju ko bhejo") |
| Later | Wake word · lower-RAM optimization · more vernacular languages |

---

*Built for India. On-device first.*