# VANI — Voice AI Native Interface

Privacy-first, on-device voice AI assistant for Android. Hindi/English/Hinglish. Zero cloud processing.

## Tech Stack

- **UI**: Flutter (Dart)
- **On-device AI**: Gemma 4 E2B via `flutter_gemma`
- **Voice**: Android microphone + `record` package → Android native TTS (hi-IN / en-IN)
- **App control**: Android Accessibility Service (`VaniAccessibilityService.kt`)
- **App launch**: Android Intents via `url_launcher`

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/inference_config.dart` | TurboQuant toggle (`useTurboQuant`) |
| `lib/services/gemma_service.dart` | Gemma 4 E2B brain |
| `lib/services/actions/action_router.dart` | Routes voice intents to apps |
| `android/app/src/main/kotlin/com/vani/vani/VaniAccessibilityService.kt` | App control engine |
| `android/app/src/main/AndroidManifest.xml` | Permissions + service registration |

## Commands

```bash
flutter pub get          # install dependencies
flutter analyze          # static analysis (run before every commit)
flutter clean            # clean build artifacts
flutter run              # run on connected Android device (USB debugging required)
flutter build apk        # build release APK
```

## Git Workflow

- `main` is the stable branch
- One branch per feature: `feat/<feature-name>`
- Commit format: `feat: <description>` / `fix: <description>` / `refactor: <description>`
- PR per feature — keep them small and reviewable
- No stacked PRs currently; each feature branch targets `main`

## Platform Notes

- **No web UI** — this is an Android app. gstack browse features do not apply.
- **Windows dev environment** — gstack browse binary (macOS arm64) will not run here.
- Testing requires a physical Android device with USB debugging enabled (6GB+ RAM recommended).

## Skill Routing

When the user's request matches an available skill, invoke it via the Skill tool.

Key routing rules:
- Bugs, errors, crashes, "why is this broken" → invoke `/investigate`
- Code review, "check my changes", "review this" → invoke `/review`
- Create PR, push, ship a feature, "land this" → invoke `/ship`
- Architecture decisions, "does this design make sense" → invoke `/plan-eng-review`
- Brainstorm features, "what should we build next" → invoke `/office-hours`
- Save session progress, "checkpoint this" → invoke `/context-save`
- Resume a previous session, "where was I" → invoke `/context-restore`
- Weekly retro, "what did we ship" → invoke `/retro`
- Security audit, permissions review → invoke `/cso`

## Current Model Configuration — DO NOT CHANGE WITHOUT ASKING

- Active model: **Gemma 3 1B** (litertlm format, ~557 MB)
- Located on device at: `/sdcard/Download/gemma_model.litertlm`
- Previous model (deprecated): Gemma 4 E2B (2.4 GB) — do not revert
- Switching to 1B reduced latency 4–6x. This was deliberate.

If asked to debug Gemma loading:
- Do NOT change `modelFileName`, `modelDownloadUrl`, `modelSizeBytes`, or `maxContextTokens` in `inference_config.dart`
- Do NOT change `ModelFileType.litertlm` in `gemma_service.dart`
- The user has the model file already; download path is dormant
- If you think there's an inconsistency, STOP and ask before editing
