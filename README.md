# VANI — Voice AI Native Interface for India

> Your phone, your voice, in your language.
> Hinglish-native. Understanding runs on your device.

![Platform](https://img.shields.io/badge/platform-Android-3DDC84)
![Built with Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B)
![AI](https://img.shields.io/badge/AI-on--device-7E57C2)
![Status](https://img.shields.io/badge/status-beta-orange)

---

## What is VANI

VANI is a Hinglish-native voice assistant for Android that controls your
everyday apps by voice — open apps, call and message contacts, navigate, and
search groceries and food. It's built for the mid-range phones most Indians
actually carry, not just flagships.

- *"mummy ko call karo"* → finds the contact, pulls up the dialer
- *"Blinkit pe doodh dhundho"* → opens Blinkit with the search ready
- *"Surat railway station navigate karo"* → opens Maps with directions

**Install and talk in seconds.** The current beta runs entirely on a fast,
on-device rule engine — no model to download, no setup, no account. A
factory-fresh install reaches a working voice command immediately.

---

## How it works — a two-tier intent engine

The core bet: most voice commands are patterns, not reasoning — so they
shouldn't pay the cost of a large model.

- **FastIntentEngine** — an on-device rule/pattern matcher resolves ~90% of
  commands in well under 50ms, with no model involved (*"WhatsApp kholo"*,
  *"papa ko call karo"*).
- **Gemma 3 1B (on-device, optional)** — a local LLM for the ambiguous ~10%,
  via `flutter_gemma` (LiteRT). It runs on the device too — no cloud LLM.

The beta ships **FastIntent-only** (`InferenceConfig.gemmaEnabled = false`), so
it's instant on a cold install and runs even on the cheapest phones. Odd
phrasing that FastIntent can't place returns an honest *"samajh nahi aaya,
dobara bolein"* rather than failing silently. Flip the flag to re-enable the
Gemma fallback once the model is present.

A category-aware disambiguator handles the tricky cases: in *"doodh order
karo"* the item word "doodh" (milk) outweighs the generic verb "order", so it
routes to groceries, not food delivery.

---

## Tech stack

| Layer | Technology |
| --- | --- |
| UI | Flutter (Android) |
| Fast path | FastIntentEngine (on-device rule matcher) |
| On-device LLM | Gemma 3 1B via flutter_gemma (LiteRT) — optional fallback |
| Speech-to-text | Online `en_IN` (current); offline Vosk on roadmap |
| Speech output | Android native TTS (hi-IN / en-IN) |
| App control | Deep links / Android Intents + Accessibility Service |
| State | Riverpod |

---

## Privacy

VANI is privacy-first, and honest about where that line sits today:

- **Command understanding runs on the device.** The current beta uses only the
  local rule engine — no LLM at all, no cloud. When the optional Gemma fallback
  is enabled, it too runs on-device.
- **App actions are local** — deep links, intents, and the Accessibility
  Service act on apps you're already signed into.
- **Speech-to-text currently uses an online service** (`en_IN`). This is the
  one part that leaves the device, and it's disclosed in-app:
  *"Runs on your device, except speech-to-text."*
- **Offline STT (Vosk) is on the roadmap**, so the full pipeline can run in
  airplane mode.
- No account required. No analytics or tracking servers. No cloud API calls
  for understanding.

---

## Supported commands

| Command | What it does | Status |
| --- | --- | --- |
| Open app | Launch any installed app by name (fuzzy-matched) | ✅ Working |
| Call contact | Resolve contact by name → pre-fill dialer | ✅ Working (auto-call planned) |
| WhatsApp | Resolve contact → open chat, message pre-drafted | ✅ Working (drafts; never auto-sends) |
| Navigate | Open Google Maps with directions | ✅ Working |
| Order food | Swiggy in-app search via verified app-link | ✅ Working |
| Grocery | Blinkit in-app search via verified app-link | ✅ Working |
| Zomato | — | 🔜 deep link being verified |

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
├── core/                     ← constants, inference config (gemmaEnabled flag)
├── models/                   ← intent + app models
├── services/
│   ├── fast_intent_engine.dart   ← ~90% of commands, <50ms, no model
│   ├── gemma_service.dart        ← Gemma 3 1B fallback (optional)
│   ├── intent_disambiguator.dart ← category-aware scoring
│   ├── audio_service.dart        ← STT
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
Android device with USB debugging on.

**Default — FastIntent-only (no model needed):**

```
flutter pub get
flutter run
```

That's it. The app is usable on a cold install; FastIntentEngine handles
commands with no model present.

**Optional — enable the Gemma 3 1B fallback:**

1. Set `InferenceConfig.gemmaEnabled = true` in `lib/core/inference_config.dart`.
2. Place the Gemma 3 1B LiteRT `.task` file on the device at the app-scoped path:
   ```
   /sdcard/Android/data/com.vani.vani/files/gemma_model.task
   ```
   (see `flutter_gemma` docs for the model file).
3. `flutter run`.

On first launch, grant microphone and accessibility permissions in onboarding.

---

## Roadmap

| Phase | Focus |
| --- | --- |
| Now | 5 core commands hardened · cold-install beta (FastIntent-only) · closed beta (10–20 users in Surat) |
| Next | Offline STT (Vosk, airplane-mode) · Zomato · auto-call · leaner install (decouple the LLM runtime from the FastIntent-only build) |
| Later | Wake word · lower-RAM optimization · more vernacular languages |

---

*Built for India. On-device first.*