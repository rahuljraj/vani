# VANI — Voice AI Native Interface for India

Voice AI assistant for budget Android users in India. Hindi / English / Hinglish.
Founder: Rahul Raj (solo, Surat) · Company: Trikontech OPC Pvt Ltd
Repo: github.com/rahuljraj/vani (PUBLIC — shared with accelerators)

---

## North Star (the vision)

A Hinglish-native voice super-assistant for budget Android users — one that *talks
with* you to get real tasks done across your apps (order food, book a ride, message,
navigate, connect Bluetooth, make notes), remembers you privately on-device, and feels
like a helpful friend rather than a command box. Long-term: the trusted default voice
layer for India's app ecosystem.

Underserved market: 500M+ Hindi/Hinglish speakers on budget Android, ignored by
English-first, flagship-focused assistants.

## Current Focus (what actually ships now)

A reliable MVP of **5 working voice commands**, used daily by real Surat users.
Every step toward the north star is filtered by one test:
**does this get the 5-command beta to real users faster?** If no, it's Phase 2+.

Discipline note: solo-founder pace is the #1 risk. Breadth is the enemy. One command
used 10x/day beats ten commands used once/week.

---

## What We've Achieved

- **5 working voice commands** (FastIntentEngine, ADB-verified on device):
  call (contact match), WhatsApp (contact + message), navigation, app-launch
  (any installed app), food/grocery order (Blinkit / Swiggy deep link)
- **FastIntent-only beta shipped** — cold install reaches voice commands with no
  model download (commit fd71536, gemmaEnabled=false)
- **Repo cleaned & protected** — .gitignore catches all model binaries / test files;
  history scrubbed of large model files previously
- **Honest CLAUDE.md + docs** — no false "on-device" claims, no private-moat leakage
- **Swiggy Builders Club — ACCEPTED** (07 Jul 2026). MCP partnership approved.

## Current Status (accurate as of 08 Jul 2026)

- main is stable
- **Beta mode: FastIntent-only.** Gemma 3 1B is built in but GATED OFF
  (gemmaEnabled=false) for lean cold-install.
- **NO live "AI load ho rahi hai" bug.** Resolved by shipping FastIntent-only mode.
  Do NOT edit gemma_service.dart to fix a load hang — the load path doesn't run.
- **STT: Google STT (online, en-IN).** On-device Whisper tested 07 Jul, FAILED
  ("mummy ji ko call karo" -> "mamamna chico pariparom", also too slow on budget
  chips). Shelved to v1.1.
- Live branch work: last was chore/repo-cleanup

---

## Architecture

- **Two-tier intent engine:** FastIntentEngine (pattern-matched, handles ~90%) +
  Gemma 3 1B (edge cases, currently gated off)
- **App control:** Android Accessibility Service (VaniAccessibilityService.kt)
- **App launch:** Android Intents via url_launcher
- **Voice:** record package -> Android native TTS (hi-IN / en-IN)

### Privacy positioning (be precise — this is public + investor-facing)
- Reasoning + personal memory stay **on-device**.
- **STT uses Google** (en-IN), disclosed. Fully-on-device STT is a v1.1 goal.
- When MCP ordering lands, it uses the **partner's cloud API** — honest line:
  "VANI's brain and memory are on-device; ordering uses the app's official API
  when you ask." Never claim "fully on-device" or "zero cloud."

## Key Files

| File | Purpose |
|------|---------|
| lib/core/inference_config.dart | Model / inference configuration |
| lib/services/gemma_service.dart | Gemma 3 1B brain (gated off in beta) |
| lib/services/fast_intent_engine.dart | Rule-based intent engine (the 90% path) |
| lib/services/actions/action_router.dart | Routes voice intents to apps |
| lib/services/tts_service.dart | Text-to-speech (for voice confirmation feature) |
| lib/screens/home_screen.dart | Main UI |
| android/app/src/main/kotlin/com/vani/vani/VaniAccessibilityService.kt | App control engine |
| android/app/src/main/AndroidManifest.xml | Permissions + service registration |

## Commands

```bash
flutter pub get          # install dependencies
flutter analyze          # static analysis (run before every commit)
flutter clean            # clean build artifacts
flutter run              # run on connected Android device (USB debugging required)
flutter build apk        # build debug/release APK
flutter build appbundle  # build AAB for Play Store
```

