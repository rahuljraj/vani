# VANI — Voice AI Native Interface for India

Voice AI assistant for budget Android users in India. Hindi / English / Hinglish.
Privacy-oriented: the assistant's reasoning and personal memory stay on the device;
speech-to-text currently uses Google STT (en-IN), disclosed to the user.
Fully-on-device STT is a v1.1 goal, not yet shipped.

Founder: Rahul Raj (solo, Surat)

## Tech Stack

- **UI**: Flutter (Dart)
- **On-device AI**: Gemma 3 1B via `flutter_gemma` — built in but FLAG-GATED OFF
  (`gemmaEnabled = false`) for the lean cold-install beta. Handles the complex ~10%
  of queries when re-enabled.
- **Intent engine**: FastIntentEngine (pattern matching) handles ~90% of queries
- **Voice**: Android microphone + `record` package → Android native TTS (hi-IN / en-IN)
- **STT**: Google STT, online, en-IN locale (Hinglish in Latin script)
- **App control**: Android Accessibility Service (`VaniAccessibilityService.kt`)
- **App launch**: Android Intents via `url_launcher`

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/inference_config.dart` | Model / inference configuration |
| `lib/services/gemma_service.dart` | Gemma 3 1B brain (gated off in beta) |
| `lib/services/fast_intent_engine.dart` | Rule-based intent engine (the 90% path) |
| `lib/services/actions/action_router.dart` | Routes voice intents to apps |
| `lib/screens/home_screen.dart` | Main UI |
| `android/app/src/main/kotlin/com/vani/vani/VaniAccessibilityService.kt` | App control engine |
| `android/app/src/main/AndroidManifest.xml` | Permissions + service registration |

## Commands

```bash
flutter pub get          # install dependencies
flutter analyze          # static analysis (run before every commit)
flutter clean            # clean build artifacts
flutter run              # run on connected Android device (USB debugging required)
flutter build apk        # build debug/release APK
flutter build appbundle  # build AAB for Play Store
```

## Current Status (accurate as of 07 Jul 2026)

- Code: github.com/rahuljraj/vani — `main` is stable
- **Beta mode: FastIntent-only.** Gemma is gated off (`gemmaEnabled = false`) so cold
  installs reach voice commands without downloading a model.
- **NO live "AI load ho rahi hai" bug.** It was resolved by shipping FastIntent-only
  mode (commit fd71536). Do NOT edit `gemma_service.dart` to fix a load hang — the
  load path does not run in the beta.
- STT: Google STT (online). On-device Whisper was tested 07 Jul 2026 and FAILED
  ("mummy ji ko call karo" → "mamamna chico pariparom", plus too slow on budget chips).
  Shelved to v1.1.
- **5 working voice commands**: call, WhatsApp (contact + message), navigation,
  app-launch (any installed app), food/grocery order (Blinkit / Swiggy deep link)
- Live work: screen-reading probe (`DEBUG_DUMP_TREE` in VaniAccessibilityService)
  → restaurant-recommendation feature

## Model Configuration (when Gemma is re-enabled)

- Active model: Gemma 3 1B (`.task` format, ~530 MB)
- <!-- TODO(verify): confirm the on-device model path against inference_config.dart.
     Docs have conflicted between /sdcard/Download/ and the app-scoped
     /sdcard/Android/data/com.vani.vani/files/ — set this to whatever the code declares. -->
- Do NOT change `modelFileName`, `modelDownloadUrl`, `modelSizeBytes`, or
  `maxContextTokens` without asking — the 1B choice was deliberate (4–6x latency win).

## Git Workflow

- `main` is stable; one branch per feature: `feat/<feature-name>`
- Commit format: `feat:` / `fix:` / `refactor:` / `chore:` / `docs:`
- **Never `git add .` or `git add -A`** — targeted adds only, name specific files
- Commit before switching branches; push at end of every session
- Verify a change worked by function/behavior (logcat, adb), not by commit stats

## When Fixing Bugs

- Always show the exact file path
- Probe actual file contents before editing — never assume API behavior
- Prefer targeted edits; full-file replacement only when the change genuinely
  spans the file
- Verify with emoji-filtered logcat (`🎤|🚀|🎯|🔎|🐛|❌`) or adb before declaring fixed
- (Windows PowerShell) run `chcp 65001` before logcat filtering for UTF-8

## When Building Features

- Reference VANI's vision: Hinglish-native, privacy-oriented India assistant
- Stay focused on the MVP: 5 working voice commands
- Defer complex features to Phase 2
- Sequence risky native changes last, so there's always a shippable version underneath

## Platform Notes

- Android app, no web UI. Windows dev environment.
- Testing requires a physical Android device with USB debugging (test device:
  OnePlus Nord CE 2 Lite 5G, arm64-v8a, package `com.vani.vani`)

## Open Strategic Questions (resolve when fresh, not mid-session)

- <!-- TODO(verify): wake word approach. Picovoice/Porcupine free tier expired
     30 Jun 2026; openWakeWord is the intended path. Interim: register VANI as the
     default Android assistant (long-press power). Confirm and update. -->
- <!-- TODO(decide): "CLI pattern over MCP" vs Swiggy MCP integration. Swiggy shipped
     MCP servers and Gemini now does third-party app actions. This is a real
     positioning call — resolve deliberately. -->