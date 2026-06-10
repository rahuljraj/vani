# Wake word — engine evaluation & decision record

## Decision: Vosk KWS, in-app (foreground-only), behind a Labs flag

| | Vosk KWS (chosen) | openWakeWord | Porcupine (Picovoice) |
|---|---|---|---|
| Cost | Free (Apache-2.0) | Free (Apache-2.0) | **Paid** (~$6k/yr commercial) — NOT added, decision open |
| "Hey VANI" support | Grammar-constrained recognizer, any phrase — but accuracy depends on phrase being near model vocab | Needs a **custom-trained model**; pretrained set is "hey jarvis"/"alexa" etc. Training pipeline is Python-side work that can't be validated here | Custom keyword in console, best-in-class accuracy |
| Android integration | `com.alphacephei:vosk-android` Maven artifact, tiny API, already proven tech for VANI's offline-STT plan | No maintained Android/Flutter wrapper; ONNX runtime + custom audio pipeline | Clean SDK |
| Battery | ⏳ measure (grammar-constrained = small search space) | ⏳ unknown | Optimized, known-good |
| False triggers | ⏳ measure — biggest risk ("vani" likely OOV → spelled variants) | Model-dependent | Low |
| Reuse | Same model dir + native lib later serves **offline STT** — one dependency, two roadmap items | None | None |

Why not openWakeWord despite "free": its only path to "Hey VANI" is training
a custom model offline — an empirical ML task, not a code task. Vosk gives a
testable engine today with the same native dependency offline STT will need.

## Why foreground-only (the deliberate scope cut)

Always-on listening needs `FOREGROUND_SERVICE_MICROPHONE` (+ Play video
declaration for background mic). That is a **new Play-sensitive permission
beyond the agreed set**, so it is surfaced as an open decision instead of
quietly added. Foreground-only still covers the in-car / hands-free case
that matters: phone mounted, VANI open, screen on — "Hey VANI, station ka
rasta dikhao" with zero taps. Upgrade path when approved: move
`VaniWakeWord` into a mic-type FGS (one permission + one service tag).

## Mic discipline (implemented)

- Engine runs ONLY while the VANI activity is resumed; home screen stops it
  on every lifecycle pause.
- Fully released before Google STT listens; restarted when the command
  completes (model stays loaded — restart is cheap).
- 3s debounce so TTS replies can't re-trigger it.

## ⏳ UNVERIFIED — measurement procedure (multi-day, on device)

**Trigger accuracy / false-trigger rate (do first):**
1. Push model, enable toggle, leave VANI open on the desk.
2. Say "Hey VANI" 20× (varied distance/accent): note hits. Target ≥16/20.
3. Play 30 min of Hindi YouTube + normal room conversation near the phone:
   note logcat `🗣️ Wake word triggered` lines. Target: 0–1 false trigger.
4. If "vani" misses: tune `TRIGGER_PHRASES` in VaniWakeWord.kt (try
   "hey funny", "he money" — whatever the en-IN model actually hears),
   re-run step 2–3.

**Battery (engine cost while app open):**
1. `adb shell dumpsys batterystats --reset`
2. 60 min: VANI foregrounded, wake word ON, screen on, no commands.
3. `adb shell dumpsys batterystats --charged com.vani.vani > on.txt`
4. Repeat with toggle OFF → off.txt. Compare CPU ms + mAh attribution.
   Acceptance: wake word adds <4%/hr over baseline.

**Latency:** stopwatch "Hey VANI" → red listening state; target <1s.

## Open decisions (founder)

1. Porcupine: pay for accuracy if Vosk false-trigger rate is unacceptable?
2. `FOREGROUND_SERVICE_MICROPHONE` for true always-on (unlocks wake word
   with screen off / other apps foregrounded)?
3. Bundle the 36MB model in the APK vs in-app download on first enable
   (current: manual adb push, dev-only).