## Model Configuration (when Gemma is re-enabled)

- Gemma 3 1B (.task format, ~530 MB)
- <!-- TODO(verify): confirm on-device model path against inference_config.dart.
     Docs have conflicted between /sdcard/Download/ and app-scoped
     /sdcard/Android/data/com.vani.vani/files/ — match to what the code declares. -->
- Do NOT change modelFileName, modelDownloadUrl, modelSizeBytes,
  maxContextTokens without asking — the 1B choice was deliberate (4-6x latency win).

---

## Working Rules (follow these)

- **Never git add . or git add -A** — targeted adds only, name specific files
- **Commit before switching branches** (uncommitted changes follow across branches)
- **Probe actual file contents before editing** — never assume API signatures;
  fetch the real file first
- **ADB-verify before declaring anything working** — "0 insertions" is not proof
- **Push at end of every session**
- **Prefer targeted edits**; full-file replacement only when the change genuinely
  spans the file
- **Sequence risky native changes last** — always keep a shippable version underneath
- (Windows PowerShell) run chcp 65001 before logcat filtering for UTF-8;
  logcat emoji markers: mic / rocket / target / magnifier / bug / cross
- Decisive recommendations over open-ended deliberation

## Dev Environment

- Windows 10, PowerShell, VS Code + Claude Code CLI, C:\Users\rahul\vani
- Test device: OnePlus Nord CE 2 Lite 5G (ADB 6d6d9eef, pkg com.vani.vani, arm64-v8a)
- Android app, no web UI

---

## Targets

**Product (near-term):**
- Voice confirmation loop — VANI *speaks* and confirms before money/contact actions
  (uses existing tts_service.dart; TTS-completion must gate re-listen)
- APK slim-down: strip flutter_gemma LiteRT libs behind flag -> ~190MB down to ~30MB
  (critical before real-user downloads)
- Onboarding + Accessibility prominent-disclosure screen
- Assist-intent registration (long-press power = launch VANI); wake word deferred

**Play Store:**
- Personal developer account (not org — avoids D-U-N-S delay); $25, ID verification
- Closed test: 12 testers, 14 continuous days (= seeds YC DAU)
- targetSdkVersion 35 now; API 36 required after 31 Aug 2026
- Signed release AAB + keystore (BACK UP OFF-MACHINE), data safety form, privacy policy

**Accelerators / business:**
- YC W27 (~50 DAU, apply Sep-Oct 2026)
- Antler India AI Residency; NVIDIA Inception; DPIIT Startup India; AIC SURATi iLAB
- OPC -> Pvt Ltd conversion required before accepting any equity

---

## Open Strategic Questions (resolve when fresh, not mid-session)

- **Swiggy MCP vs Accessibility-tapping for ORDERING.** Swiggy Builders Club accepted.
  35 MCP tools (Food/Instamart/Dineout), OAuth 2.1, no lock-in. **No prod access
  needed to build — wire on localhost, prototype the pav-bhaji flow free.** MCP is
  likely FAR more reliable than accessibility UI-tapping for ordering (won't break on
  app updates). Leaning: VANI becomes HYBRID — MCP where partners offer it,
  on-device control everywhere else. Ordering via MCP is cloud, not on-device (see
  privacy positioning). Prototype before committing.
  - Legal form asks PERSONAL PAN/DOB — before signing prod agreement, confirm with
    builders@swiggy.in whether the agreement should be in Trikontech OPC's name
    (company PAN/CIN), not personal. No rush — build on localhost first.
- **Wake word.** Picovoice/Porcupine free tier expired 30 Jun 2026; openWakeWord is
  the intended path (laptop PoC first). Interim: default-assistant / long-press power.
- **Screen-reading probe** (DEBUG_DUMP_TREE in VaniAccessibilityService) — was for
  reading Swiggy's UI. Swiggy MCP may make this unnecessary FOR SWIGGY, but the probe
  still matters for non-MCP apps. Verify it's committed:
  Select-String -Path android\...\VaniAccessibilityService.kt -Pattern "DUMP_TREE"

---

## Deferred / Do NOT surface publicly

- Full conversational cart dialog (multi-turn add-items) -> Phase 2+
- VANI-to-VANI user knowledge sharing -> Phase 3, needs heavy consent design
- Git-history scrub for any past moat references -> deliberate future task, not rushed